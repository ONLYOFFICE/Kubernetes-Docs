#!/usr/bin/env bash
# Decides which ONLYOFFICE Docs images from Docker Hub the chart is tested with.
# Images are built and pushed by ONLYOFFICE/Docker-Docs; CI only uses what is already on Docker Hub.
#
# Sources:
#   release         - onlyoffice/docs-*:<tag>            (public release images)
#   4testing        - onlyoffice/4testing-docs-*:<tag>   (Docker-Docs build.yaml with test-repo=true)
#   auto            - release if <tag> exists there, else 4testing, else fail
#   4testing-latest - newest 4testing build of the version the chart targets:
#                     version = images.tag from values.yaml without the build number
#                     (10.0.0.3-1 -> 10.0.0.3), then the highest <version>-<N> tag that exists
#                     for ALL chart images in onlyoffice/4testing-* on Docker Hub.
#
# Defaults: PRs into release/* and hotfix/* -> 4testing-latest (falls back to auto),
#           everything else -> auto with <tag> = images.tag from values.yaml.
#
# Priority of settings: workflow_dispatch inputs > PR description directives > defaults.
# PR description directives (one per line, anywhere in the PR body):
#   ci-images-source: 4testing
#   ci-images-tag: 10.0.0-12
#
# Env in:  INPUT_SOURCE, INPUT_TAG, PR_BODY, BASE_REF, VALUES_FILE (default values.yaml)
# Out:     source, tag, prefix  -> $GITHUB_OUTPUT

set -euo pipefail

VALUES_FILE="${VALUES_FILE:-values.yaml}"
OUT="${GITHUB_OUTPUT:-/dev/stdout}"
SUMMARY="${GITHUB_STEP_SUMMARY:-/dev/null}"

# Reads "key: value" from the PR body. The body is untrusted: values are validated below.
directive() {
  printf '%s\n' "${PR_BODY:-}" | tr -d '\r' \
    | sed -n -E "s/^[[:space:]]*$1:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p" | tail -n1
}

# Prints tags of a Docker Hub repo (onlyoffice/<name>) containing <filter>
hub_tags() {
  local url="https://hub.docker.com/v2/namespaces/onlyoffice/repositories/${1#onlyoffice/}/tags?page_size=100&name=$2"
  local page=0 body
  while [[ -n "$url" && "$url" != "null" && $page -lt 20 ]]; do
    body=$(curl -fsSL --retry 3 --max-time 30 "$url") || return 1
    yq -p json -r '.results[].name' <<< "$body"
    url=$(yq -p json -r '.next' <<< "$body")
    page=$((page + 1))
  done
}

# Highest <version>-<N> (optionally v-prefixed) tag present in every given repo
latest_common_tag() {
  local version="$1"; shift
  local re="^v?${version//./\\.}-[0-9]+$" common="" tags repo
  for repo in "$@"; do
    tags=$(hub_tags "$repo" "$version" | grep -E "$re" | sort -u) || true
    echo "  ${repo}: $(grep -c . <<< "${tags:-}") matching tags" >&2
    if [[ -z "$common" ]]; then common="$tags"; else common=$(comm -12 <(echo "$common") <(echo "$tags")); fi
  done
  [[ -n "$common" ]] && awk -F- '{print $NF, $0}' <<< "$common" | sort -n | tail -n1 | cut -d' ' -f2
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

values_tag="$(yq -r '.images.tag' "$VALUES_FILE")"
docservice_repo="$(yq -r '.docservice.image.repository' "$VALUES_FILE")"   # onlyoffice/docs-cluster-de
# Version the chart targets: 10.0.0.3-1 -> 10.0.0.3, v10.0.0-12 -> 10.0.0
values_version="$(sed -E 's/^v//; s/-[0-9]+$//' <<< "$values_tag")"

if [[ "$source" == "4testing-latest" ]]; then
  if ! [[ "$values_version" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
    echo "::error::Cannot take a version from images.tag '${values_tag}' (expected like 10.0.0.3-1)"; exit 1
  fi
  # All onlyoffice images a default install uses (docs-cluster-de, docs-utils), 4testing variants
  mapfile -t repos < <(yq -r '.docservice.image.repository, .tests.image.repository' "$VALUES_FILE" \
                         | sed 's#^onlyoffice/#onlyoffice/4testing-#' | sort -u)
  echo "Looking for the newest ${values_version}-N tag in: ${repos[*]}"
  found="$(latest_common_tag "$values_version" "${repos[@]}")" || true
  if [[ -n "$found" ]]; then
    source="4testing"; tag="$found"
    echo "Newest 4testing build of ${values_version}: ${tag}"
  elif [[ "$latest_is_default" == "true" ]]; then
    echo "::warning::No 4testing build of ${values_version} found, falling back to images.tag '${values_tag}'"
    source="auto"
  else
    echo "::error::No 4testing build of ${values_version} found"; exit 1
  fi
fi

tag="${tag:-$values_tag}"
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
