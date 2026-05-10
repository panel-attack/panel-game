#!/bin/zsh
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
set -o pipefail
cd "$(dirname "$0")"
pkill -f serverLauncher.lua 2>/dev/null || true
luajit serverLauncher.lua debug 2>&1 | tee logs/server.log
exit_code=${pipestatus[1]}
if [[ $exit_code -ne 0 ]]; then
	echo "run_server.sh: server exited with code $exit_code" >&2
fi
exit $exit_code
