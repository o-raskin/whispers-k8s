#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-whispers}"

BACKEND_IMAGE_REPOSITORY="${BACKEND_IMAGE_REPOSITORY:-ghcr.io/o-raskin/whispers}"
BACKEND_IMAGE_TAG="${BACKEND_IMAGE_TAG:-latest}"
WEBAPP_IMAGE_REPOSITORY="${WEBAPP_IMAGE_REPOSITORY:-ghcr.io/o-raskin/whispers-webapp}"
WEBAPP_IMAGE_TAG="${WEBAPP_IMAGE_TAG:-latest}"

WEB_HOST="${WEB_HOST:-whispers.example.com}"
BACKEND_HOST="${BACKEND_HOST:-api.${WEB_HOST}}"
TURN_HOST="${TURN_HOST:-turn.example.com}"
TURN_USERNAME="${TURN_USERNAME:-user}"
TURN_PASSWORD="${TURN_PASSWORD:-user123}"

TLS_ENABLED="${TLS_ENABLED:-true}"
TLS_CERT_PATH="${TLS_CERT_PATH:-${HOME}/cert.pem}"
TLS_KEY_PATH="${TLS_KEY_PATH:-${HOME}/private-key.pem}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

install_k3s() {
  if command -v k3s >/dev/null 2>&1; then
    return
  fi

  curl -sfL https://get.k3s.io | sh -
}

ensure_kubeconfig() {
  mkdir -p "${HOME}/.kube"

  sudo cp /etc/rancher/k3s/k3s.yaml "${HOME}/.kube/config"
  sudo chown "$(id -u)":"$(id -g)" "${HOME}/.kube/config"
  chmod 600 "${HOME}/.kube/config"

  export KUBECONFIG="${HOME}/.kube/config"
}

install_helm() {
  if command -v helm >/dev/null 2>&1; then
    return
  fi

  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_envsubst() {
  if command -v envsubst >/dev/null 2>&1; then
    return
  fi

  if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y gettext-base
    return
  fi

  echo "envsubst is required but not installed" >&2
  exit 1
}

wait_for_k3s() {
  kubectl wait --for=condition=Ready node --all --timeout=180s
}

create_tls_secret() {
  if [[ "${TLS_ENABLED}" != "true" ]]; then
    return
  fi

  kubectl -n "${NAMESPACE}" create secret tls whispers-webapp-tls \
    --cert="${TLS_CERT_PATH}" \
    --key="${TLS_KEY_PATH}" \
    --dry-run=client -o yaml | kubectl apply -f -
}

main() {
  install_k3s
  ensure_kubeconfig
  install_helm
  install_envsubst
  wait_for_k3s

  kubectl create namespace "${NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

  create_tls_secret

  kubectl -n "${NAMESPACE}" create secret generic coturn-auth \
    --from-literal=username="${TURN_USERNAME}" \
    --from-literal=password="${TURN_PASSWORD}" \
    --dry-run=client -o yaml | kubectl apply -f -

  local tmp_dir api_values web_values turn_values app_scheme
  tmp_dir="$(mktemp -d)"
  api_values="${tmp_dir}/values-backend.yaml"
  web_values="${tmp_dir}/values-webapp.yaml"
  turn_values="${tmp_dir}/values-coturn.yaml"

  if [[ "${TLS_ENABLED}" == "true" ]]; then
    app_scheme="https"
  else
    app_scheme="http"
  fi
  env \
    APP_SCHEME="${app_scheme}" \
    TLS_ENABLED="${TLS_ENABLED}" \
    BACKEND_IMAGE_REPOSITORY="${BACKEND_IMAGE_REPOSITORY}" \
    BACKEND_IMAGE_TAG="${BACKEND_IMAGE_TAG}" \
    WEBAPP_IMAGE_REPOSITORY="${WEBAPP_IMAGE_REPOSITORY}" \
    WEBAPP_IMAGE_TAG="${WEBAPP_IMAGE_TAG}" \
    WEB_HOST="${WEB_HOST}" \
    BACKEND_HOST="${BACKEND_HOST}" \
    TURN_HOST="${TURN_HOST}" \
    envsubst < "${REPO_ROOT}/examples/whispers-backend-k3s-values.tmpl.yaml" > "${api_values}"

  env \
    APP_SCHEME="${app_scheme}" \
    TLS_ENABLED="${TLS_ENABLED}" \
    BACKEND_IMAGE_REPOSITORY="${BACKEND_IMAGE_REPOSITORY}" \
    BACKEND_IMAGE_TAG="${BACKEND_IMAGE_TAG}" \
    WEBAPP_IMAGE_REPOSITORY="${WEBAPP_IMAGE_REPOSITORY}" \
    WEBAPP_IMAGE_TAG="${WEBAPP_IMAGE_TAG}" \
    WEB_HOST="${WEB_HOST}" \
    BACKEND_HOST="${BACKEND_HOST}" \
    TURN_HOST="${TURN_HOST}" \
    envsubst < "${REPO_ROOT}/examples/whispers-webapp-k3s-values.tmpl.yaml" > "${web_values}"

  env \
    APP_SCHEME="${app_scheme}" \
    TLS_ENABLED="${TLS_ENABLED}" \
    BACKEND_IMAGE_REPOSITORY="${BACKEND_IMAGE_REPOSITORY}" \
    BACKEND_IMAGE_TAG="${BACKEND_IMAGE_TAG}" \
    WEBAPP_IMAGE_REPOSITORY="${WEBAPP_IMAGE_REPOSITORY}" \
    WEBAPP_IMAGE_TAG="${WEBAPP_IMAGE_TAG}" \
    WEB_HOST="${WEB_HOST}" \
    BACKEND_HOST="${BACKEND_HOST}" \
    TURN_HOST="${TURN_HOST}" \
    envsubst < "${REPO_ROOT}/examples/coturn-k3s-values.tmpl.yaml" > "${turn_values}"

  helm upgrade --install whispers "${REPO_ROOT}/whispers" \
    --namespace "${NAMESPACE}" \
    -f "${api_values}"

  helm upgrade --install whispers-webapp "${REPO_ROOT}/whispers-webapp" \
    --namespace "${NAMESPACE}" \
    -f "${web_values}"

  helm upgrade --install coturn "${REPO_ROOT}/coturn" \
    --namespace "${NAMESPACE}" \
    -f "${turn_values}"

  rm -rf "${tmp_dir}"
}

main "$@"
