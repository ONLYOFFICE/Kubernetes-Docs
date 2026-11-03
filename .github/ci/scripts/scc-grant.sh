#!/usr/bin/env bash
# Adds users or groups to an existing SecurityContextConstraints object.
# Same effect as `oc adm policy add-scc-to-user|add-scc-to-group`, but needs only kubectl,
# and works on MicroShift too (does not rely on system:openshift:scc:* cluster roles).
#
# usage: scc-grant.sh <scc> <user|group> <subject>...
#   scc-grant.sh anyuid user system:serviceaccount:docs:documentserver
#   scc-grant.sh anyuid group system:serviceaccounts:deps
set -euo pipefail

SCC="$1" KIND="$2"; shift 2
field="users"; [[ "$KIND" == "group" ]] && field="groups"

kubectl get scc "$SCC" -o json \
  | jq --arg f "$field" '.[$f] = ((.[$f] // []) + $ARGS.positional | unique)' --args "$@" \
  | kubectl replace -f -
echo "SCC ${SCC}: added ${KIND}(s) $*"
