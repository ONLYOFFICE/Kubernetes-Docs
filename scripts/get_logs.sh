#!/bin/bash
for i in `kubectl get pod | grep -i converter | awk '{print $1}'`; do
  kubectl logs $i > $i.txt
done

for i in `kubectl get pod | grep -i docservice | awk '{print $1}'`; do
  kubectl logs $i -c proxy > $i-PROXY.txt
  kubectl logs $i -c docservice > $i-DOCSERVICE.txt
done

for i in `kubectl get pod | grep -i spellchecker | awk '{print $1}'`; do
  kubectl logs $i > $i.txt
done
