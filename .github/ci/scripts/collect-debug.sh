#!/usr/bin/env bash
# Dumps cluster state and logs of all pods (incl. previous containers and finished hook jobs).
# usage: collect-debug.sh <out-dir>
set -uo pipefail
OUT="${1:-debug}"
mkdir -p "$OUT/logs"

kubectl get all,pvc,pv,cm,secrets,jobs -A -o wide > "$OUT/resources.txt" 2>&1
kubectl get events -A --sort-by=.lastTimestamp       > "$OUT/events.txt" 2>&1
kubectl describe pods -A                             > "$OUT/describe-pods.txt" 2>&1
kubectl describe pvc,pv -A                           > "$OUT/describe-storage.txt" 2>&1
helm list -A -a                                      > "$OUT/helm-list.txt" 2>&1
helm get all "${RELEASE:-documentserver}" -n "${DOCS_NAMESPACE:-docs}"                                  > "$OUT/helm-release.txt" 2>&1

kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{"\n"}{end}' |
while read -r ns pod; do
  kubectl logs -n "$ns" "$pod" --all-containers --prefix            > "$OUT/logs/${ns}_${pod}.log" 2>&1
  kubectl logs -n "$ns" "$pod" --all-containers --prefix --previous > "$OUT/logs/${ns}_${pod}.previous.log" 2>/dev/null \
    || rm -f "$OUT/logs/${ns}_${pod}.previous.log"
done

# Short version straight into the job log
echo "::group::Pods"; kubectl get pods -A -o wide; echo "::endgroup::"
echo "::group::Warning events"; kubectl get events -A --field-selector type=Warning --sort-by=.lastTimestamp | tail -50; echo "::endgroup::"

# OpenShift: which SCC admitted each pod
if kubectl api-resources --api-group=security.openshift.io 2>/dev/null | grep -q securitycontextconstraints; then
  kubectl get pods -A -o custom-columns='NS:.metadata.namespace,POD:.metadata.name,SCC:.metadata.annotations.openshift\.io/scc' > "$OUT/pods-scc.txt" 2>&1
  kubectl get scc -o yaml > "$OUT/scc.yaml" 2>&1
  sudo podman exec microshift-okd journalctl -u microshift --no-pager -n 2000 > "$OUT/microshift.log" 2>&1 || true
  echo "::group::Pods SCC"; cat "$OUT/pods-scc.txt"; echo "::endgroup::"
fi
