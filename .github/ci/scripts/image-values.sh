#!/usr/bin/env bash
# Prints a values override that points every onlyoffice/* image of the chart
# to onlyoffice/<prefix>* and sets the global images.tag.
# The list of images is taken from values.yaml, so new jobs/services are picked up automatically.
#
# usage: image-values.sh <values.yaml> <prefix> <tag>
set -euo pipefail

VALUES_FILE="$1" PREFIX="$2" TAG="$3"
export PREFIX TAG

yq '
  [ .. | select(tag == "!!map" and has("repository"))
       | select(.repository | test("^onlyoffice/"))
       | {"p": path, "r": (.repository | sub("^onlyoffice/", "onlyoffice/" + strenv(PREFIX)))} ]
  | .[] as $i ireduce ({}; setpath($i.p + ["repository"]; $i.r))
  | .images.tag = strenv(TAG)
' "$VALUES_FILE"
