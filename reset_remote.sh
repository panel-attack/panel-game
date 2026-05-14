#!/bin/bash
# Reset the deployed server. Two modes:
#   zsh reset_remote.sh          — redeploy current branch + restart, preserves accounts
#   zsh reset_remote.sh --nuke   — full wipe (players.txt, leaderboard, sqlite),
#                                  auto-clears your local user_id cache too

set -e
SERVER="root@104.156.250.136"
INSTALL_DIR="/opt/panel-attack"
BRANCH=$(git rev-parse --abbrev-ref HEAD)

NUKE_CMD=""
if [[ "$1" == "--nuke" ]]; then
  echo "==> NUKE mode: wipes all server-side player data."
  NUKE_CMD="rm -f players.txt leaderboard.csv PADatabase.sqlite3*"
fi

echo "==> Pushing branch '$BRANCH' to origin..."
git push origin "$BRANCH"

echo "==> Resetting remote and restarting..."
ssh "$SERVER" "
  systemctl stop panel-attack
  cd $INSTALL_DIR
  git fetch origin
  git reset --hard origin/$BRANCH
  $NUKE_CMD
  systemctl start panel-attack
  sleep 2
  systemctl status panel-attack --no-pager | head -15
"

if [[ -n "$NUKE_CMD" ]]; then
  echo ""
  echo "==> Clearing local user_id caches for $SERVER..."
  find ~/Library/Application\ Support/LOVE -path '*/servers/104.156.250.136/user_id.txt' -delete 2>/dev/null || true
  echo "    Done. Other testers should run this on their machines too:"
  echo "    find ~/Library/Application\\ Support/LOVE -path '*/servers/104.156.250.136/user_id.txt' -delete"
fi

echo ""
echo "==> Tailing logs (Ctrl+C to exit)..."
ssh "$SERVER" "journalctl -u panel-attack -f --no-pager"
