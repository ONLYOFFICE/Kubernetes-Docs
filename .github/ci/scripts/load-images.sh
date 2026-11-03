#!/usr/bin/env bash
# Pulls images on the runner (authenticated if docker login was done) and loads them into the cluster.
# Images already present locally are not pulled again.
#
# usage: load-images.sh <kind|openshift> <image>...
set -euo pipefail

PLATFORM="$1"; shift
images=("$@")

for img in "${images[@]}"; do
  docker image inspect "$img" > /dev/null 2>&1 || docker pull -q "$img"
done

case "$PLATFORM" in
  kind)
    kind load docker-image --name "${KIND_CLUSTER:-ci}" "${images[@]}"
    ;;
  openshift)
    # CRI-O inside the MicroShift container shares containers-storage with podman
    for img in "${images[@]}"; do
      docker save "$img" | sudo podman exec -i microshift-okd podman load -q
    done
    sudo podman exec microshift-okd crictl images | grep onlyoffice || true
    ;;
  *) echo "unknown platform $PLATFORM"; exit 1 ;;
esac
