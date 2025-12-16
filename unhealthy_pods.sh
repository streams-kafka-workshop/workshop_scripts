#!/usr/bin/env bash
set -euo pipefail

NS_RE='(globex|kafka|registry|openshift-operators|devspaces|openshift-gitops)'

oc get pods -A --no-headers \
| awk -v ns_re="$NS_RE" '
  $1 ~ ns_re {
    split($3,a,"/");
    if ($4!="Running" || a[1]!=a[2]) print
  }
'
