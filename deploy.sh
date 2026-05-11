#!/bin/bash
set -e

SERVER="root@104.156.250.136"
INSTALL_DIR="/opt/panel-attack"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

echo "==> Pushing branch '$BRANCH' to origin..."
git push origin "$BRANCH"

echo "==> Deploying to $SERVER..."
ssh "$SERVER" "cd $INSTALL_DIR && git pull && systemctl restart panel-attack"

echo "==> Tailing logs (Ctrl+C to exit)..."
ssh "$SERVER" "journalctl -u panel-attack -f --no-pager"
