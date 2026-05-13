#!/bin/zsh
# Run the client/common test suite via LÖVE.
#
# NOT truly headless — LÖVE 11.x always opens a window because the test
# bootstrap (GAME:load) pulls graphics-heavy modules (themes, stages,
# characters). Going fully headless would require disabling t.modules.window
# + t.modules.graphics in conf.lua AND refactoring testLauncher to skip the
# GAME init, which is out of scope here.
#
# Isolation from a running dev client:
#   - Distinct LOVE_IDENTITY so save dir doesn't conflict with the dev client
#   - main.lua swap is auto-recovered on next run if a prior run was killed
#
# Pass test name as $1 to run a single test file, e.g.
#   zsh run_tests.sh PuzzleSetIteratorTests
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

# Recover from a previous run that was killed before its trap could fire.
# If main.lua.bak exists at start, the last run died mid-swap and main.lua
# is currently the testLauncher copy — restore the real main.lua.
if [[ -f main.lua.bak ]]; then
  echo "run_tests.sh: recovering main.lua from a prior aborted run"
  mv main.lua.bak main.lua
fi

# Ensure cleanup runs on exit (success, failure, interrupt). SIGKILL is the
# only signal we can't trap; the recovery block above handles that case on
# the next invocation.
trap cleanup EXIT INT TERM HUP

# Swap entry points
mv main.lua main.lua.bak
cp testLauncher.lua main.lua

# Distinct save directory so a running dev client (LOVE_IDENTITY="Panel Attack")
# doesn't get its config / replays / state stomped by parallel test runs.
export LOVE_IDENTITY="Panel Attack Tests"

# Run tests (pass through any arguments like test filter)
love . "$@"
