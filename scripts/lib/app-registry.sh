#!/usr/bin/env bash

APP_REGISTRY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_ROOT="${REPOS_ROOT:-$(cd "${APP_REGISTRY_DIR}/../../.." && pwd)}"

supported_apps() {
  printf '%s\n' "family_hub fitness badge_creator paisa novel_tracker drift"
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
    family_hub|fitness|badge_creator|paisa)
      printf '%s\n' "$repo_name"
      ;;
    novel_extension)
      printf '%s\n' "novel_tracker"
      ;;
    ios_app|drift)
      printf '%s\n' "drift"
      ;;
    *)
      echo "Unsupported repo dir: $repo_name (expected family_hub, fitness, badge_creator, paisa, novel_extension, or ios_app)" >&2
      return 1
      ;;
  esac
}

resolve_app() {
  local app_key="$1"
  case "$app_key" in
    family_hub)
      APP_LABEL="Family Hub"
      APP_REPO_DIR="${REPOS_ROOT}/family_hub"
      APP_DEFAULT_REPO_URL="https://github.com/biswashghi/family_hub.git"
      APP_DOMAIN_ENV="FAMILY_DOMAIN"
      ;;
    fitness)
      APP_LABEL="Fitness"
      APP_REPO_DIR="${REPOS_ROOT}/fitness"
      APP_DEFAULT_REPO_URL="https://github.com/biswashghi/fitness.git"
      APP_DOMAIN_ENV="FITNESS_DOMAIN"
      ;;
    badge_creator)
      APP_LABEL="Badge Creator"
      APP_REPO_DIR="${REPOS_ROOT}/badge_creator"
      APP_DEFAULT_REPO_URL="https://github.com/biswashghi/badge_creator.git"
      APP_DOMAIN_ENV="BADGE_CREATOR_DOMAIN"
      ;;
    paisa)
      APP_LABEL="Paisa"
      APP_REPO_DIR="${REPOS_ROOT}/paisa"
      APP_DEFAULT_REPO_URL="https://github.com/biswashghi/paisa.git"
      APP_DOMAIN_ENV="PAISA_WEB_DOMAIN"
      ;;
    novel_tracker)
      APP_LABEL="Novel Tracker"
      APP_REPO_DIR="${REPOS_ROOT}/novel_extension"
      APP_DEFAULT_REPO_URL="https://github.com/biswashghi/novel_tracker.git"
      ;;
    drift)
      APP_LABEL="Drift"
      APP_REPO_DIR="${REPOS_ROOT}/ios_app"
      APP_DEFAULT_REPO_URL="https://github.com/biswashghi/drift.git"
      APP_DOMAIN_ENV="DRIFT_API_DOMAIN"
      ;;
    *)
      echo "Unsupported app: $app_key" >&2
      echo "Supported apps: $(supported_apps)" >&2
      return 1
      ;;
  esac

  APP_DEPLOY_SCRIPT="${APP_REPO_DIR}/scripts/deploy-vps.sh"
}
