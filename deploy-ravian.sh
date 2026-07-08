#!/usr/bin/env bash
set -Eeuo pipefail

REPO_URL="https://github.com/Ravshik/Ravian.git"
APP_DIR="$HOME/ravian"
WEB_DIR="/var/www/html"

echo "== Ravian deploy =="

if ! command -v git >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y git
fi

sudo apt update
sudo apt install -y nginx

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

sudo mkdir -p "$WEB_DIR"
sudo find "$WEB_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
sudo cp -a "$APP_DIR"/. "$WEB_DIR"/
sudo chown -R www-data:www-data "$WEB_DIR"

sudo tee /etc/nginx/sites-available/ravian >/dev/null <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    server_name _;

    root /var/www/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }
}
NGINX

sudo rm -f /etc/nginx/sites-enabled/*
sudo ln -sf /etc/nginx/sites-available/ravian /etc/nginx/sites-enabled/ravian
sudo nginx -t
sudo systemctl enable nginx >/dev/null 2>&1 || true
sudo systemctl restart nginx

sudo ufw allow 80/tcp >/dev/null 2>&1 || true
sudo ufw reload >/dev/null 2>&1 || true

echo
curl -I http://127.0.0.1/index.html || true
echo
echo "Ravian is deployed:"
echo "http://151.244.243.164/index.html?v=ravian-final"
