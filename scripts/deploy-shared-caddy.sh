#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 6 ]]; then
  echo "Usage: $0 <deploy-user> <server-ip> <family-domain> <fitness-domain> <badge-creator-domain> <acme-email>"
  exit 1
fi

DEPLOY_USER="$1"
SERVER_IP="$2"
FAMILY_DOMAIN="$3"
FITNESS_DOMAIN="$4"
BADGE_CREATOR_DOMAIN="$5"
ACME_EMAIL="$6"

ssh "${DEPLOY_USER}@${SERVER_IP}" <<EOF
set -euo pipefail

if ! command -v docker >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y ca-certificates curl git
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null
  sudo chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \$(. /etc/os-release && echo \$VERSION_CODENAME) stable" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  sudo usermod -aG docker ${DEPLOY_USER}
fi

sudo mkdir -p /opt/shared-caddy
sudo tee /opt/shared-caddy/Caddyfile >/dev/null <<CADDYFILE
{
  email ${ACME_EMAIL}
}

${FAMILY_DOMAIN} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:8787
}

${FITNESS_DOMAIN} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:8788
}

${BADGE_CREATOR_DOMAIN} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:8789
}
CADDYFILE

sudo tee /opt/shared-caddy/docker-compose.yml >/dev/null <<'COMPOSEFILE'
services:
  caddy:
    image: caddy:2
    container_name: shared-caddy
    restart: unless-stopped
    network_mode: host
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config

volumes:
  caddy_data:
  caddy_config:
COMPOSEFILE

cd /opt/shared-caddy
sudo docker compose up -d --force-recreate
sudo docker compose ps
EOF
