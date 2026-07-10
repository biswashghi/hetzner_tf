#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 4 ]]; then
  echo "Usage: $0 <repo-dir> <deploy-user> <server-ip> <repo-url> [branch]"
  exit 1
fi

REPO_DIR="$1"
DEPLOY_USER="$2"
SERVER_IP="$3"
REPO_URL="$4"
BRANCH="${5:-main}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${TF_DIR:-${SCRIPT_DIR}/../shared}"
BW_SESSION_FILE="${BW_SESSION_FILE:-/tmp/bw-session-${UID}}"

if [[ ! -d "$REPO_DIR" ]]; then
  echo "Repo dir not found: $REPO_DIR"
  exit 1
fi

if [[ ! -d "$TF_DIR" ]]; then
  echo "Terraform dir not found: $TF_DIR"
  exit 1
fi

REQUIRED_FILES=(
  "${REPO_DIR}/scripts/deploy-hetzner.sh"
  "${REPO_DIR}/docker-compose.prod.yml"
)
for file in "${REQUIRED_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Required deployment file missing: $file"
    exit 1
  fi
done

REPO_NAME="$(basename "$REPO_DIR")"
case "$REPO_NAME" in
  family_hub)
    APP_DOMAIN="$(cd "$TF_DIR" && terraform output -raw family_domain 2>/dev/null || true)"
    ;;
  fitness)
    APP_DOMAIN="$(cd "$TF_DIR" && terraform output -raw fitness_domain 2>/dev/null || true)"
    ;;
  badge_creator)
    APP_DOMAIN="$(cd "$TF_DIR" && terraform output -raw badge_creator_domain 2>/dev/null || true)"
    ;;
  *)
    echo "Unsupported repo dir: $REPO_NAME (expected family_hub, fitness, or badge_creator)"
    exit 1
    ;;
esac

ensure_bw_session() {
  local session="${BW_SESSION:-}"
  if [[ -n "$session" ]]; then
    if bw sync --session "$session" >/dev/null 2>&1; then
      printf '%s' "$session"
      return
    fi
  fi

  if [[ -f "$BW_SESSION_FILE" ]]; then
    session="$(tr -d '\r\n' < "$BW_SESSION_FILE")"
    if [[ -n "$session" ]] && bw sync --session "$session" >/dev/null 2>&1; then
      printf '%s' "$session"
      return
    fi
  fi

  if ! bw login --check >/dev/null 2>&1; then
    echo "Bitwarden CLI is not logged in."
    echo "Run 'bw login' (or 'bw login --apikey') first, then rerun this command."
    exit 1
  fi

  if ! session="$(bw unlock --raw)"; then
    echo "Bitwarden unlock failed."
    echo "If you recently signed out, run 'bw login' first and try again."
    exit 1
  fi
  umask 177
  printf '%s' "$session" > "$BW_SESSION_FILE"
  printf '%s' "$session"
}

ACME_EMAIL="$(cd "$TF_DIR" && terraform output -raw acme_email 2>/dev/null || true)"
FAMILY_DOMAIN="$(cd "$TF_DIR" && terraform output -raw family_domain 2>/dev/null || true)"
FITNESS_DOMAIN="$(cd "$TF_DIR" && terraform output -raw fitness_domain 2>/dev/null || true)"
BADGE_CREATOR_DOMAIN="$(cd "$TF_DIR" && terraform output -raw badge_creator_domain 2>/dev/null || true)"

if [[ -z "$APP_DOMAIN" || "$APP_DOMAIN" == "example.com" ]]; then
  echo "Service domain output is empty/default. Configure domains in ${TF_DIR}/terraform.tfvars and apply."
  exit 1
fi
if [[ -z "$FAMILY_DOMAIN" || "$FAMILY_DOMAIN" == "example.com" ]]; then
  echo "family_domain output is empty/default. Configure ${TF_DIR}/terraform.tfvars and apply."
  exit 1
fi
if [[ -z "$FITNESS_DOMAIN" || "$FITNESS_DOMAIN" == "example.com" ]]; then
  echo "fitness_domain output is empty/default. Configure ${TF_DIR}/terraform.tfvars and apply."
  exit 1
fi
if [[ -z "$BADGE_CREATOR_DOMAIN" || "$BADGE_CREATOR_DOMAIN" == "example.com" ]]; then
  echo "badge_creator_domain output is empty/default. Configure ${TF_DIR}/terraform.tfvars and apply."
  exit 1
fi
if [[ -z "$ACME_EMAIL" || "$ACME_EMAIL" == "admin@example.com" ]]; then
  echo "acme_email output is empty/default. Configure ${TF_DIR}/terraform.tfvars and apply."
  exit 1
fi

FAMILY_HUB_USERNAME_VALUE="${FAMILY_HUB_USERNAME:-}"
FAMILY_HUB_PASSWORD_VALUE="${FAMILY_HUB_PASSWORD:-}"
if [[ "$REPO_NAME" == "family_hub" ]]; then
  if [[ -z "$FAMILY_HUB_USERNAME_VALUE" || -z "$FAMILY_HUB_PASSWORD_VALUE" ]]; then
    if ! command -v bw >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
      echo "Family Hub deploy requires bw and jq to fetch credentials from Bitwarden."
      echo "Alternatively set FAMILY_HUB_USERNAME and FAMILY_HUB_PASSWORD in your shell."
      exit 1
    fi

    BW_ITEM_NAME="${BW_FAMILY_HUB_ITEM_NAME:-family-hub-prod-credentials}"
    BW_USERNAME_FIELD="${BW_FAMILY_HUB_USERNAME_FIELD:-username}"
    BW_PASSWORD_FIELD="${BW_FAMILY_HUB_PASSWORD_FIELD:-password}"
    BW_SESSION_VALUE="$(ensure_bw_session)"
    BW_ITEM_JSON="$(bw get item "$BW_ITEM_NAME" --session "$BW_SESSION_VALUE")"

    if [[ -z "$FAMILY_HUB_USERNAME_VALUE" ]]; then
      FAMILY_HUB_USERNAME_VALUE="$(
        printf '%s' "$BW_ITEM_JSON" \
          | jq -r --arg field "$BW_USERNAME_FIELD" '[
              (.fields[]? | select((.name|ascii_downcase)==($field|ascii_downcase)) | .value),
              .login.username
            ] | map(select(. != null and . != "")) | .[0] // ""' \
          | tr -d '\r\n'
      )"
    fi
    if [[ -z "$FAMILY_HUB_PASSWORD_VALUE" ]]; then
      FAMILY_HUB_PASSWORD_VALUE="$(
        printf '%s' "$BW_ITEM_JSON" \
          | jq -r --arg field "$BW_PASSWORD_FIELD" '[
              (.fields[]? | select((.name|ascii_downcase)==($field|ascii_downcase)) | .value),
              .login.password
            ] | map(select(. != null and . != "")) | .[0] // ""' \
          | tr -d '\r\n'
      )"
    fi
  fi

  if [[ -z "$FAMILY_HUB_USERNAME_VALUE" || -z "$FAMILY_HUB_PASSWORD_VALUE" ]]; then
    echo "Could not resolve Family Hub credentials."
    echo "Set FAMILY_HUB_USERNAME/FAMILY_HUB_PASSWORD or configure Bitwarden item/fields via:"
    echo "  BW_FAMILY_HUB_ITEM_NAME (default: family-hub-prod-credentials)"
    echo "  BW_FAMILY_HUB_USERNAME_FIELD (default: username)"
    echo "  BW_FAMILY_HUB_PASSWORD_FIELD (default: password)"
    exit 1
  fi
fi

"${SCRIPT_DIR}/deploy-shared-caddy.sh" \
  "$DEPLOY_USER" "$SERVER_IP" "$FAMILY_DOMAIN" "$FITNESS_DOMAIN" "$BADGE_CREATOR_DOMAIN" "$ACME_EMAIL"

(
  cd "$REPO_DIR"
  if [[ "$REPO_NAME" == "family_hub" ]]; then
    APP_DOMAIN="$APP_DOMAIN" ACME_EMAIL="$ACME_EMAIL" \
      FAMILY_HUB_USERNAME="$FAMILY_HUB_USERNAME_VALUE" \
      FAMILY_HUB_PASSWORD="$FAMILY_HUB_PASSWORD_VALUE" \
      ./scripts/deploy-hetzner.sh "$DEPLOY_USER" "$SERVER_IP" "$REPO_URL" "$BRANCH"
  else
    APP_DOMAIN="$APP_DOMAIN" ACME_EMAIL="$ACME_EMAIL" \
      ./scripts/deploy-hetzner.sh "$DEPLOY_USER" "$SERVER_IP" "$REPO_URL" "$BRANCH"
  fi
)
