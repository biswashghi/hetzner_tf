#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 [--update-dns] <app> [repo-url] [branch]"
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${TF_DIR:-${SCRIPT_DIR}/../shared}"
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
if [[ $# -lt 1 || $# -gt 3 ]]; then
  usage >&2
  exit 1
fi
if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required." >&2
  exit 1
fi

APP="$1"
shift
resolve_app "$APP"

REPO_URL="$APP_DEFAULT_REPO_URL"
BRANCH=main
if [[ $# -eq 1 ]]; then
  if is_repo_url "$1"; then REPO_URL="$1"; else BRANCH="$1"; fi
elif [[ $# -eq 2 ]]; then
  REPO_URL="$1"
  BRANCH="$2"
fi

tf_output_required() {
  local name="$1" value
  if ! value="$(cd "$TF_DIR" && terraform output -no-color -raw "$name" 2>/dev/null)"; then
    echo "Missing Terraform output: ${name}" >&2
    exit 1
  fi
  if [[ -z "$value" || "$value" == "example.com" || "$value" == "admin@example.com" ]]; then
    echo "Terraform output '${name}' is missing or still uses an example value." >&2
    exit 1
  fi
  printf '%s\n' "$value"
}

SERVER_IP="$(tf_output_required server_ipv4)"
DEPLOY_USER="$(tf_output_required deploy_user)"

# Read only the selected application's routing data. One app can deploy even if
# another app has not been configured in this Terraform state.
case "$APP" in
  family_hub)
    FAMILY_DOMAIN="$(tf_output_required family_domain)"; export FAMILY_DOMAIN
    ;;
  fitness)
    FITNESS_DOMAIN="$(tf_output_required fitness_domain)"; export FITNESS_DOMAIN
    ;;
  badge_creator)
    BADGE_CREATOR_DOMAIN="$(tf_output_required badge_creator_domain)"; export BADGE_CREATOR_DOMAIN
    ;;
  paisa)
    PAISA_WEB_DOMAIN="$(tf_output_required paisa_web_domain)"; export PAISA_WEB_DOMAIN
    PAISA_API_DOMAIN="$(tf_output_required paisa_api_domain)"; export PAISA_API_DOMAIN
    ;;
  novel_tracker)
    NOVEL_API_DOMAIN="$(tf_output_required novel_api_domain)"; export NOVEL_API_DOMAIN
    NOVEL_AUTH_DOMAIN="$(tf_output_required novel_auth_domain)"; export NOVEL_AUTH_DOMAIN
    ;;
  drift)
    DRIFT_API_DOMAIN="$(tf_output_required drift_api_domain)"; export DRIFT_API_DOMAIN
    ;;
esac

ARGS=("${SCRIPT_DIR}/deploy-vps-prod.sh")
[[ "$UPDATE_DNS" == "0" ]] || ARGS+=(--update-dns)
ARGS+=("$APP" "$DEPLOY_USER" "$SERVER_IP" "$REPO_URL" "$BRANCH")
"${ARGS[@]}"
