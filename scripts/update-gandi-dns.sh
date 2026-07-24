#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 [--check] <fqdn> <ipv4> [ttl]

Environment:
  GANDI_PAT             Personal Access Token. If unset, Bitwarden is used.
  GANDI_ZONE            DNS zone, default: bghimire.com
  BW_GANDI_ITEM_NAME    Bitwarden item name, default: gandi-pat
  BW_GANDI_FIELD_NAME   Bitwarden custom field name, default: token

Examples:
  $0 family.bghimire.com 203.0.113.10
  $0 --check family.bghimire.com 203.0.113.10
USAGE
}

CHECK_ONLY=0
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi
if [[ "${1:-}" == "--check" ]]; then
  CHECK_ONLY=1
  shift
fi

if [[ $# -lt 2 || $# -gt 3 ]]; then
  usage
  exit 1
fi

FQDN="${1%.}"
IPV4="$2"
TTL="${3:-300}"
ZONE="${GANDI_ZONE:-bghimire.com}"
ZONE="${ZONE%.}"
API_BASE="https://api.gandi.net/v5/livedns/domains"

if [[ ! "$IPV4" =~ ^[0-9]{1,3}(\.[0-9]{1,3}){3}$ ]]; then
  echo "IPv4 address expected, got: $IPV4" >&2
  exit 1
fi

if [[ ! "$TTL" =~ ^[0-9]+$ || "$TTL" -lt 300 ]]; then
  echo "TTL must be a number >= 300." >&2
  exit 1
fi

if [[ "$FQDN" == "$ZONE" ]]; then
  RRNAME="@"
elif [[ "$FQDN" == *".${ZONE}" ]]; then
  RRNAME="${FQDN%.${ZONE}}"
else
  echo "FQDN '$FQDN' is not inside Gandi zone '$ZONE'." >&2
  exit 1
fi

ensure_bw_session() {
  local session="${BW_SESSION:-}"
  local session_file="${BW_SESSION_FILE:-/tmp/bw-session-${UID}}"

  if [[ -n "$session" ]] && bw sync --session "$session" >/dev/null 2>&1; then
    printf '%s\n' "$session"
    return
  fi

  if [[ -f "$session_file" ]]; then
    session="$(tr -d '\r\n' < "$session_file")"
    if [[ -n "$session" ]] && bw sync --session "$session" >/dev/null 2>&1; then
      printf '%s\n' "$session"
      return
    fi
  fi

  if ! bw login --check >/dev/null 2>&1; then
    echo "Bitwarden CLI is not logged in. Run 'bw login' first." >&2
    exit 1
  fi

  if ! session="$(bw unlock --raw)"; then
    echo "Bitwarden unlock failed." >&2
    exit 1
  fi
  if [[ -z "$session" || "$session" == \?* ]]; then
    echo "Bitwarden unlock did not return a usable session. Export BW_SESSION and rerun." >&2
    exit 1
  fi

  umask 177
  printf '%s' "$session" > "$session_file"
  printf '%s\n' "$session"
}

load_gandi_pat() {
  if [[ -n "${GANDI_PAT:-}" ]]; then
    printf '%s\n' "$GANDI_PAT"
    return
  fi

  if ! command -v bw >/dev/null 2>&1; then
    echo "GANDI_PAT is unset and Bitwarden CLI (bw) is not available." >&2
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "GANDI_PAT is unset and jq is required to read Bitwarden." >&2
    exit 1
  fi

  local item_name="${BW_GANDI_ITEM_NAME:-gandi-pat}"
  local field_name="${BW_GANDI_FIELD_NAME:-token}"
  local session item_json token
  session="$(ensure_bw_session)" || exit 1
  if ! item_json="$(bw get item "$item_name" --session "$session" 2>/dev/null)"; then
    echo "Could not read Bitwarden item '$item_name' for Gandi PAT." >&2
    exit 1
  fi
  token="$(
    printf '%s\n' "$item_json" \
      | jq -r --arg field "$field_name" '
          first(.fields[]? | select((.name|ascii_downcase)==($field|ascii_downcase)) | .value) // .notes // empty
        ' \
      | tr -d '\r\n[:space:]'
  )" || exit 1

  if [[ -z "$token" ]]; then
    echo "Could not find Gandi PAT in Bitwarden item '$item_name'." >&2
    exit 1
  fi

  printf '%s\n' "$token"
}

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required." >&2
  exit 1
fi

TOKEN="$(load_gandi_pat)" || exit 1
RECORD_URL="${API_BASE}/${ZONE}/records/${RRNAME}/A"

if [[ "$CHECK_ONLY" == "1" ]]; then
  curl -fsS -H "Authorization: Bearer ${TOKEN}" "$RECORD_URL" | jq .
  exit 0
fi

PAYLOAD="$(jq -nc --arg ip "$IPV4" --argjson ttl "$TTL" '{rrset_values: [$ip], rrset_ttl: $ttl}')"

curl -fsS -X PUT \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$RECORD_URL" >/dev/null

VERIFY_IP="$(
  curl -fsS -H "Authorization: Bearer ${TOKEN}" "$RECORD_URL" \
    | jq -r '.rrset_values[]?'
)" || exit 1

if [[ "$VERIFY_IP" != "$IPV4" ]]; then
  echo "Gandi DNS update verification failed for $FQDN." >&2
  exit 1
fi

echo "Updated ${FQDN} A record to ${IPV4} with TTL ${TTL}."
