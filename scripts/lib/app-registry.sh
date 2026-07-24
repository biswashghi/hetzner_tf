#!/usr/bin/env bash

APP_REGISTRY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_ROOT="${REPOS_ROOT:-$(cd "${APP_REGISTRY_DIR}/../../.." && pwd)}"

supported_apps() {
  printf '%s\n' "family_hub fitness badge_creator"
}

is_repo_url() {
  case "${1:-}" in
    http://*|https://*|git@*:*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

app_key_from_repo_dir() {
  local repo_dir="$1"
  local repo_name
  repo_name="$(basename "$repo_dir")"

  case "$repo_name" in
    family_hub|fitness|badge_creator)
      printf '%s\n' "$repo_name"
      ;;
    *)
      echo "Unsupported repo dir: $repo_name (expected family_hub, fitness, or badge_creator)" >&2
      return 1
      ;;
  esac
}

resolve_app() {
  local app_key="$1"

  APP_KEY="$app_key"
  case "$app_key" in
    family_hub)
      APP_LABEL="Family Hub"
      APP_REPO_DIR="${REPOS_ROOT}/family_hub"
      APP_DEFAULT_REPO_URL="https://github.com/biswashghi/family_hub.git"
      APP_DOMAIN_ENV="FAMILY_DOMAIN"
      APP_DOMAIN_OUTPUT="family_domain"
      APP_HOST_PORT="8787"
      APP_HEALTH_PATH="/api/health"
      ;;
    fitness)
      APP_LABEL="Fitness"
      APP_REPO_DIR="${REPOS_ROOT}/fitness"
      APP_DEFAULT_REPO_URL="https://github.com/biswashghi/fitness.git"
      APP_DOMAIN_ENV="FITNESS_DOMAIN"
      APP_DOMAIN_OUTPUT="fitness_domain"
      APP_HOST_PORT="8788"
      APP_HEALTH_PATH="/api/health"
      ;;
    badge_creator)
      APP_LABEL="Badge Creator"
      APP_REPO_DIR="${REPOS_ROOT}/badge_creator"
      APP_DEFAULT_REPO_URL="https://github.com/biswashghi/badge_creator.git"
      APP_DOMAIN_ENV="BADGE_CREATOR_DOMAIN"
      APP_DOMAIN_OUTPUT="badge_creator_domain"
      APP_HOST_PORT="8789"
      APP_HEALTH_PATH="/"
      ;;
    *)
      echo "Unsupported app: $app_key" >&2
      echo "Supported apps: $(supported_apps)" >&2
      return 1
      ;;
  esac

  APP_DEPLOY_SCRIPT="${APP_REPO_DIR}/scripts/deploy-vps.sh"
}

app_port() {
  local app_key="$1"
  case "$app_key" in
    family_hub)
      printf '%s\n' "8787"
      ;;
    fitness)
      printf '%s\n' "8788"
      ;;
    badge_creator)
      printf '%s\n' "8789"
      ;;
    *)
      echo "Unsupported app: $app_key" >&2
      return 1
      ;;
  esac
}
