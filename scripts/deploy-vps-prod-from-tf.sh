#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 [--update-dns] <app> [repo-url] [branch]

Examples:
  $0 family_hub main
  $0 fitness https://github.com/biswashghi/fitness.git main
  $0 --update-dns badge_creator main
  $0 --update-dns paisa main
USAGE
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
  usage
  exit 1
fi

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required." >&2
  exit 1
fi

if [[ ! -d "$TF_DIR" ]]; then
  echo "Terraform dir not found: $TF_DIR" >&2
  exit 1
fi

APP="$1"
shift
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

tf_output_required() {
  local name="$1"
  local value
  if ! value="$(cd "$TF_DIR" && terraform output -no-color -raw "$name" 2>/dev/null)"; then
    echo "Missing Terraform output: $name" >&2
    exit 1
  fi
  if [[ -z "$value" || "$value" == *$'\n'* || "$value" == *"Warning:"* || "$value" == "example.com" || "$value" == "admin@example.com" ]]; then
    echo "Terraform output '$name' is empty/default. Configure ${TF_DIR}/terraform.tfvars and apply." >&2
    exit 1
  fi
  printf '%s\n' "$value"
}

validate_ipv4() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
    echo "Terraform output '$name' must be an IPv4 address." >&2
    exit 1
  fi
}

validate_dns_name() {
  local name="$1"
  local value="$2"
  if [[ ! "$value" =~ ^[A-Za-z0-9._-]+$ || "$value" != *.* ]]; then
    echo "Terraform output '$name' must be a DNS name." >&2
    exit 1
  fi
}

SERVER_IP="$(tf_output_required server_ipv4)" || exit 1
DEPLOY_USER="$(tf_output_required deploy_user)" || exit 1
FAMILY_DOMAIN="$(tf_output_required family_domain)" || exit 1
FITNESS_DOMAIN="$(tf_output_required fitness_domain)" || exit 1
BADGE_CREATOR_DOMAIN="$(tf_output_required badge_creator_domain)" || exit 1
PAISA_WEB_DOMAIN="$(tf_output_required paisa_web_domain)" || exit 1
PAISA_API_DOMAIN="$(tf_output_required paisa_api_domain)" || exit 1
NOVEL_API_DOMAIN="$(tf_output_required novel_api_domain)" || exit 1
NOVEL_AUTH_DOMAIN="$(tf_output_required novel_auth_domain)" || exit 1
ACME_EMAIL="$(tf_output_required acme_email)" || exit 1

validate_ipv4 server_ipv4 "$SERVER_IP"
validate_dns_name family_domain "$FAMILY_DOMAIN"
validate_dns_name fitness_domain "$FITNESS_DOMAIN"
validate_dns_name badge_creator_domain "$BADGE_CREATOR_DOMAIN"
validate_dns_name paisa_web_domain "$PAISA_WEB_DOMAIN"
validate_dns_name paisa_api_domain "$PAISA_API_DOMAIN"
validate_dns_name novel_api_domain "$NOVEL_API_DOMAIN"
validate_dns_name novel_auth_domain "$NOVEL_AUTH_DOMAIN"

if [[ "$UPDATE_DNS" == "1" ]]; then
  FAMILY_DOMAIN="$FAMILY_DOMAIN" \
  FITNESS_DOMAIN="$FITNESS_DOMAIN" \
  BADGE_CREATOR_DOMAIN="$BADGE_CREATOR_DOMAIN" \
  PAISA_WEB_DOMAIN="$PAISA_WEB_DOMAIN" \
  PAISA_API_DOMAIN="$PAISA_API_DOMAIN" \
  NOVEL_API_DOMAIN="$NOVEL_API_DOMAIN" \
  NOVEL_AUTH_DOMAIN="$NOVEL_AUTH_DOMAIN" \
  ACME_EMAIL="$ACME_EMAIL" \
    "${SCRIPT_DIR}/deploy-vps-prod.sh" --update-dns "$APP" "$DEPLOY_USER" "$SERVER_IP" "$REPO_URL" "$BRANCH"
else
  FAMILY_DOMAIN="$FAMILY_DOMAIN" \
  FITNESS_DOMAIN="$FITNESS_DOMAIN" \
  BADGE_CREATOR_DOMAIN="$BADGE_CREATOR_DOMAIN" \
  PAISA_WEB_DOMAIN="$PAISA_WEB_DOMAIN" \
  PAISA_API_DOMAIN="$PAISA_API_DOMAIN" \
  NOVEL_API_DOMAIN="$NOVEL_API_DOMAIN" \
  NOVEL_AUTH_DOMAIN="$NOVEL_AUTH_DOMAIN" \
  ACME_EMAIL="$ACME_EMAIL" \
    "${SCRIPT_DIR}/deploy-vps-prod.sh" "$APP" "$DEPLOY_USER" "$SERVER_IP" "$REPO_URL" "$BRANCH"
fi
