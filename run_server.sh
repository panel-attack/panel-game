#!/bin/zsh
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
cd "$(dirname "$0")"
pkill -f serverLauncher.lua 2>/dev/null || true
luajit serverLauncher.lua debug 2>&1 | tee logs/server.log
