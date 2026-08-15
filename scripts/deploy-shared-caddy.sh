#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 10 ]]; then
  echo "Usage: $0 <deploy-user> <server-ip> <family-domain> <fitness-domain> <badge-creator-domain> <paisa-web-domain> <paisa-api-domain> <novel-api-domain> <novel-auth-domain> <acme-email> [family-port] [fitness-port] [badge-creator-port] [paisa-web-port] [paisa-api-port] [novel-api-port] [novel-auth-port]"
  exit 1
fi

DEPLOY_USER="$1"
SERVER_IP="$2"
FAMILY_DOMAIN="$3"
FITNESS_DOMAIN="$4"
BADGE_CREATOR_DOMAIN="$5"
PAISA_WEB_DOMAIN="$6"
PAISA_API_DOMAIN="$7"
NOVEL_API_DOMAIN="$8"
NOVEL_AUTH_DOMAIN="$9"
ACME_EMAIL="$10"
FAMILY_PORT="${11:-8787}"
FITNESS_PORT="${12:-8788}"
BADGE_CREATOR_PORT="${13:-8789}"
PAISA_WEB_PORT="${14:-8790}"
PAISA_API_PORT="${15:-8791}"
NOVEL_API_PORT="${16:-8792}"
NOVEL_AUTH_PORT="${17:-8793}"

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
  reverse_proxy 127.0.0.1:${FAMILY_PORT}
}

${FITNESS_DOMAIN} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:${FITNESS_PORT}
}

${BADGE_CREATOR_DOMAIN} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:${BADGE_CREATOR_PORT}
}

${PAISA_WEB_DOMAIN} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:${PAISA_WEB_PORT}
}

${PAISA_API_DOMAIN} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:${PAISA_API_PORT}
}

${NOVEL_API_DOMAIN} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:${NOVEL_API_PORT}
}

${NOVEL_AUTH_DOMAIN} {
  encode zstd gzip
  reverse_proxy 127.0.0.1:${NOVEL_AUTH_PORT}
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
