#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  echo "Deprecated compatibility wrapper."
  echo "Use: ${SCRIPT_DIR}/deploy-vps-platform.sh <deploy-user> <server-ip> <acme-email>"
  exit 0
fi

if [[ $# -eq 3 ]]; then
  exec "${SCRIPT_DIR}/deploy-vps-platform.sh" "$1" "$2" "$3"
fi

# The legacy signature placed ACME email in argument 10. Domain and port
# arguments are intentionally ignored: applications now own their route files.
if [[ $# -ge 10 ]]; then
  echo "Warning: deploy-shared-caddy.sh is deprecated; bootstrapping only the shared platform." >&2
  exec "${SCRIPT_DIR}/deploy-vps-platform.sh" "$1" "$2" "${10}"
fi

echo "Usage: $0 <deploy-user> <server-ip> <acme-email>" >&2
exit 1
