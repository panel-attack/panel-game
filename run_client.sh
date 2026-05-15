#!/bin/zsh
#
# Usage:
#   zsh run_client.sh                    # launch one client as "Player1"
#   zsh run_client.sh Alice              # launch one client as "Alice"
#   zsh run_client.sh Alice Bob          # launch two clients in parallel
#
# Simulated network lag (per direction — RTT is 2x). All three TCP sockets
# (gameplay, spectate, lobby) are affected. Lag only one side for realism by
# running two terminals and only setting the vars in one.
#   PA_NETWORK_LAG_MS=N                  # fixed N ms each direction
#   PA_NETWORK_LAG_MIN_MS=A MAX_MS=B     # uniform random in [A, B] ms
#
# Scenarios:
#   1) Sluggish wifi      MIN=120 MAX=180   ~240–360ms RTT, mild jitter
#   2) Mobile on a train  MIN=80  MAX=400   wide jitter, exposes ordering bugs
#   3) Transcontinental   MIN=200 MAX=280   ~400–560ms RTT, US↔Asia feel
#   4) Satellite / bad    MIN=400 MAX=700   for verifying timeouts/disconnects
#   5) Pathological       MIN=20  MAX=600   max variance, worst-case race finder
#
# Example:
#   PA_NETWORK_LAG_MIN_MS=80 PA_NETWORK_LAG_MAX_MS=400 zsh run_client.sh Alice
#   zsh run_client.sh Bob   # second terminal, no lag — the "good" connection

source ~/.zshrc 2>/dev/null
cd "$(dirname "$0")"
project_dir=$(pwd)

# Running this script implies local development, so surface the Localhost server
# (and other debug servers) in the main menu automatically. Override by exporting
# PA_SHOW_LOCAL=false before invoking the script.
: ${PA_SHOW_LOCAL:=true}

# Accept zero or more player names. With no args, launch a single default client.
# With one or more, launch one client per name in parallel — useful for local
# multiplayer testing.
if [[ $# -eq 0 ]]; then
  set -- "Player1"
fi

kill_project_clients() {
  # Kill any love process running this exact project directory.
  pkill -f "/Applications/love.app/Contents/MacOS/love $project_dir" 2>/dev/null || true
  pkill -f " love $project_dir" 2>/dev/null || true
}

cleanup() {
  trap - INT TERM HUP
  kill_project_clients
}
trap cleanup INT TERM HUP

# 1) Kill currently running instances for this project.
kill_project_clients
sleep 0.2

# 2) Start requested instances.
love_pids=()
for player_name in "$@"; do
  identity_arg="$player_name"
  LOVE_IDENTITY="Panel Attack $identity_arg" PLAYER_NAME="$player_name" PA_SHOW_LOCAL="$PA_SHOW_LOCAL" \
    PA_NETWORK_LAG_MS="${PA_NETWORK_LAG_MS:-}" \
    PA_NETWORK_LAG_MIN_MS="${PA_NETWORK_LAG_MIN_MS:-}" \
    PA_NETWORK_LAG_MAX_MS="${PA_NETWORK_LAG_MAX_MS:-}" \
    love "$project_dir" &
  love_pids+=("$!")
done

# Keep script alive while clients are alive.
wait "${love_pids[@]}"
