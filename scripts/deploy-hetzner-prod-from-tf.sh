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

case "$APP" in
  family_hub) FAMILY_DOMAIN="$(tf_output_required family_domain)"; export FAMILY_DOMAIN ;;
  fitness) FITNESS_DOMAIN="$(tf_output_required fitness_domain)"; export FITNESS_DOMAIN ;;
  badge_creator) BADGE_CREATOR_DOMAIN="$(tf_output_required badge_creator_domain)"; export BADGE_CREATOR_DOMAIN ;;
  paisa)
    PAISA_WEB_DOMAIN="$(tf_output_required paisa_web_domain)"; export PAISA_WEB_DOMAIN
    PAISA_API_DOMAIN="$(tf_output_required paisa_api_domain)"; export PAISA_API_DOMAIN
    ;;
  novel_tracker)
    NOVEL_API_DOMAIN="$(tf_output_required novel_api_domain)"; export NOVEL_API_DOMAIN
    NOVEL_AUTH_DOMAIN="$(tf_output_required novel_auth_domain)"; export NOVEL_AUTH_DOMAIN
    ;;
  drift) DRIFT_API_DOMAIN="$(tf_output_required drift_api_domain)"; export DRIFT_API_DOMAIN ;;
esac

"${SCRIPT_DIR}/deploy-vps-prod.sh" "$APP" "$DEPLOY_USER" "$SERVER_IP" "$REPO_URL" "$BRANCH"
