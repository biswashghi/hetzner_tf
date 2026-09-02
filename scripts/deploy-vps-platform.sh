#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 <deploy-user> <server-ip> <acme-email>"
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

if [[ $# -ne 3 ]]; then
  usage >&2
  exit 1
fi

DEPLOY_USER="$1"
SERVER_IP="$2"
ACME_EMAIL="$3"
ALLOW_LEGACY_ROUTE_CUTOVER="${ALLOW_LEGACY_ROUTE_CUTOVER:-0}"
if [[ ! "$ACME_EMAIL" =~ ^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$ ]]; then
  echo "ACME email is invalid." >&2
  exit 1
fi
if [[ "$ALLOW_LEGACY_ROUTE_CUTOVER" != "0" && "$ALLOW_LEGACY_ROUTE_CUTOVER" != "1" ]]; then
  echo "ALLOW_LEGACY_ROUTE_CUTOVER must be 0 or 1." >&2
  exit 1
fi
ACME_EMAIL_BASE64="$(printf '%s' "$ACME_EMAIL" | base64 | tr -d '\n')"

ssh "${DEPLOY_USER}@${SERVER_IP}" \
  ACME_EMAIL_BASE64="$ACME_EMAIL_BASE64" \
  ALLOW_LEGACY_ROUTE_CUTOVER="$ALLOW_LEGACY_ROUTE_CUTOVER" \
  'bash -s' <<'REMOTE'
set -euo pipefail

PLATFORM_DIR=/opt/shared-caddy
EDGE_NETWORK=vps-edge

if sudo test -f "$PLATFORM_DIR/Caddyfile" && \
    sudo grep -Eq 'reverse_proxy[[:space:]]+127\.0\.0\.1:' "$PLATFORM_DIR/Caddyfile" && \
    [[ "$ALLOW_LEGACY_ROUTE_CUTOVER" != "1" ]]; then
  echo "Refusing to replace a legacy host-port Caddyfile automatically." >&2
  echo "Migrate or retire every remaining legacy route, then rerun the coordinated cutover with ALLOW_LEGACY_ROUTE_CUTOVER=1." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl git
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

if command -v ufw >/dev/null 2>&1 && sudo ufw status | grep -q '^Status: active'; then
  sudo ufw allow 443/udp >/dev/null
fi

if ! sudo docker network inspect "$EDGE_NETWORK" >/dev/null 2>&1; then
  sudo docker network create --label com.bghimire.vps.role=edge "$EDGE_NETWORK" >/dev/null
fi

for volume in shared-caddy_caddy_data shared-caddy_caddy_config; do
  if ! sudo docker volume inspect "$volume" >/dev/null 2>&1; then
    sudo docker volume create --label com.bghimire.vps.role=platform "$volume" >/dev/null
  fi
done

sudo install -d -m 0755 "$PLATFORM_DIR" "$PLATFORM_DIR/apps"
if [[ -f "$PLATFORM_DIR/Caddyfile" && ! -f "$PLATFORM_DIR/Caddyfile.pre-platform" ]]; then
  sudo cp "$PLATFORM_DIR/Caddyfile" "$PLATFORM_DIR/Caddyfile.pre-platform"
fi
if [[ -f "$PLATFORM_DIR/docker-compose.yml" && ! -f "$PLATFORM_DIR/docker-compose.yml.pre-platform" ]]; then
  sudo cp "$PLATFORM_DIR/docker-compose.yml" "$PLATFORM_DIR/docker-compose.yml.pre-platform"
fi

ACME_EMAIL="$(printf '%s' "$ACME_EMAIL_BASE64" | base64 -d)"
sudo tee "$PLATFORM_DIR/Caddyfile" >/dev/null <<CADDYFILE
{
  email ${ACME_EMAIL}
}

import /etc/caddy/apps/*.caddy
CADDYFILE

sudo tee "$PLATFORM_DIR/docker-compose.yml" >/dev/null <<'COMPOSEFILE'
name: vps-platform

services:
  caddy:
    image: caddy:2
    container_name: shared-caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp"
    networks:
      edge:
        aliases: [vps-edge-proxy]
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./apps:/etc/caddy/apps:ro
      - caddy_data:/data
      - caddy_config:/config

networks:
  edge:
    external: true
    name: vps-edge

volumes:
  caddy_data:
    external: true
    name: shared-caddy_caddy_data
  caddy_config:
    external: true
    name: shared-caddy_caddy_config
COMPOSEFILE

sudo tee /usr/local/bin/vps-platform-check >/dev/null <<'CHECKSCRIPT'
#!/usr/bin/env bash
set -euo pipefail

docker network inspect vps-edge >/dev/null 2>&1 || {
  echo "VPS platform is not initialized: missing vps-edge network." >&2
  exit 1
}
docker inspect -f '{{.State.Running}}' shared-caddy 2>/dev/null | grep -qx true || {
  echo "VPS platform is not initialized: shared-caddy is not running." >&2
  exit 1
}
test -x /usr/local/bin/vps-route || {
  echo "VPS platform is not initialized: vps-route helper is missing." >&2
  exit 1
}
CHECKSCRIPT
sudo chmod 0755 /usr/local/bin/vps-platform-check

sudo tee /usr/local/bin/vps-route >/dev/null <<'ROUTESCRIPT'
#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 || ! "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]; then
  echo "Usage: vps-route <app-name> < route.caddy" >&2
  exit 1
fi

APP="$1"
ROUTE_DIR=/opt/shared-caddy/apps
TARGET="${ROUTE_DIR}/${APP}.caddy"
TEMP="$(mktemp)"
PREVIOUS="$(mktemp)"
HAD_PREVIOUS=0
trap 'rm -f "$TEMP" "$PREVIOUS"' EXIT

cat >"$TEMP"
if [[ ! -s "$TEMP" ]]; then
  echo "Refusing to install an empty route for ${APP}." >&2
  exit 1
fi

exec 9>/run/lock/vps-route.lock
flock 9
install -d -m 0755 "$ROUTE_DIR"
if [[ -f "$TARGET" ]]; then
  cp "$TARGET" "$PREVIOUS"
  HAD_PREVIOUS=1
fi
install -m 0644 "$TEMP" "$TARGET"

if ! docker exec shared-caddy caddy validate --config /etc/caddy/Caddyfile >/dev/null; then
  if [[ "$HAD_PREVIOUS" -eq 1 ]]; then
    install -m 0644 "$PREVIOUS" "$TARGET"
  else
    rm -f "$TARGET"
  fi
  echo "Rejected invalid Caddy route for ${APP}; the previous route is still active." >&2
  exit 1
fi

if ! docker exec shared-caddy caddy reload --config /etc/caddy/Caddyfile >/dev/null; then
  if [[ "$HAD_PREVIOUS" -eq 1 ]]; then
    install -m 0644 "$PREVIOUS" "$TARGET"
  else
    rm -f "$TARGET"
  fi
  docker exec shared-caddy caddy reload --config /etc/caddy/Caddyfile >/dev/null || true
  echo "Caddy could not reload ${APP}; the previous route was restored." >&2
  exit 1
fi
echo "Installed route ${TARGET}"
ROUTESCRIPT
sudo chmod 0755 /usr/local/bin/vps-route

cd "$PLATFORM_DIR"
if sudo docker container inspect shared-caddy >/dev/null 2>&1; then
  CURRENT_PROJECT="$(sudo docker container inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' shared-caddy 2>/dev/null || true)"
  if [[ "$CURRENT_PROJECT" != "vps-platform" ]]; then
    echo "Replacing legacy shared-caddy container; certificate volumes are preserved."
    sudo docker rm -f shared-caddy >/dev/null
  fi
fi
sudo docker compose up -d
sudo /usr/local/bin/vps-platform-check
sudo docker compose ps
REMOTE
