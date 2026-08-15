#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <repo-dir> <deploy-user> <server-ip> <repo-url> [branch]

Compatibility wrapper for the provider-agnostic VPS deploy flow.
Prefer: scripts/deploy-vps-prod-from-tf.sh <app> [repo-url] [branch]
USAGE
}

if [[ $# -lt 4 || "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    exit 0
  fi
  exit 1
fi

REPO_DIR="$1"
DEPLOY_USER="$2"
SERVER_IP="$3"
REPO_URL="$4"
BRANCH="${5:-main}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${TF_DIR:-${SCRIPT_DIR}/../shared}"
# shellcheck source=lib/app-registry.sh
source "${SCRIPT_DIR}/lib/app-registry.sh"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "Repo dir not found: $REPO_DIR" >&2
  exit 1
fi

APP="$(app_key_from_repo_dir "$REPO_DIR")" || exit 1

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

FAMILY_DOMAIN="$(tf_output_required family_domain)" || exit 1
FITNESS_DOMAIN="$(tf_output_required fitness_domain)" || exit 1
BADGE_CREATOR_DOMAIN="$(tf_output_required badge_creator_domain)" || exit 1
PAISA_WEB_DOMAIN="$(tf_output_required paisa_web_domain)" || exit 1
PAISA_API_DOMAIN="$(tf_output_required paisa_api_domain)" || exit 1
NOVEL_API_DOMAIN="$(tf_output_required novel_api_domain)" || exit 1
NOVEL_AUTH_DOMAIN="$(tf_output_required novel_auth_domain)" || exit 1
ACME_EMAIL="$(tf_output_required acme_email)" || exit 1

FAMILY_DOMAIN="$FAMILY_DOMAIN" \
FITNESS_DOMAIN="$FITNESS_DOMAIN" \
BADGE_CREATOR_DOMAIN="$BADGE_CREATOR_DOMAIN" \
PAISA_WEB_DOMAIN="$PAISA_WEB_DOMAIN" \
PAISA_API_DOMAIN="$PAISA_API_DOMAIN" \
NOVEL_API_DOMAIN="$NOVEL_API_DOMAIN" \
NOVEL_AUTH_DOMAIN="$NOVEL_AUTH_DOMAIN" \
ACME_EMAIL="$ACME_EMAIL" \
  "${SCRIPT_DIR}/deploy-vps-prod.sh" "$APP" "$DEPLOY_USER" "$SERVER_IP" "$REPO_URL" "$BRANCH"
