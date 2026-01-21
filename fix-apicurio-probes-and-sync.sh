#!/usr/bin/env bash
set -euo pipefail

OP_NS="${OP_NS:-openshift-operators}"
POD_PREFIX="${POD_PREFIX:-apicurio-registry-operator}"
APP_GREP="${APP_GREP:-service-registry}"

echo "==> Namespace:           ${OP_NS}"
echo "==> Pod prefix match:    ${POD_PREFIX}"
echo "==> Argo app name match: ${APP_GREP}"
echo

if ! command -v oc >/dev/null 2>&1; then
  echo "ERROR: 'oc' not found in PATH."
  exit 1
fi

if ! oc whoami >/dev/null 2>&1; then
  echo "ERROR: Not logged into an OpenShift cluster. Run 'oc login' first."
  exit 1
fi

echo "==> Finding deployments owning pods matching '${POD_PREFIX}' in '${OP_NS}'..."

deps="$(
  oc -n "${OP_NS}" get pod -o name \
  | grep "^pod/${POD_PREFIX}" \
  | while read -r p; do
      rs="$(oc -n "${OP_NS}" get "$p" -o jsonpath='{.metadata.ownerReferences[0].name}' 2>/dev/null || true)"
      if [[ -n "${rs}" ]]; then
        oc -n "${OP_NS}" get "rs/${rs}" -o jsonpath='{.metadata.ownerReferences[0].name}{"\n"}' 2>/dev/null || true
      fi
    done \
  | sort -u
)"

if [[ -z "${deps}" ]]; then
  echo "WARNING: No deployments found for pods matching '${POD_PREFIX}' in '${OP_NS}'."
else
  echo "==> Deployments to patch:"
  echo "${deps}" | sed 's/^/  - /'
  echo

  while read -r dep; do
    [[ -z "${dep}" ]] && continue
    echo "==> Patching deployment: ${OP_NS}/${dep}"

    containers="$(oc -n "${OP_NS}" get "deploy/${dep}" -o jsonpath='{range .spec.template.spec.containers[*]}{.name}{"\n"}{end}')"
    echo "${containers}" | sed 's/^/    container: /'

    while read -r c; do
      [[ -z "${c}" ]] && continue
      oc -n "${OP_NS}" patch "deploy/${dep}" --type=strategic \
        -p "{\"spec\":{\"template\":{\"spec\":{\"containers\":[{\"name\":\"${c}\",\"livenessProbe\":null,\"readinessProbe\":null,\"startupProbe\":null}]}}}}"
    done <<< "${containers}"

    echo "    done."
    echo
  done <<< "${deps}"
fi

echo "==> Forcing ArgoCD sync (patch) for applications matching '${APP_GREP}'..."

apps="$(
  oc get applications.argoproj.io -A --no-headers \
    -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name \
  | grep "${APP_GREP}" || true
)"

if [[ -z "${apps}" ]]; then
  echo "WARNING: No ArgoCD Applications found matching '${APP_GREP}'."
else
  echo "${apps}" | while read -r ns name; do
    [[ -z "${ns}" || -z "${name}" ]] && continue
    echo "==> Syncing ${ns}/${name}"
    oc -n "${ns}" patch applications.argoproj.io "${name}" --type=merge \
      -p '{"operation":{"sync":{"prune":false}}}'
  done
fi

echo
echo "Done."
