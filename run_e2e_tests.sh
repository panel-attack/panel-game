#!/bin/zsh
# Run the end-to-end multiplayer protocol tests.
#
# Spins up a real Server inside the test process on port 49580 (NOT 49569 —
# we deliberately avoid the dev port so a running `run_server.sh` won't
# collide). Each scenario opens N real TCP sockets to localhost and drives
# the full client protocol.
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
set -o pipefail
cd "$(dirname "$0")"

E2E_PORT=49580

# Kill anything still bound to the e2e port from a previous (crashed) run.
port_pids=$(lsof -tiTCP:${E2E_PORT} -sTCP:LISTEN 2>/dev/null || true)
if [[ -n "$port_pids" ]]; then
	kill -9 $port_pids 2>/dev/null || true
	sleep 0.2
fi

mkdir -p logs
echo "Running E2E suite on port ${E2E_PORT}."
luajit e2eTestLauncher.lua 2>&1 | tee logs/e2e.log
exit_code=${pipestatus[1]}
if [[ $exit_code -ne 0 ]]; then
	echo "run_e2e_tests.sh: e2e suite exited with code $exit_code" >&2
fi
exit $exit_code
