#!/bin/zsh
source ~/.zshrc 2>/dev/null
cd "$(dirname "$0")"
project_dir=$(pwd)

identity_arg="${1:-1}"
player_name="${1:-Player1}"
pidfile="/tmp/panel-attack-client-${identity_arg}.pid"

# Kill only the previous love instance launched with THIS identity, so multiple
# clients (one per player name) can still run side-by-side for local testing.
if [[ -f "$pidfile" ]]; then
  prev_pid=$(cat "$pidfile" 2>/dev/null)
  if [[ -n "$prev_pid" ]] && kill -0 "$prev_pid" 2>/dev/null; then
    kill "$prev_pid" 2>/dev/null || true
    sleep 0.2
  fi
  rm -f "$pidfile"
fi

LOVE_IDENTITY="Panel Attack $identity_arg" PLAYER_NAME="$player_name" love "$project_dir" &
love_pid=$!
echo "$love_pid" > "$pidfile"
trap 'rm -f "$pidfile"' EXIT
wait "$love_pid"

