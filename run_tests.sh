#!/bin/zsh
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
cd "$(dirname "$0")"
love ./testLauncher.lua
