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
#   - PA_TEST_MODE=1 makes main.lua dispatch to testLauncher (see main.lua
#     top of file). No source-tree swap — a SIGKILL'd test run can't strand
#     main.lua as testLauncher anymore.
#
# Pass test name as $1 to run a single test file, e.g.
#   zsh run_tests.sh PuzzleSetIteratorTests
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
cd "$(dirname "$0")"

# Legacy recovery: prior versions of this script did `mv main.lua main.lua.bak`
# and could leave the swap stranded on SIGKILL. If a .bak still exists, restore
# only when main.lua looks like the testLauncher copy; otherwise drop the stale
# backup. New runs never create main.lua.bak.
if [[ -f main.lua.bak ]]; then
  if head -n 1 main.lua | grep -q "PA_TEST_MODE\|local logger = require"; then
    echo "run_tests.sh: dropping stale main.lua.bak (main.lua is healthy)"
    rm main.lua.bak
  else
    echo "run_tests.sh: recovering main.lua from a prior aborted swap (legacy)"
    mv main.lua.bak main.lua
  fi
fi

# Distinct save directory so a running dev client (LOVE_IDENTITY="Panel Attack")
# doesn't get its config / replays / state stomped by parallel test runs.
export LOVE_IDENTITY="Panel Attack Tests"

# main.lua early-returns into testLauncher when this is set (see main.lua:1).
export PA_TEST_MODE=1

# Run tests (pass through any arguments like test filter)
love . "$@"
