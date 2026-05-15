#!/bin/zsh
#
# Usage:
#   zsh run_client.sh                    # launch one client as "Player1"
#   zsh run_client.sh Alice              # launch one client as "Alice"
#   zsh run_client.sh Alice Bob          # launch two clients in parallel
#
# Simulated network conditions (DEV ONLY — prod never sets these env vars).
# All three TCP sockets (gameplay, spectate, lobby) share the params. Lag is
# per direction so RTT ~= 2x. Lag only one side for realism by running two
# terminals and only setting the vars in one.
#
# Quick path: pick a named profile.
#   PA_NETWORK_PROFILE=mobile_train zsh run_client.sh Alice
#
# Available profiles:
#   none              No simulated lag (default)
#   sluggish_wifi     120–180ms, mild jitter
#   mobile_train      80–400ms, wide jitter + bursty spikes
#   subway            80–300ms with periodic 500ms stalls (tunnels)
#   transcontinental  200–280ms, modest jitter (US↔Asia feel)
#   satellite         400–700ms with 2% loss
#   bad_wifi          40–200ms with bursty spikes (microwave/AP contention)
#   lossy_dsl         60–150ms, 2% loss, 512Kbps uplink cap
#   pathological      Everything at once — worst-case race finder
#
# Manual knobs (override or compose on top of a profile):
#   PA_NETWORK_LAG_MS=N                  # fixed N ms each direction
#   PA_NETWORK_LAG_MIN_MS=A MAX_MS=B     # exp-skewed range, P(spike)≈0.7%
#   PA_NETWORK_LOSS_PCT=2                # 2% packets eat +RTO (TCP retransmit)
#   PA_NETWORK_RTO_MS=250                # the +RTO added on loss (default 250)
#   PA_NETWORK_STALL_HZ=0.125            # one stall every ~8s
#   PA_NETWORK_STALL_MS=500              # stall duration
#   PA_NETWORK_BURST_MS=800              # cluster spikes for this many ms
#   PA_NETWORK_BANDWIDTH_KBPS=512        # cap upload bandwidth (0 = off)
#
# Examples:
#   PA_NETWORK_PROFILE=subway zsh run_client.sh Alice
#   PA_NETWORK_PROFILE=mobile_train PA_NETWORK_LOSS_PCT=5 zsh run_client.sh Bob
#   zsh run_client.sh Carl       # second terminal, no lag — the "good" peer


source ~/.zshrc 2>/dev/null
cd "$(dirname "$0")"
project_dir=$(pwd)
pid_dir="$project_dir/logs/client_pids"

# Resolve a named profile into env vars. Explicit per-knob env vars set by
# the caller win (`: ${VAR:=...}` only fills unset values).
case "${PA_NETWORK_PROFILE:-}" in
  ""|none)
    ;;
  sluggish_wifi)
    : ${PA_NETWORK_LAG_MIN_MS:=120}; : ${PA_NETWORK_LAG_MAX_MS:=180}
    ;;
  mobile_train)
    : ${PA_NETWORK_LAG_MIN_MS:=80};  : ${PA_NETWORK_LAG_MAX_MS:=400}
    : ${PA_NETWORK_BURST_MS:=600}
    ;;
  subway)
    : ${PA_NETWORK_LAG_MIN_MS:=80};  : ${PA_NETWORK_LAG_MAX_MS:=300}
    : ${PA_NETWORK_STALL_HZ:=0.125}; : ${PA_NETWORK_STALL_MS:=500}
    ;;
  transcontinental)
    : ${PA_NETWORK_LAG_MIN_MS:=200}; : ${PA_NETWORK_LAG_MAX_MS:=280}
    ;;
  satellite)
    : ${PA_NETWORK_LAG_MIN_MS:=400}; : ${PA_NETWORK_LAG_MAX_MS:=700}
    : ${PA_NETWORK_LOSS_PCT:=2}
    ;;
  bad_wifi)
    : ${PA_NETWORK_LAG_MIN_MS:=40};  : ${PA_NETWORK_LAG_MAX_MS:=200}
    : ${PA_NETWORK_BURST_MS:=800}
    ;;
  lossy_dsl)
    : ${PA_NETWORK_LAG_MIN_MS:=60};  : ${PA_NETWORK_LAG_MAX_MS:=150}
    : ${PA_NETWORK_LOSS_PCT:=2};     : ${PA_NETWORK_BANDWIDTH_KBPS:=512}
    ;;
  pathological)
    : ${PA_NETWORK_LAG_MIN_MS:=20};  : ${PA_NETWORK_LAG_MAX_MS:=600}
    : ${PA_NETWORK_BURST_MS:=1000}
    : ${PA_NETWORK_STALL_HZ:=0.05};  : ${PA_NETWORK_STALL_MS:=800}
    : ${PA_NETWORK_LOSS_PCT:=3}
    ;;
  *)
    echo "Unknown PA_NETWORK_PROFILE: $PA_NETWORK_PROFILE" >&2
    echo "Valid: none sluggish_wifi mobile_train subway transcontinental satellite bad_wifi lossy_dsl pathological" >&2
    exit 1
    ;;
esac

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
    PA_NETWORK_LOSS_PCT="${PA_NETWORK_LOSS_PCT:-}" \
    PA_NETWORK_RTO_MS="${PA_NETWORK_RTO_MS:-}" \
    PA_NETWORK_STALL_HZ="${PA_NETWORK_STALL_HZ:-}" \
    PA_NETWORK_STALL_MS="${PA_NETWORK_STALL_MS:-}" \
    PA_NETWORK_BURST_MS="${PA_NETWORK_BURST_MS:-}" \
    PA_NETWORK_BANDWIDTH_KBPS="${PA_NETWORK_BANDWIDTH_KBPS:-}" \
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
