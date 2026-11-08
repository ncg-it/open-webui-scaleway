#!/usr/bin/env bash
# Überträgt deploy/ auf den Server und startet den Stack neu.
# Nutzung: scripts/deploy.sh <host-oder-ip> [ssh-key]
set -euo pipefail

HOST="${1:?Host oder IP angeben}"
KEY="${2:-}"
REMOTE_DIR=/opt/open-webui
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SSH_OPTS=(-o StrictHostKeyChecking=accept-new)
[ -n "$KEY" ] && SSH_OPTS+=(-i "$KEY")

[ -f "$ROOT/deploy/.env" ] || { echo "deploy/.env fehlt (Vorlage: deploy/.env.example)"; exit 1; }

echo "Warte auf cloud-init ..."
ssh "${SSH_OPTS[@]}" "deploy@$HOST" "cloud-init status --wait >/dev/null || true"

scp "${SSH_OPTS[@]}" "$ROOT/deploy/docker-compose.yml" "$ROOT/deploy/Caddyfile" "$ROOT/deploy/.env" "deploy@$HOST:$REMOTE_DIR/"
ssh "${SSH_OPTS[@]}" "deploy@$HOST" "chmod 600 $REMOTE_DIR/.env && cd $REMOTE_DIR && docker compose pull && docker compose up -d --remove-orphans && docker image prune -f"

echo "Fertig. Status:"
ssh "${SSH_OPTS[@]}" "deploy@$HOST" "cd $REMOTE_DIR && docker compose ps"
