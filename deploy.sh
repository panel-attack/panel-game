#!/bin/bash
set -e

SERVER="root@104.156.250.136"
INSTALL_DIR="/opt/panel-attack"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

cd "$(dirname "$0")"

# Snapshot pre-deploy state first. Restarting the service rotates the
# journal cursor and may also clear in-memory state we'd want for
# post-mortems — grab journal + on-disk logs + any crash_reports before
# we touch the running process. Outputs to gathered_logs/<ts>_<commit>/.
# Set PANEL_SKIP_GATHER=1 to skip (e.g. emergency hotfix where you're
# already on the box doing surgery).
if [[ "${PANEL_SKIP_GATHER:-0}" != "1" ]]; then
  echo "==> Gathering pre-deploy state..."
  PANEL_SERVER="$SERVER" INSTALL_DIR="$INSTALL_DIR" zsh ./gather_logs.sh
else
  echo "==> Skipping gather (PANEL_SKIP_GATHER=1)"
fi

echo "==> Pushing branch '$BRANCH' to origin..."
git push origin "$BRANCH"

echo "==> Deploying to $SERVER..."
ssh "$SERVER" "git config --global --add safe.directory $INSTALL_DIR; cd $INSTALL_DIR && git pull && systemctl restart panel-attack"

echo "==> Tailing logs (Ctrl+C to exit)..."
ssh "$SERVER" "journalctl -u panel-attack -f --no-pager"
