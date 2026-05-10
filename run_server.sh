#!/bin/zsh
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
set -o pipefail
cd "$(dirname "$0")"

# Kill any previous server process and any process still holding the server port.
pkill -f serverLauncher.lua 2>/dev/null || true
port_pids=$(lsof -tiTCP:49569 -sTCP:LISTEN 2>/dev/null || true)
if [[ -n "$port_pids" ]]; then
	kill -9 $port_pids 2>/dev/null || true
	# Give the OS a brief moment to release the port before relaunching.
	sleep 0.2
fi
luajit serverLauncher.lua debug 2>&1 | tee logs/server.log
exit_code=${pipestatus[1]}
if [[ $exit_code -ne 0 ]]; then
	echo "run_server.sh: server exited with code $exit_code" >&2
fi
exit $exit_code
