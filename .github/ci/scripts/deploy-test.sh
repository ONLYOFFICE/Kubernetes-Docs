#!/usr/bin/env bash
# Loads the chart images, installs (or upgrades) the chart, runs `helm test` and smoke tests.
#
# env: PLATFORM        kind | openshift
#      HELM_ARGS       values arguments, e.g. "-f a.yaml -f b.yaml"
#      RELEASE         release name (default documentserver, as in README/OPENSHIFT.md)
#      DOCS_NAMESPACE  (default docs)
#      BASE_CHART      optional path: install this chart first, then upgrade to the PR chart
#      ROUTE_HOST      openshift: smoke tests go through the Route
set -euo pipefail

CI_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RELEASE="${RELEASE:-documentserver}"
NS="${DOCS_NAMESPACE:-docs}"
read -r -a helm_args <<< "${HELM_ARGS}"
# shellcheck source=diagnose.sh
source "$CI_DIR/scripts/diagnose.sh"

echo "::group::Images"
charts=(.)
[[ -n "${BASE_CHART:-}" ]] && charts+=("$BASE_CHART")
mapfile -t images < <(
  for c in "${charts[@]}"; do helm template "$RELEASE" "$c" -n "$NS" "${helm_args[@]}"; done \
    | yq ea -N '.. | select(tag == "!!map" and has("image")) | .image' | sort -u
)
printf '%s\n' "${images[@]}"
bash "$CI_DIR/scripts/load-images.sh" "$PLATFORM" "${images[@]}"
echo "::endgroup::"

if [[ -n "${BASE_CHART:-}" ]]; then
  echo "::group::Install base chart"
  helm install "$RELEASE" "$BASE_CHART" -n "$NS" "${helm_args[@]}" --wait --timeout 15m \
    || { diagnose "$NS"; exit 1; }
  echo "::endgroup::"
fi

echo "::group::Install / upgrade chart"
helm upgrade --install "$RELEASE" . -n "$NS" "${helm_args[@]}" --wait --timeout 15m \
  || { diagnose "$NS"; exit 1; }
kubectl get pods,pvc -n "$NS" -o wide
echo "::endgroup::"

echo "::group::helm test"
helm test "$RELEASE" -n "$NS" --logs --timeout 10m || { diagnose "$NS"; exit 1; }
echo "::endgroup::"

echo "::group::Smoke tests"
export FILES_URL="http://smoke-files.deps.svc.cluster.local:8080"
if [[ "$PLATFORM" == "openshift" ]]; then
  kubectl get route -n "$NS" -o wide
  export DS_URL="http://${ROUTE_HOST:?}"
else
  kubectl port-forward -n "$NS" svc/documentserver 8888:8888 > /tmp/port-forward.log 2>&1 &
  export DS_URL="http://127.0.0.1:8888"
fi
for _ in $(seq 60); do curl -sf "$DS_URL/healthcheck" > /dev/null && break; sleep 2; done
python3 "$CI_DIR/smoke/smoke.py"
echo "::endgroup::"
