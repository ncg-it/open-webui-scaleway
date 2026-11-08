#!/usr/bin/env bash
# Copies deploy/ to the server and restarts the stack.
# Usage: scripts/deploy.sh <host-or-ip> [ssh-key]
set -euo pipefail

HOST="${1:?Specify host or IP}"
KEY="${2:-}"
REMOTE_DIR=/opt/open-webui
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
[ -n "$KEY" ] && SSH_OPTS+=(-i "$KEY")

[ -f "$ROOT/deploy/.env" ] || { echo "deploy/.env is missing (template: deploy/.env.example)"; exit 1; }

echo "Waiting for cloud-init ..."
ssh "${SSH_OPTS[@]}" "deploy@$HOST" "cloud-init status --wait >/dev/null || true"

scp "${SSH_OPTS[@]}" "$ROOT/deploy/docker-compose.yml" "$ROOT/deploy/Caddyfile" "$ROOT/deploy/.env" "deploy@$HOST:$REMOTE_DIR/"
scp -r "${SSH_OPTS[@]}" "$ROOT/deploy/searxng" "deploy@$HOST:$REMOTE_DIR/"
ssh "${SSH_OPTS[@]}" "deploy@$HOST" "chmod 600 $REMOTE_DIR/.env && cd $REMOTE_DIR && docker compose pull && docker compose up -d --remove-orphans && docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile && docker image prune -f"

echo "Done. Status:"
ssh "${SSH_OPTS[@]}" "deploy@$HOST" "cd $REMOTE_DIR && docker compose ps"
