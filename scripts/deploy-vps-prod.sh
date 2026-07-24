#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 [--update-dns] <app> <deploy-user> <server-ip> [repo-url] [branch]

Apps:
  family_hub
  fitness
  badge_creator

Environment:
  FAMILY_DOMAIN
  FITNESS_DOMAIN
  BADGE_CREATOR_DOMAIN
  ACME_EMAIL

Examples:
  $0 family_hub deploy 203.0.113.10 https://github.com/biswashghi/family_hub.git main
  $0 --update-dns fitness deploy 203.0.113.10 main
USAGE
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/app-registry.sh
source "${SCRIPT_DIR}/lib/app-registry.sh"

UPDATE_DNS=0
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi
if [[ "${1:-}" == "--update-dns" ]]; then
  UPDATE_DNS=1
  shift
fi

if [[ $# -lt 3 || $# -gt 5 ]]; then
  usage
  exit 1
fi

APP="$1"
DEPLOY_USER="$2"
SERVER_IP="$3"
shift 3

resolve_app "$APP"

REPO_URL="$APP_DEFAULT_REPO_URL"
BRANCH="main"
if [[ $# -eq 1 ]]; then
  if is_repo_url "$1"; then
    REPO_URL="$1"
  else
    BRANCH="$1"
  fi
elif [[ $# -eq 2 ]]; then
  REPO_URL="$1"
  BRANCH="$2"
fi

required_env() {
  local name="$1"
  local value="${!name:-}"
  if [[ -z "$value" || "$value" == "example.com" || "$value" == "admin@example.com" ]]; then
    echo "$name is required and must not be a default/example value." >&2
    exit 1
  fi
}

required_env FAMILY_DOMAIN
required_env FITNESS_DOMAIN
required_env BADGE_CREATOR_DOMAIN
required_env ACME_EMAIL

APP_DOMAIN="${!APP_DOMAIN_ENV}"
FAMILY_PORT="$(app_port family_hub)"
FITNESS_PORT="$(app_port fitness)"
BADGE_CREATOR_PORT="$(app_port badge_creator)"

if [[ ! -d "$APP_REPO_DIR" ]]; then
  echo "App repo dir not found: $APP_REPO_DIR" >&2
  exit 1
fi

if [[ ! -x "$APP_DEPLOY_SCRIPT" ]]; then
  echo "App deploy script is missing or not executable: $APP_DEPLOY_SCRIPT" >&2
  exit 1
fi

if [[ "$UPDATE_DNS" == "1" ]]; then
  "${SCRIPT_DIR}/update-gandi-dns.sh" "$APP_DOMAIN" "$SERVER_IP"
fi

"${SCRIPT_DIR}/deploy-shared-caddy.sh" \
  "$DEPLOY_USER" "$SERVER_IP" \
  "$FAMILY_DOMAIN" "$FITNESS_DOMAIN" "$BADGE_CREATOR_DOMAIN" "$ACME_EMAIL" \
  "$FAMILY_PORT" "$FITNESS_PORT" "$BADGE_CREATOR_PORT"

(
  cd "$APP_REPO_DIR"
  APP_HOST_PORT="$APP_HOST_PORT" APP_DOMAIN="$APP_DOMAIN" ACME_EMAIL="$ACME_EMAIL" \
    "$APP_DEPLOY_SCRIPT" "$DEPLOY_USER" "$SERVER_IP" "$REPO_URL" "$BRANCH"
)

VERIFY_URL="https://${APP_DOMAIN}${APP_HEALTH_PATH}"
echo "Verifying ${APP_LABEL}: ${VERIFY_URL}"
curl -fsS --retry 6 --retry-delay 10 "$VERIFY_URL" >/dev/null
echo "${APP_LABEL} deployed and verified."
