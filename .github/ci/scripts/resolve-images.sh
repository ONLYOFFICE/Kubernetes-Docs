#!/usr/bin/env bash
# Decides which ONLYOFFICE Docs images from Docker Hub the chart is tested with.
# Images are built and pushed by ONLYOFFICE/Docker-Docs; CI only uses what is already on Docker Hub.
#
# The version under test is appVersion from Chart.yaml (e.g. 10.0.3). Images on Docker Hub are
# tagged <version>-<N> or <version>-rc.<N>; the most recently pushed tag that exists for ALL chart
# images (docs-cluster-de, docs-utils) is used, release candidates included.
#
# Sources:
#   auto            - most recently pushed release build of appVersion (onlyoffice/docs-*:<version>-<N>),
#                     else most recently pushed 4testing build (rc included), else fail
#   release         - onlyoffice/docs-*:<tag>            (public release images)
#   4testing        - onlyoffice/4testing-docs-*:<tag>   (Docker-Docs build.yaml with test-repo=true)
#   4testing-latest - most recently pushed 4testing build of appVersion (rc included)
#   For release / 4testing without an explicit tag, the most recently pushed build of appVersion in that repo is taken.
#
# Defaults: PRs into release/* and hotfix/* -> 4testing-latest (falls back to auto),
#           everything else -> auto.
#
# Priority of settings: workflow_dispatch inputs > PR description directives > defaults.
# PR description directives (one per line, anywhere in the PR body):
#   ci-images-source: 4testing
#   ci-images-tag: 10.0.0-12
#
# Env in:  INPUT_SOURCE, INPUT_TAG, PR_BODY, BASE_REF,
#          CHART_FILE (default Chart.yaml), VALUES_FILE (default values.yaml, image repository names only)
# Out:     source, tag, prefix  -> $GITHUB_OUTPUT

set -euo pipefail

CHART_FILE="${CHART_FILE:-Chart.yaml}"
VALUES_FILE="${VALUES_FILE:-values.yaml}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

# Reads "key: value" from the PR body. The body is untrusted: values are validated below.
directive() {
  printf '%s\n' "${PR_BODY:-}" | tr -d '\r' \
    | sed -n -E "s/^[[:space:]]*$1:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p" | tail -n1
}

# Prints "<tag> <push time>" for tags of a Docker Hub repo (onlyoffice/<name>) containing <filter>
hub_tags() {
  local url="https://hub.docker.com/v2/namespaces/onlyoffice/repositories/${1#onlyoffice/}/tags?page_size=100&name=$2"
  local page=0 body
  while [[ -n "$url" && "$url" != "null" && $page -lt 20 ]]; do
    body=$(curl -fsSL --retry 3 --max-time 30 "$url") || return 1
    yq -p json -r '.results[] | .name + " " + .tag_last_pushed' <<< "$body"
    url=$(yq -p json -r '.next' <<< "$body")
    page=$((page + 1))
  done
}

# Most recently pushed <version>-<N> or <version>-rc.<N> (optionally v-prefixed) tag present in
# every given repo. A tag counts as pushed when its last image was pushed (latest time across repos).
latest_common_tag() {
  local version="$1"; shift
  local re="^v?${version//./\\.}-(rc\\.)?[0-9]+ " all="" tags repo
  for repo in "$@"; do
    tags=$(hub_tags "$repo" "$version" | grep -E "$re" | sort -u) || true
    echo "  ${repo}: $(grep -c . <<< "${tags:-}") matching tags" >&2
    all+="${tags}"$'\n'
  done
  awk -v n="$#" 'NF == 2 { cnt[$1]++; if ($2 > t[$1]) t[$1] = $2 }
       END { for (k in cnt) if (cnt[k] == n) print t[k], k }' <<< "$all" \
    | sort | tail -n1 | cut -d' ' -f2 | grep .
}

image_exists() {
  docker buildx imagetools inspect "$1" > /dev/null 2>&1
}

source="${INPUT_SOURCE:-}"
tag="${INPUT_TAG:-}"
[[ -z "$source" ]] && source="$(directive ci-images-source)"
[[ -z "$tag"    ]] && tag="$(directive ci-images-tag)"

latest_is_default=false
if [[ -z "$source" && -z "$tag" && ( "${BASE_REF:-}" == release/* || "${BASE_REF:-}" == hotfix/* ) ]]; then
  source="4testing-latest"; latest_is_default=true
fi
[[ -z "$source" ]] && source="auto"

case "$source" in
  auto|release|4testing|4testing-latest) ;;
  *) echo "::error::Unknown images source '${source}' (allowed: auto, release, 4testing, 4testing-latest)"; exit 1 ;;
esac

docservice_repo="$(yq -r '.docservice.image.repository' "$VALUES_FILE")"   # onlyoffice/docs-cluster-de
# Version the chart targets: appVersion 10.0.3 (a v prefix or build number is stripped, just in case)
app_version="$(yq -r '.appVersion' "$CHART_FILE" | sed -E 's/^v//; s/-[0-9]+$//')"

# All onlyoffice images a default install uses (docs-cluster-de, docs-utils)
mapfile -t release_repos < <(yq -r '.docservice.image.repository, .tests.image.repository' "$VALUES_FILE" | sort -u)
mapfile -t testing_repos < <(printf '%s\n' "${release_repos[@]}" | sed 's#^onlyoffice/#onlyoffice/4testing-#')

newest_build() {  # newest_build <release|4testing>: most recently pushed <appVersion>-[rc.]N tag present in every chart image
  local repos
  if [[ "$1" == release ]]; then repos=("${release_repos[@]}"); else repos=("${testing_repos[@]}"); fi
  echo "Looking for the most recently pushed ${app_version}-[rc.]N tag in: ${repos[*]}" >&2
  latest_common_tag "$app_version" "${repos[@]}"
}

if [[ -z "$tag" ]]; then
  if ! [[ "$app_version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    echo "::error::Cannot take a version from appVersion in ${CHART_FILE} ('${app_version}', expected like 10.0.3)"; exit 1
  fi
  case "$source" in
    4testing-latest)
      if tag="$(newest_build 4testing)"; then
        source="4testing"
      elif [[ "$latest_is_default" == "true" ]]; then
        echo "::warning::No 4testing build of ${app_version} found, falling back to auto"
        source="auto"
      else
        echo "::error::No 4testing build of ${app_version} found"; exit 1
      fi
      ;;
    release|4testing)
      tag="$(newest_build "$source")" || { echo "::error::No ${source} build of ${app_version} found"; exit 1; }
      ;;
  esac
  if [[ "$source" == "auto" ]]; then
    if tag="$(newest_build release)"; then
      source="release"
    elif tag="$(newest_build 4testing)"; then
      source="4testing"
    else
      {
        echo "::error::No release or 4testing images found for appVersion ${app_version} (expected tags ${app_version}-<N>)."
        echo "::error::Push them from ONLYOFFICE/Docker-Docs (build.yaml, test-repo=true) or set 'ci-images-tag:' in the PR description."
      }
      exit 1
    fi
  fi
  echo "Newest ${source} build of ${app_version}: ${tag}"
elif [[ "$source" == "4testing-latest" ]]; then
  source="4testing"   # an explicit tag wins over "latest"
fi

if ! [[ "$tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]; then
  echo "::error::Invalid image tag '${tag}'"; exit 1
fi

release_ref="docker.io/${docservice_repo}:${tag}"
testing_ref="docker.io/${docservice_repo/onlyoffice\//onlyoffice/4testing-}:${tag}"

case "$source" in
  auto)
    if image_exists "$release_ref"; then
      source="release"
    elif image_exists "$testing_ref"; then
      source="4testing"
    else
      {
        echo "::error::No images found for tag '${tag}' (checked ${release_ref} and ${testing_ref})."
        echo "::error::Push them from ONLYOFFICE/Docker-Docs (build.yaml, test-repo=true) or set 'ci-images-tag:' in the PR description."
      }
      exit 1
    fi
    ;;
  release)  image_exists "$release_ref" || { echo "::error::${release_ref} not found"; exit 1; } ;;
  4testing) image_exists "$testing_ref" || { echo "::error::${testing_ref} not found"; exit 1; } ;;
esac

prefix=""
[[ "$source" == "4testing" ]] && prefix="4testing-"

{
  echo "source=${source}"
  echo "tag=${tag}"
  echo "prefix=${prefix}"
} >> "$OUT"

{
  echo "### Images under test"
  echo "| source | tag | example image |"
  echo "|---|---|---|"
  echo "| \`${source}\` | \`${tag}\` | \`onlyoffice/${prefix}${docservice_repo#onlyoffice/}:${tag}\` |"
} >> "$SUMMARY"

echo "Resolved: source=${source} tag=${tag} prefix='${prefix}'"
