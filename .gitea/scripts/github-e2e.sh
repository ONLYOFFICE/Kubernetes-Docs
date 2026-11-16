#!/usr/bin/env bash
# Runs the chart e2e tests on GitHub for a Gitea PR and reports the result back to Gitea.
#
#  1. waits until the PR head commit is mirrored to GitHub (git.onlyoffice.com -> github.com)
#  2. starts .github/workflows/chart-e2e.yaml (workflow_dispatch) on the PR branch at that commit
#  3. follows the run until it completes
#  4. sets the Gitea commit status "chart-e2e / github" with a link to the run; exits 1 unless the run succeeded
#
# PR description directives are passed on as workflow inputs (same syntax as .github/ci/README.md):
#   ci-images-source: 4testing
#   ci-images-tag: 10.0.0-12
#
# Env in: GH_TOKEN, GH_REPO, GITEA_TOKEN, GITEA_URL, GITEA_REPO, PR_NUMBER, PR_TITLE, PR_BODY_EVENT,
#         HEAD_REF, HEAD_SHA, BASE_REF
#         WORKFLOW         (default chart-e2e.yaml)
#         MIRROR_TIMEOUT   seconds to wait for the mirror (default 1800)
#         POLL_INTERVAL    seconds between status checks (default 30)

set -euo pipefail

: "${GH_TOKEN:?secret E2E_GITHUB_TOKEN is not set}" "${GH_REPO:?}" "${HEAD_REF:?}" "${HEAD_SHA:?}"
WORKFLOW="${WORKFLOW:-chart-e2e.yaml}"
MIRROR_TIMEOUT="${MIRROR_TIMEOUT:-1800}"
POLL_INTERVAL="${POLL_INTERVAL:-30}"
GH_API="https://api.github.com/repos/${GH_REPO}"
STATUS_CONTEXT="chart-e2e / github"

RESP="$(mktemp)"
RUN_ID=""
RUN_URL=""
DONE=false

# gh_api METHOD PATH [JSON]: body goes to $RESP, prints the HTTP code ("000" on network errors)
gh_api() {
  local args=(-sS -o "$RESP" -w '%{http_code}' -X "$1"
    -H "Authorization: Bearer ${GH_TOKEN}"
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28")
  [[ -n "${3:-}" ]] && args+=(-H "Content-Type: application/json" -d "$3")
  curl "${args[@]}" "${GH_API}$2" || true   # -w prints 000 on network errors
}

# Commit status on Gitea, best effort: the job result is what counts
gitea_status() {  # state description [target_url]
  [[ -n "${GITEA_TOKEN:-}" && -n "${GITEA_URL:-}" && -n "${GITEA_REPO:-}" ]] || return 0
  local data
  data=$(jq -nc --arg s "$1" --arg d "$2" --arg u "${3:-}" --arg c "$STATUS_CONTEXT" \
    '{state: $s, description: $d, context: $c} + (if $u == "" then {} else {target_url: $u} end)')
  curl -fsS -o /dev/null -X POST -H "Authorization: token ${GITEA_TOKEN}" -H "Content-Type: application/json" \
    -d "$data" "${GITEA_URL}/api/v1/repos/${GITEA_REPO}/statuses/${HEAD_SHA}" \
    || echo "::warning::Could not set the Gitea commit status (${1})"
}

on_exit() {
  local rc=$?
  rm -f "$RESP"
  if [[ "$DONE" != true ]]; then
    gitea_status error "Trigger failed before the GitHub run finished" "$RUN_URL"
  fi
  return $rc
}
trap on_exit EXIT

on_cancel() {
  echo "::warning::Cancelled"
  if [[ -n "$RUN_ID" ]]; then
    echo "Cancelling GitHub run ${RUN_URL}"
    gh_api POST "/actions/runs/${RUN_ID}/cancel" > /dev/null || true
  fi
  exit 1
}
trap on_cancel INT TERM

# ---------------------------------------------------------------- inputs

# PR body is read live, so "Re-run" picks up an edited description
PR_BODY="${PR_BODY_EVENT:-}"
if [[ -n "${PR_NUMBER:-}" && -n "${GITEA_URL:-}" ]]; then
  if body=$(curl -fsSL --retry 3 -H "Authorization: token ${GITEA_TOKEN}" \
       "${GITEA_URL}/api/v1/repos/${GITEA_REPO}/pulls/${PR_NUMBER}" | jq -r '.body // ""'); then
    PR_BODY="$body"
  else
    echo "::warning::Could not read the PR description from the Gitea API, using the event payload"
  fi
fi

directive() {
  printf '%s\n' "$PR_BODY" | tr -d '\r' \
    | sed -n -E "s/^[[:space:]]*$1:[[:space:]]*([^[:space:]]+)[[:space:]]*$/\1/p" | tail -n1
}
images_source="$(directive ci-images-source)"
images_tag="$(directive ci-images-tag)"

# The body is untrusted; .github/ci/scripts/resolve-images.sh validates again on GitHub
case "$images_source" in
  ""|auto|release|4testing|4testing-latest) ;;
  *) echo "::error::Unknown ci-images-source '${images_source}' (allowed: auto, release, 4testing, 4testing-latest)"; exit 1 ;;
esac
if [[ -n "$images_tag" && ! "$images_tag" =~ ^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$ ]]; then
  echo "::error::Invalid ci-images-tag '${images_tag}'"; exit 1
fi

DISPATCH_ID="gitea-${PR_NUMBER:-0}-${HEAD_SHA:0:8}-$(date +%s)"
title="PR #${PR_NUMBER:-?} ${PR_TITLE:-$HEAD_REF}"
title="${title:0:200}"

# ---------------------------------------------------------------- 1. wait for the mirror

echo "Waiting for ${HEAD_SHA} on ${GH_REPO}:${HEAD_REF} (up to ${MIRROR_TIMEOUT}s)"
gitea_status pending "Waiting for the GitHub mirror"
deadline=$((SECONDS + MIRROR_TIMEOUT))
while :; do
  mirrored=false
  code=$(gh_api GET "/git/ref/heads/${HEAD_REF}")
  if [[ "$code" == 200 ]]; then
    branch_sha=$(jq -r '.object.sha' "$RESP")
    if [[ "$branch_sha" == "$HEAD_SHA" ]]; then
      mirrored=true
    else
      # The branch may already be ahead of the PR commit (a newer push); it only has to contain it
      code=$(gh_api GET "/compare/${HEAD_SHA}...${branch_sha}")
      [[ "$code" == 200 ]] && [[ "$(jq -r '.status' "$RESP")" =~ ^(ahead|identical)$ ]] && mirrored=true
    fi
  elif [[ "$code" == 401 || "$code" == 403 ]]; then
    echo "::error::GitHub API: HTTP ${code} $(jq -r '.message // empty' "$RESP" 2>/dev/null). Check E2E_GITHUB_TOKEN."
    exit 1
  fi
  [[ "$mirrored" == true ]] && break
  if (( SECONDS >= deadline )); then
    echo "::error::${HEAD_SHA} did not reach ${GH_REPO}:${HEAD_REF} in ${MIRROR_TIMEOUT}s. Is the push mirror working?"
    exit 1
  fi
  sleep 20
done
echo "Mirrored"

# ---------------------------------------------------------------- 2. start the run

inputs=$(jq -nc --arg src "$images_source" --arg tag "$images_tag" --arg base "${BASE_REF:-}" \
  --arg sha "$HEAD_SHA" --arg title "$title" --arg id "$DISPATCH_ID" '
  {"base-ref": $base, sha: $sha, title: $title, "dispatch-id": $id}
  + (if $src == "" then {} else {"images-source": $src} end)
  + (if $tag == "" then {} else {"images-tag": $tag} end)')
echo "Dispatching ${WORKFLOW} on ${HEAD_REF}: ${inputs}"

# return_run_details makes GitHub answer 200 with the run id; without it (204) the run is looked up by dispatch-id
code=$(gh_api POST "/actions/workflows/${WORKFLOW}/dispatches" \
  "$(jq -nc --arg ref "$HEAD_REF" --argjson inputs "$inputs" '{ref: $ref, inputs: $inputs, return_run_details: true}')")
if [[ "$code" == 422 ]] && grep -q return_run_details "$RESP"; then
  code=$(gh_api POST "/actions/workflows/${WORKFLOW}/dispatches" \
    "$(jq -nc --arg ref "$HEAD_REF" --argjson inputs "$inputs" '{ref: $ref, inputs: $inputs}')")
fi
case "$code" in
  200) RUN_ID=$(jq -r '.workflow_run_id // empty' "$RESP") ;;
  204) ;;
  *)
    echo "::error::Dispatch failed: HTTP ${code} $(cat "$RESP")"
    echo "::error::The branch must contain .github/workflows/${WORKFLOW} with the 'sha', 'title', 'dispatch-id', 'base-ref' inputs."
    exit 1 ;;
esac

if [[ -z "$RUN_ID" ]]; then
  echo "Looking up the run by [${DISPATCH_ID}]"
  for _ in $(seq 1 30); do
    sleep 10
    code=$(gh_api GET "/actions/workflows/${WORKFLOW}/runs?event=workflow_dispatch&per_page=50")
    [[ "$code" == 200 ]] || continue
    RUN_ID=$(jq -r --arg id "[${DISPATCH_ID}]" \
      '[.workflow_runs[] | select(.display_title | endswith($id))][0].id // empty' "$RESP")
    [[ -n "$RUN_ID" ]] && break
  done
  [[ -n "$RUN_ID" ]] || { echo "::error::Dispatched, but the GitHub run was not found"; exit 1; }
fi
RUN_URL="https://github.com/${GH_REPO}/actions/runs/${RUN_ID}"

echo "GitHub run: ${RUN_URL}"
gitea_status pending "Running on GitHub" "$RUN_URL"

# ---------------------------------------------------------------- 3. follow it

print_jobs() {
  if [[ "$(gh_api GET "/actions/runs/${RUN_ID}/jobs?per_page=100")" == 200 ]]; then
    jq -r '.jobs[] | "  \(.conclusion // .status | ascii_upcase)\t\(.name)"' "$RESP" | sort -k2
  fi
}

last="" errors=0 polls=0
while :; do
  code=$(gh_api GET "/actions/runs/${RUN_ID}")
  if [[ "$code" != 200 ]]; then
    errors=$((errors + 1))
    echo "::warning::GitHub API: HTTP ${code} (${errors} in a row)"
    (( errors >= 20 )) && { echo "::error::Lost track of ${RUN_URL}"; exit 1; }
    sleep "$POLL_INTERVAL"; continue
  fi
  errors=0
  status=$(jq -r '.status' "$RESP")
  conclusion=$(jq -r '.conclusion // ""' "$RESP")
  [[ "$status" == completed ]] && break
  if [[ "$status" != "$last" ]] || (( polls % 10 == 0 )); then
    echo "[$(date -u +%H:%M:%S)] ${status}"
    print_jobs
    last="$status"
  fi
  polls=$((polls + 1))
  sleep "$POLL_INTERVAL"
done

# ---------------------------------------------------------------- 4. report

echo
echo "Result: ${conclusion}"
print_jobs
echo
echo "GitHub run: ${RUN_URL}"

DONE=true
case "$conclusion" in
  success)
    gitea_status success "Passed on GitHub" "$RUN_URL"
    exit 0 ;;
  cancelled)
    gitea_status error "Cancelled on GitHub" "$RUN_URL"
    echo "::error::GitHub run was cancelled: ${RUN_URL}"
    exit 1 ;;
  *)
    gitea_status failure "Failed on GitHub (${conclusion})" "$RUN_URL"
    echo "::error::GitHub run ${conclusion}: ${RUN_URL}"
    exit 1 ;;
esac
