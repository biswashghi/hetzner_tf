#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 [--update-dns] <app> <deploy-user> <server-ip> [repo-url] [branch]

Application releases are independent. The shared platform must already exist:
  scripts/deploy-vps-platform.sh <deploy-user> <server-ip> <acme-email>

Examples:
  FAMILY_DOMAIN=family.example.com $0 family_hub deploy 203.0.113.10 main
  PAISA_WEB_DOMAIN=paisa.example.com PAISA_API_DOMAIN=api.paisa.example.com \\
    $0 paisa deploy 203.0.113.10 main
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
  usage >&2
  exit 1
fi

APP="$1"
DEPLOY_USER="$2"
SERVER_IP="$3"
shift 3
resolve_app "$APP"

if [[ "$APP" == "fitness" || "$APP" == "badge_creator" ]]; then
  echo "${APP} still uses the legacy host-port deployment and is not enabled on the vps-edge platform." >&2
  echo "Migrate its Compose service and route before deploying it through this wrapper." >&2
  exit 1
fi

REPO_URL="$APP_DEFAULT_REPO_URL"
BRANCH=main
if [[ $# -eq 1 ]]; then
  if is_repo_url "$1"; then REPO_URL="$1"; else BRANCH="$1"; fi
elif [[ $# -eq 2 ]]; then
  REPO_URL="$1"
  BRANCH="$2"
fi

required_env() {
  local name="$1" value="${!1:-}"
  if [[ -z "$value" || "$value" == "example.com" || "$value" == "admin@example.com" ]]; then
    echo "${name} is required and must not use an example value." >&2
    exit 1
  fi
}

case "$APP" in
  family_hub|fitness|badge_creator)
    required_env "$APP_DOMAIN_ENV"
    ;;
  paisa)
    required_env PAISA_WEB_DOMAIN
    required_env PAISA_API_DOMAIN
    ;;
  novel_tracker)
    required_env NOVEL_API_DOMAIN
    required_env NOVEL_AUTH_DOMAIN
    ;;
  drift)
    required_env DRIFT_API_DOMAIN
    ;;
esac

if [[ "$UPDATE_DNS" == "1" ]]; then
  case "$APP" in
    paisa)
      "${SCRIPT_DIR}/update-gandi-dns.sh" "$PAISA_WEB_DOMAIN" "$SERVER_IP"
      "${SCRIPT_DIR}/update-gandi-dns.sh" "$PAISA_API_DOMAIN" "$SERVER_IP"
      ;;
    novel_tracker)
      "${SCRIPT_DIR}/update-gandi-dns.sh" "$NOVEL_API_DOMAIN" "$SERVER_IP"
      "${SCRIPT_DIR}/update-gandi-dns.sh" "$NOVEL_AUTH_DOMAIN" "$SERVER_IP"
      ;;
    drift)
      "${SCRIPT_DIR}/update-gandi-dns.sh" "$DRIFT_API_DOMAIN" "$SERVER_IP"
      ;;
    *)
      "${SCRIPT_DIR}/update-gandi-dns.sh" "${!APP_DOMAIN_ENV}" "$SERVER_IP"
      ;;
  esac
fi

if [[ ! -d "$APP_REPO_DIR" || ! -x "$APP_DEPLOY_SCRIPT" ]]; then
  echo "Application checkout or deploy script is unavailable: ${APP_REPO_DIR}" >&2
  exit 1
fi

(
  cd "$APP_REPO_DIR"
  "$APP_DEPLOY_SCRIPT" "$DEPLOY_USER" "$SERVER_IP" "$REPO_URL" "$BRANCH"
)

echo "${APP_LABEL} release completed without redeploying the shared platform."
