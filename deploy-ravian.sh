#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/Ravshik/Ravian.git"
APP_DIR="/opt/ravian"
PROXY_DIR="/opt/loft-hall-proxy"
SITE_HOST="ravian.77.110.122.36.sslip.io"

echo "== Ravian Docker deploy =="

if ! command -v git >/dev/null 2>&1; then
  apt update
  apt install -y git
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: Docker is required on this host."
  exit 1
fi

if [ -d "$APP_DIR/.git" ]; then
  cd "$APP_DIR"
  git fetch origin main
  git reset --hard origin/main
else
  rm -rf "$APP_DIR"
  git clone "$REPO_URL" "$APP_DIR"
  cd "$APP_DIR"
fi

if ! grep -q "<title>Ravian</title>" "$APP_DIR/index.html"; then
  echo "ERROR: index.html is not Ravian."
  exit 1
fi

docker network inspect loft-hall-internship_default >/dev/null
docker compose up -d --build

if ! grep -q "^${SITE_HOST} " "$PROXY_DIR/Caddyfile"; then
  cp "$PROXY_DIR/Caddyfile" "$PROXY_DIR/Caddyfile.backup-$(date +%Y%m%d-%H%M%S)"
  cat >> "$PROXY_DIR/Caddyfile" <<CADDY

${SITE_HOST} {
    encode zstd gzip
    reverse_proxy ravian:80
}
CADDY
fi

docker exec loft-hall-caddy caddy validate --config /etc/caddy/Caddyfile
docker exec loft-hall-caddy caddy reload --config /etc/caddy/Caddyfile

echo
docker ps --filter name=ravian --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
echo
echo "Ravian is deployed:"
echo "https://${SITE_HOST}/"
