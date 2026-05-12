#!/bin/zsh
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

pidfiles=()
love_pids=()

for player_name in "$@"; do
  identity_arg="$player_name"
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

  LOVE_IDENTITY="Panel Attack $identity_arg" PLAYER_NAME="$player_name" PA_SHOW_LOCAL="$PA_SHOW_LOCAL" love "$project_dir" &
  love_pid=$!
  echo "$love_pid" > "$pidfile"
  pidfiles+=("$pidfile")
  love_pids+=("$love_pid")
done

cleanup() {
  trap - EXIT INT TERM HUP
  # Only fires when the script itself is terminating (Ctrl+C, SIGTERM, or after
  # `wait` returns because every client has already exited). Tear down only the
  # love instances we tracked — closing one window naturally won't reach here,
  # because `wait pid1 pid2 ...` keeps blocking until ALL listed pids exit.
  for p in "${love_pids[@]}"; do
    # `love` on macOS is typically a wrapper script around Love.app's binary,
    # so kill its child too in case our tracked pid is the wrapper.
    pkill -P "$p" 2>/dev/null || true
    kill "$p" 2>/dev/null || true
  done
  for f in "${pidfiles[@]}"; do
    rm -f "$f"
  done
}
trap cleanup EXIT INT TERM HUP
wait "${love_pids[@]}"
