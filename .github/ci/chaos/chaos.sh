#!/usr/bin/env bash
# Resilience (chaos) scenarios against a release already deployed by deploy-test.sh.
#
# Every scenario: start an availability probe -> inject a fault -> remove it -> wait until the
# infrastructure (pods in "deps" and the NFS server) is back, then until Docs is Ready and
# /healthcheck is "true" -> quick smoke subset.
# A scenario fails if Docs does not recover ON ITS OWN within RECOVERY_TIMEOUT (no restarts by CI),
# a smoke check fails after recovery (or during the fault, for "degraded but working" scenarios),
# or a MAX_* threshold below is exceeded.
#
# Report columns:
#   outage      longest continuous period with /healthcheck != true (whole scenario)
#   infra       seconds from fault removal until deps + NFS pods are all Ready again
#   Docs lag    seconds from that moment until Docs is Ready and healthy: Docs' own recovery time
#   smoke       duration of the smoke subset after recovery (catches hangs /healthcheck does not see)
#
# env: PLATFORM            kind | openshift   (node restart and Chaos Mesh scenarios are kind only)
#      DOCS_NAMESPACE      (default docs)
#      KIND_CLUSTER        kind cluster name (node restart scenario)
#      CHAOS_ONLY          regex, run only scenarios whose name matches
#      CHAOS_SKIP          regex, skip scenarios whose name matches
#      CHAOS_MESH          1 = install Chaos Mesh and run network/stress scenarios (kind only)
#      CHAOS_MESH_VERSION  Chaos Mesh chart version
#      FAULT_DURATION      seconds a network fault is held (default 60)
#      RECOVERY_TIMEOUT    seconds to recover after the fault is removed (default 300)
#      MAX_DOWNTIME        seconds; fail when the longest outage is longer   (default: report only)
#      MAX_DOCS_LAG        seconds; fail when Docs lag is longer             (default: report only)
#      MAX_SMOKE           seconds; fail when the smoke subset takes longer  (default: report only)
set -euo pipefail

CI_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NS="${DOCS_NAMESPACE:-docs}"
DEPS_NS=deps
NFS_NS=default   # NFS Server Provisioner (kind); on OpenShift there is no pod there, which is fine
PLATFORM="${PLATFORM:-kind}"
FAULT_DURATION="${FAULT_DURATION:-60}"
RECOVERY_TIMEOUT="${RECOVERY_TIMEOUT:-300}"
MAX_DOWNTIME="${MAX_DOWNTIME:-}"
MAX_DOCS_LAG="${MAX_DOCS_LAG:-}"
MAX_SMOKE="${MAX_SMOKE:-}"
CHAOS_MESH_VERSION="${CHAOS_MESH_VERSION:-2.8.4}"
# shellcheck source=../scripts/diagnose.sh
source "$CI_DIR/scripts/diagnose.sh"

export FILES_URL="http://smoke-files.deps.svc.cluster.local:8080"
# Covers DB/cache (CommandService), queue + converter (async conversion), Document Builder
SMOKE_QUICK='^(healthcheck|command_version|command_unknown_document|convert_async_with_polling|docbuilder)$'

# ---------------------------------------------------------------- access to Docs

set_ds_url() {
  if [[ "$PLATFORM" == "openshift" ]]; then
    DS_URL="http://${ROUTE_HOST:?}"
  else
    # node IP is re-read: it can change after a node restart
    DS_URL="http://$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null):30888"
  fi
  export DS_URL
}

# 1s timeout: a hanging healthcheck counts as down and keeps the probe at ~1 sample per 1-2s
healthy() { [[ "$(curl -s -m 1 "$DS_URL/healthcheck" 2>/dev/null)" == "true" ]]; }

smoke() {  # smoke <regex>; no step summary per call, the chaos table is written at the end
  GITHUB_STEP_SUMMARY='' SMOKE_ONLY="$1" python3 "$CI_DIR/smoke/smoke.py"
}

# ---------------------------------------------------------------- probe

# Background loop: one /healthcheck per second, "<epoch> <1|0>" per line
probe_start() {
  PROBE_LOG=$(mktemp)
  ( while :; do
      if healthy; then echo "$(date +%s) 1"; else echo "$(date +%s) 0"; fi
      sleep 1
    done ) > "$PROBE_LOG" 2>/dev/null &
  PROBE_PID=$!
}

# Prints the longest continuous outage in seconds (by timestamps, not by sample count)
probe_stop() {
  kill "$PROBE_PID" 2>/dev/null || true
  wait "$PROBE_PID" 2>/dev/null || true
  awk '$2 == 0 { if (!start) start = $1; cur = $1 - start + 1; if (cur > max) max = cur }
       $2 == 1 { start = 0 }
       END { print max + 0 }' "$PROBE_LOG"
}

# ---------------------------------------------------------------- recovery

# "<ready> <total>" of non-completed, non-terminating pods in a namespace
pod_counts() {
  kubectl get pods -n "$1" -o json 2>/dev/null | jq -r '
    [.items[] | select(.status.phase != "Succeeded" and .metadata.deletionTimestamp == null)]
    | "\([.[] | select(.status.conditions // [] | any(.type == "Ready" and .status == "True"))] | length) \(length)"'
}

# All pods Ready and at least as many as before the scenario: a killed pod that has not been
# recreated yet must not look like "everything is Ready"
ns_ready() {  # ns_ready <namespace> <minimum pod count>
  local ready total
  read -r ready total < <(pod_counts "$1") || return 1
  [[ -n "${total:-}" ]] && (( ready == total && total >= $2 ))
}

infra_ready() { ns_ready "$DEPS_NS" "$BASE_DEPS" && ns_ready "$NFS_NS" "$BASE_NFS"; }
docs_ready()  { ns_ready "$NS" "$BASE_DOCS" && healthy; }

# Sets INFRA_TIME and DOCS_LAG (seconds, "-" if not reached)
wait_recovered() {
  local start=$SECONDS deadline=$((SECONDS + RECOVERY_TIMEOUT)) t_infra=""
  INFRA_TIME="-"; DOCS_LAG="-"
  while (( SECONDS < deadline )); do
    set_ds_url
    if [[ -z "$t_infra" ]] && infra_ready; then
      t_infra=$SECONDS; INFRA_TIME=$((t_infra - start))
      echo "infrastructure Ready after ${INFRA_TIME}s"
    fi
    if [[ -n "$t_infra" ]] && docs_ready; then
      DOCS_LAG=$((SECONDS - t_infra))
      echo "Docs Ready and healthy ${DOCS_LAG}s after the infrastructure"
      return 0
    fi
    sleep 1
  done
  return 1
}

# Container restarts of Docs pods: a dependency failure should not need a Docs restart
docs_restarts() {
  kubectl get pods -n "$NS" -o json | jq '[.items[].status.containerStatuses[]?.restartCount] | add // 0'
}

pod_total() { local r t; read -r r t < <(pod_counts "$1"); echo "${t:-0}"; }

# ---------------------------------------------------------------- scenario runner

results=()
failed=0

over() {  # over <value> <limit>: true if a limit is set and the value is a number above it
  [[ -n "$2" && "$1" =~ ^[0-9]+$ ]] && (( $1 > $2 ))
}

run() {  # run <name> <function> [args...]
  local name="$1"; shift
  [[ -n "${CHAOS_ONLY:-}" && ! "$name" =~ ${CHAOS_ONLY} ]] && return 0
  [[ -n "${CHAOS_SKIP:-}" && "$name" =~ ${CHAOS_SKIP} ]] && return 0

  echo "::group::chaos: ${name}"
  local status=PASS note="" t0=$SECONDS r0 outage smoke_time="-" ts
  BASE_DEPS=$(pod_total "$DEPS_NS"); BASE_NFS=$(pod_total "$NFS_NS"); BASE_DOCS=$(pod_total "$NS")
  INFRA_TIME="-"; DOCS_LAG="-"
  r0=$(docs_restarts)
  set_ds_url
  probe_start

  if ! "$@"; then
    status=FAIL; note="scenario step failed"
  elif ! wait_recovered; then
    status=FAIL; note="not recovered in ${RECOVERY_TIMEOUT}s"
    diagnose "$NS"; diagnose "$DEPS_NS"
  fi
  outage=$(probe_stop)

  if [[ "$status" == PASS ]]; then
    ts=$SECONDS
    smoke "$SMOKE_QUICK" || { status=FAIL; note="smoke failed after recovery"; }
    smoke_time=$((SECONDS - ts))
  fi
  if [[ "$status" == PASS ]]; then
    if over "$outage" "$MAX_DOWNTIME"; then
      status=FAIL; note="outage ${outage}s > MAX_DOWNTIME ${MAX_DOWNTIME}s"
    elif over "$DOCS_LAG" "$MAX_DOCS_LAG"; then
      status=FAIL; note="Docs lag ${DOCS_LAG}s > MAX_DOCS_LAG ${MAX_DOCS_LAG}s"
    elif over "$smoke_time" "$MAX_SMOKE"; then
      status=FAIL; note="smoke ${smoke_time}s > MAX_SMOKE ${MAX_SMOKE}s"
    fi
  fi

  results+=("${name}|${status}|${outage}|${INFRA_TIME}|${DOCS_LAG}|${smoke_time}|$(( $(docs_restarts) - r0 ))|$((SECONDS - t0))|${note}")
  echo "::endgroup::"
  if [[ "$status" != PASS ]]; then
    echo "::error::chaos ${name}: ${note}"
    failed=$((failed + 1))
  fi
}

# ---------------------------------------------------------------- fault helpers

# Hard kill (no graceful shutdown) of pods whose name matches a regex: simulates a crash
kill_pods() {  # kill_pods <namespace> <name regex>
  local ns="$1" re="$2" pods
  mapfile -t pods < <(kubectl get pods -n "$ns" -o name | grep -E "$re" || true)
  (( ${#pods[@]} )) || { echo "::error::no pods match ${re} in ${ns}"; return 1; }
  echo "killing: ${pods[*]}"
  kubectl delete -n "$ns" "${pods[@]}" --grace-period=0 --force --wait=false || return 1
  sleep 5   # let the probe see the outage before the recovery wait starts
}

# Applies a Chaos Mesh experiment, checks it really reached some containers, holds it, removes it.
# With a smoke regex, runs it while the fault is active ("degraded but working"),
# otherwise just waits FAULT_DURATION.
# shellcheck disable=SC2016  # ${DOCS_NS} is an envsubst variable list, not a shell expansion
mesh() {  # mesh <manifest name> [smoke regex during the fault]
  local rendered records rc=0
  rendered=$(mktemp --suffix .yaml)
  DOCS_NS="$NS" envsubst '${DOCS_NS}' < "$CI_DIR/chaos/mesh/$1.yaml" > "$rendered"
  kubectl apply -f "$rendered" || return 1

  # Injection is asynchronous; without this the smoke may run before the fault exists
  if ! kubectl wait -f "$rendered" --for=condition=AllInjected --timeout=120s; then
    echo "::error::$1: fault was not injected"
    kubectl describe -f "$rendered" | tail -40 || true
    rc=1
  else
    # AllInjected is also true when the selector matched nothing
    records=$(kubectl get -f "$rendered" -o json | jq '.status.experiment.containerRecords // [] | length')
    echo "$1: injected into ${records} container(s)"
    if (( records == 0 )); then
      echo "::error::$1: selector matched no pods"; rc=1
    elif [[ -n "${2:-}" ]]; then
      smoke "$2" || rc=1
    else
      sleep "$FAULT_DURATION"
    fi
  fi

  # Deletion waits for Chaos Mesh's finalizer, i.e. until the fault is recovered in every pod
  kubectl delete -f "$rendered" --wait=true --timeout=120s || rc=1
  return "$rc"
}

install_chaos_mesh() {
  echo "::group::Chaos Mesh ${CHAOS_MESH_VERSION}"
  helm repo add chaos-mesh https://charts.chaos-mesh.org > /dev/null
  helm repo update chaos-mesh > /dev/null
  # kind nodes run containerd; no dashboard, no DNS server (DNSChaos is not used)
  helm upgrade --install chaos-mesh chaos-mesh/chaos-mesh --version "$CHAOS_MESH_VERSION" \
    -n chaos-mesh --create-namespace \
    --set chaosDaemon.runtime=containerd \
    --set chaosDaemon.socketPath=/run/containerd/containerd.sock \
    --set controllerManager.replicaCount=1 \
    --set dashboard.create=false \
    --set dnsServer.create=false \
    --wait --timeout 10m || { diagnose chaos-mesh; return 1; }
  echo "::endgroup::"
}

# ---------------------------------------------------------------- scenarios

# Requested while no converter runs: the task must wait in the queue and finish when it is back
convert_while_converter_down() {
  local replicas pid rc=0
  replicas=$(kubectl get deploy converter -n "$NS" -o jsonpath='{.spec.replicas}')
  kubectl scale deploy/converter -n "$NS" --replicas=0 || return 1
  kubectl wait pod -n "$NS" -l app=converter --for=delete --timeout=120s || true
  CONVERT_TIMEOUT=300 smoke '^convert_async_with_polling$' > /tmp/convert-pending.log 2>&1 &
  pid=$!
  sleep 30
  kubectl scale deploy/converter -n "$NS" --replicas="$replicas"
  wait "$pid" || rc=1
  cat /tmp/convert-pending.log
  return "$rc"
}

node_restart() {
  local node="${KIND_CLUSTER:?}-control-plane"
  echo "docker restart ${node}"
  docker restart "$node"
  for _ in $(seq 60); do kubectl get --raw /readyz > /dev/null 2>&1 && return 0; sleep 5; done
  echo "::error::API server did not come back"; return 1
}

kubectl apply -n "$NS" -f "$CI_DIR/chaos/nodeport.yaml"
set_ds_url
for _ in $(seq 60); do healthy && break; sleep 2; done
healthy || { echo "::error::Docs is not healthy at ${DS_URL} before chaos"; exit 1; }

# Docs components
run docservice-kill           kill_pods "$NS" '^pod/docservice-'
run converter-kill            kill_pods "$NS" '^pod/converter-'
run convert-converter-down    convert_while_converter_down

# Dependencies (Docs must reconnect by itself)
run postgres-kill             kill_pods "$DEPS_NS" '^pod/postgres-[0-9]+$'
run pgbouncer-kill            kill_pods "$DEPS_NS" '^pod/postgres-pooler-rw-'
run rabbitmq-kill             kill_pods "$DEPS_NS" '^pod/rabbitmq-server-'
run valkey-kill               kill_pods "$DEPS_NS" '^pod/valkey-'
run nfs-server-kill           kill_pods "$NFS_NS"  '^pod/nfs-server-nfs-server-provisioner-'

# Network and resource faults
if [[ "${CHAOS_MESH:-0}" == 1 && "$PLATFORM" == kind ]]; then
  install_chaos_mesh
  run net-partition-postgres  mesh partition-docs-postgres
  run net-partition-rabbitmq  mesh partition-docs-rabbitmq
  run net-delay-deps          mesh delay-docs-deps     "$SMOKE_QUICK"
  run cpu-stress-converter    mesh stress-converter-cpu '^convert_async_with_polling$'
fi

# Whole node power cycle: the heaviest one, last.
# Docs restarts are expected here: kubelet restarts every container after a node reboot.
[[ "$PLATFORM" == kind ]] && run node-restart node_restart

# ---------------------------------------------------------------- report

sec() { [[ "$1" =~ ^[0-9]+$ ]] && echo "${1}s" || echo "$1"; }
{
  echo "### Chaos (${PLATFORM})"
  echo "| scenario | result | outage | infra | Docs lag | smoke | Docs restarts | took | note |"
  echo "|---|---|---|---|---|---|---|---|---|"
  for r in "${results[@]}"; do
    IFS='|' read -r n s o inf lag sm rs t note <<< "$r"
    echo "| \`${n}\` | $([[ $s == PASS ]] && echo ✅ || echo ❌) ${s} | $(sec "$o") | $(sec "$inf") | $(sec "$lag") | $(sec "$sm") | ${rs} | $(sec "$t") | ${note} |"
  done
  echo
  echo "outage: longest period with /healthcheck != true · infra: fault removed → deps + NFS Ready ·"
  echo "Docs lag: infra Ready → Docs Ready and healthy · smoke: quick smoke after recovery"
} | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"

(( failed == 0 ))
