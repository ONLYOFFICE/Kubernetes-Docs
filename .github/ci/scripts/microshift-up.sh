#!/usr/bin/env bash
# Starts an upstream MicroShift (OKD based, no Red Hat pull secret needed) single-node cluster
# in a privileged podman container, the same way microshift-io/microshift tests itself on
# GitHub-hosted ubuntu-24.04 runners, and prepares it for the chart tests.
#
# env: MICROSHIFT_REF   git ref of microshift-io/microshift to take quickstart.sh from (default main)
#      MICROSHIFT_TAG   MicroShift image tag (default latest released)
#      ROUTE_HOST       host name for the Docs route, mapped to the node IP in /etc/hosts
# out: KUBECONFIG, MICROSHIFT_IP -> $GITHUB_ENV
set -euo pipefail

CONTAINER=microshift-okd
MICROSHIFT_REF="${MICROSHIFT_REF:-main}"
MICROSHIFT_TAG="${MICROSHIFT_TAG:-latest}"
ROUTE_HOST="${ROUTE_HOST:-docs.microshift.test}"
CI_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "::group::Start MicroShift (${MICROSHIFT_REF}, ${MICROSHIFT_TAG})"
curl -fsSL "https://raw.githubusercontent.com/microshift-io/microshift/${MICROSHIFT_REF}/src/quickstart.sh" \
  | sudo TAG="${MICROSHIFT_TAG}" GITHUB_TOKEN="${GITHUB_TOKEN:-}" bash -euo pipefail

# Healthy when greenboot healthcheck has finished (same check as upstream CI)
for _ in $(seq 100); do
  state=$(sudo podman exec "$CONTAINER" systemctl show --property=SubState --value greenboot-healthcheck 2>/dev/null || echo unknown)
  [[ "$state" == "exited" ]] && break
  sleep 10
done
[[ "$state" == "exited" ]] || { echo "::error::MicroShift is not healthy"; sudo podman logs "$CONTAINER" | tail -100; exit 1; }
echo "::endgroup::"

ip=$(sudo podman inspect -f '{{.NetworkSettings.IPAddress}}' "$CONTAINER")
echo "MicroShift node IP: ${ip}"

# kubeconfig for the runner: API is reachable on the container IP
mkdir -p "$HOME/.kube"
sudo podman exec "$CONTAINER" cat /var/lib/microshift/resources/kubeadmin/kubeconfig \
  | IP="$ip" yq '.clusters[].cluster.server = "https://" + strenv(IP) + ":6443"
                | del(.clusters[].cluster."certificate-authority-data")
                | .clusters[].cluster."insecure-skip-tls-verify" = true' > "$HOME/.kube/microshift"
export KUBECONFIG="$HOME/.kube/microshift"
kubectl get nodes -o wide
kubectl get scc

# CRI-O in the MicroShift container has no registries.conf, so short image names
# (rabbitmq:..., valkey/valkey:..., python:...) chosen by dependency operators fail with
# "short-name ... did not resolve". Resolve them on docker.io, as a regular OpenShift node does.
sudo podman exec -i "$CONTAINER" sh -euc '
  conf=/etc/containers/registries.conf
  [ -f "$conf" ] && { mkdir -p /etc/containers/registries.conf.d; conf=/etc/containers/registries.conf.d/99-ci-docker-io.conf; }
  printf "%s\n" "unqualified-search-registries = [\"docker.io\"]" "short-name-mode = \"permissive\"" > "$conf"
  echo "written $conf:"; cat "$conf"
  systemctl reload crio || systemctl restart crio
'

# Route host -> node IP (the router listens on the node's ports 80/443)
echo "${ip} ${ROUTE_HOST}" | sudo tee -a /etc/hosts

# Directories for hostPath PVs (writable for any UID, the SCC decides who runs as what)
sudo podman exec "$CONTAINER" sh -c 'for i in $(seq 1 8); do mkdir -p /var/ci-pv/$i && chmod 0777 /var/ci-pv/$i; done'
kubectl apply -f "$CI_DIR/manifests/hostpath-pvs.yaml"

{
  echo "KUBECONFIG=${KUBECONFIG}"
  echo "MICROSHIFT_IP=${ip}"
} >> "${GITHUB_ENV:-/dev/null}"
