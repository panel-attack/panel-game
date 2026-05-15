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
#
#   PA_NETWORK_LAG_MIN_MS=120 PA_NETWORK_LAG_MAX_MS=180 zsh run_client.sh Lala
#   PA_NETWORK_LAG_MIN_MS=80 PA_NETWORK_LAG_MAX_MS=400 zsh run_client.sh Bevy
#   PA_NETWORK_LAG_MIN_MS=200 PA_NETWORK_LAG_MAX_MS=280 zsh run_client.sh Koozie
#   PA_NETWORK_LAG_MIN_MS=400 PA_NETWORK_LAG_MAX_MS=700 zsh run_client.sh Hayley
#   PA_NETWORK_LAG_MIN_MS=20 PA_NETWORK_LAG_MAX_MS=600 zsh run_client.sh Amber


source ~/.zshrc 2>/dev/null
cd "$(dirname "$0")"
project_dir=$(pwd)
pid_dir="$project_dir/logs/client_pids"

# Running this script implies local development, so surface the Localhost server
# (and other debug servers) in the main menu automatically. Override by exporting
# PA_SHOW_LOCAL=false before invoking the script.
: ${PA_SHOW_LOCAL:=true}

# By default, kill existing project clients before launching new ones. Set
# PA_KILL_EXISTING=false to allow concurrent invocations of this script.
: ${PA_KILL_EXISTING:=true}

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

pid_file_for_player() {
  local player_name="$1"
  local safe_name
  safe_name=$(printf "%s" "$player_name" | tr -c '[:alnum:]_.-' '_')
  printf "%s/%s.pid" "$pid_dir" "$safe_name"
}

kill_player_pid_if_running() {
  local player_name="$1"
  local pid_file
  pid_file=$(pid_file_for_player "$player_name")

  if [[ -f "$pid_file" ]]; then
    local existing_pid
    existing_pid=$(cat "$pid_file" 2>/dev/null)
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      kill "$existing_pid" 2>/dev/null || true
    fi
    rm -f "$pid_file"
  fi
}

register_player_pid() {
  local player_name="$1"
  local pid="$2"
  local pid_file
  pid_file=$(pid_file_for_player "$player_name")
  mkdir -p "$pid_dir"
  printf "%s\n" "$pid" > "$pid_file"
}

cleanup_player_pid_if_owned() {
  local player_name="$1"
  local pid="$2"
  local pid_file
  pid_file=$(pid_file_for_player "$player_name")

  if [[ -f "$pid_file" ]]; then
    local stored_pid
    stored_pid=$(cat "$pid_file" 2>/dev/null)
    if [[ "$stored_pid" == "$pid" ]]; then
      rm -f "$pid_file"
    fi
  fi
}

cleanup() {
  trap - INT TERM HUP
  for i in "${(@k)launched_pid_by_name}"; do
    local player_name="$i"
    local pid="${launched_pid_by_name[$i]}"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    cleanup_player_pid_if_owned "$player_name" "$pid"
  done
}
trap cleanup INT TERM HUP

# 1) Optionally kill existing instance(s) by matching player name only.
if [[ "$PA_KILL_EXISTING" != "false" ]]; then
  for player_name in "$@"; do
    kill_player_pid_if_running "$player_name"
  done
  sleep 0.2
fi

# 2) Start requested instances.
love_pids=()
typeset -A launched_pid_by_name
for player_name in "$@"; do
  identity_arg="$player_name"
  LOVE_IDENTITY="Panel Attack $identity_arg" PLAYER_NAME="$player_name" PA_SHOW_LOCAL="$PA_SHOW_LOCAL" \
    PA_NETWORK_LAG_MS="${PA_NETWORK_LAG_MS:-}" \
    PA_NETWORK_LAG_MIN_MS="${PA_NETWORK_LAG_MIN_MS:-}" \
    PA_NETWORK_LAG_MAX_MS="${PA_NETWORK_LAG_MAX_MS:-}" \
    love "$project_dir" &
  pid="$!"
  love_pids+=("$pid")
  launched_pid_by_name["$player_name"]="$pid"
  register_player_pid "$player_name" "$pid"
done

# Keep script alive while clients are alive.
wait "${love_pids[@]}"

for i in "${(@k)launched_pid_by_name}"; do
  cleanup_player_pid_if_owned "$i" "${launched_pid_by_name[$i]}"
done
