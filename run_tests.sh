#!/bin/zsh
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
cd "$(dirname "$0")"

# LÖVE 11.x workaround: swap main.lua with testLauncher.lua
# (LÖVE 12 will support `love . ./testLauncher.lua` directly)

cleanup() {
  if [[ -f main.lua.bak ]]; then
    mv main.lua.bak main.lua
  fi
}

# Ensure cleanup runs on exit (success, failure, or interrupt)
trap cleanup EXIT

# Swap entry points
mv main.lua main.lua.bak
cp testLauncher.lua main.lua

# Run tests (pass through any arguments like test filter)
love . "$@"
