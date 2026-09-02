#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${TF_DIR:-${SCRIPT_DIR}/../shared}"

tf_output_required() {
  local name="$1" value
  value="$(cd "$TF_DIR" && terraform output -no-color -raw "$name")"
  if [[ -z "$value" || "$value" == "example.com" || "$value" == "admin@example.com" ]]; then
    echo "Terraform output '${name}' is missing or still uses an example value." >&2
    exit 1
  fi
  printf '%s\n' "$value"
}

"${SCRIPT_DIR}/deploy-vps-platform.sh" \
  "$(tf_output_required deploy_user)" \
  "$(tf_output_required server_ipv4)" \
  "$(tf_output_required acme_email)"
