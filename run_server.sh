#!/bin/zsh
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
set -o pipefail
cd "$(dirname "$0")"

# Kill any previous server process and anything still holding our ports.
# Server binds 3 ports: 49569 (gameplay), 49570 (lobby), 49571 (spectate).
pkill -f serverLauncher.lua 2>/dev/null || true
port_pids=$(lsof -tiTCP:49569,49570,49571 -sTCP:LISTEN 2>/dev/null || true)
if [[ -n "$port_pids" ]]; then
	kill -9 ${=port_pids} 2>/dev/null || true
fi

# Wait for ports to actually be free. SO_REUSEADDR handles TIME_WAIT, but a
# freshly-killed process can still own the listener for a tick. Polls every
# 0.1s, gives up after 10s and lets the server's own retry loop take over.
deadline=$(( $(date +%s) + 10 ))
while (( $(date +%s) < deadline )); do
	if [[ -z "$(lsof -tiTCP:49569,49570,49571 -sTCP:LISTEN 2>/dev/null)" ]]; then
		break
	fi
	sleep 0.1
done

echo "Starting server on ports 49569/49570/49571 (output is activity-driven; idle server may appear silent)."
luajit serverLauncher.lua debug 2>&1 | tee logs/server.log
exit_code=${pipestatus[1]}
if [[ $exit_code -ne 0 ]]; then
	echo "run_server.sh: server exited with code $exit_code" >&2
fi
exit $exit_code
