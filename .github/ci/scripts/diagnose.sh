#!/usr/bin/env bash
# Shared diagnostics, sourced by install-deps.sh and deploy-test.sh.
# Explains why workloads in a namespace are not ready. Note: when the SCC (OpenShift) or
# admission rejects pods, no pod exists at all and the reason is only in ReplicaSet/Job events.

diagnose() {
  local ns="$1"
  echo "::endgroup::"   # keep diagnostics expanded in the job log
  echo "::error::Not ready in namespace ${ns}, diagnostics follow"
  echo "--- pods";        kubectl get pods -n "$ns" -o wide || true
  echo "--- workloads";   kubectl get deploy,rs,sts,jobs -n "$ns" -o wide || true
  echo "--- pvc";         kubectl get pvc -n "$ns" -o wide || true
  echo "--- events";      kubectl get events -n "$ns" --sort-by=.lastTimestamp | tail -40 || true
  echo "--- replicasets"; kubectl describe rs -n "$ns" | sed -n '/^Events:/,/^$/p' | tail -30 || true
  echo "--- statefulsets"; kubectl describe sts -n "$ns" | sed -n '/^Events:/,/^$/p' | tail -30 || true
  echo "--- jobs";        kubectl describe jobs -n "$ns" | sed -n '/^Events:/,/^$/p' | tail -30 || true
  # Effective identity of each pod: which SCC admitted it and with which UID/GID/fsGroup
  echo "--- pod security (SCC, pod and container securityContext as admitted)"
  kubectl get pods -n "$ns" -o json 2>/dev/null | jq -r '
    .items[] | "\(.metadata.name)  scc=\(.metadata.annotations["openshift.io/scc"] // "-")
    pod: \(.spec.securityContext | tojson)
    " + ([.spec.initContainers[]?, .spec.containers[]] | map("\(.name): \(.securityContext // {} | tojson)") | join("\n    "))' || true
  for pod in $(kubectl get pods -n "$ns" -o name 2>/dev/null); do
    echo "--- describe ${pod}"; kubectl describe -n "$ns" "$pod" | sed -n '/^Containers:/,$p' | tail -60 || true
    echo "--- logs ${pod}";     kubectl logs -n "$ns" "$pod" --all-containers --tail=80 || true
    echo "--- previous logs ${pod}"; kubectl logs -n "$ns" "$pod" --all-containers --previous --tail=80 2>/dev/null || true
  done
}
