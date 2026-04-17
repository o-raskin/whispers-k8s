#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-whispers}"
API_RELEASE="${API_RELEASE:-whispers}"
WEB_RELEASE="${WEB_RELEASE:-whispers-webapp}"
TURN_RELEASE="${TURN_RELEASE:-coturn}"
API_VALUES="${API_VALUES:-}"
WEB_VALUES="${WEB_VALUES:-}"
TURN_VALUES="${TURN_VALUES:-}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null
helm repo update >/dev/null

kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.hostNetwork=true \
  --set controller.dnsPolicy=ClusterFirstWithHostNet \
  --set controller.service.type=ClusterIP

api_args=()
web_args=()
turn_args=()

if [[ -n "${API_VALUES}" ]]; then
  api_args+=(-f "${API_VALUES}")
fi

if [[ -n "${WEB_VALUES}" ]]; then
  web_args+=(-f "${WEB_VALUES}")
fi

if [[ -n "${TURN_VALUES}" ]]; then
  turn_args+=(-f "${TURN_VALUES}")
fi

helm upgrade --install "${API_RELEASE}" "${REPO_ROOT}/whispers" \
  --namespace "${NAMESPACE}" \
  "${api_args[@]}"

helm upgrade --install "${WEB_RELEASE}" "${REPO_ROOT}/whispers-webapp" \
  --namespace "${NAMESPACE}" \
  "${web_args[@]}"

helm upgrade --install "${TURN_RELEASE}" "${REPO_ROOT}/coturn" \
  --namespace "${NAMESPACE}" \
  "${turn_args[@]}"
