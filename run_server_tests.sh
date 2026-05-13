#!/bin/zsh
# Run the server-side unit/integration test suite in isolation.
#
# Does NOT kill or interfere with any running dev server on port 49569 —
# the tests use MockConnection / MockPersistence and never bind a real
# socket. Pass "debug" as the first arg for verbose logging.
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
set -o pipefail
cd "$(dirname "$0")"

luajit serverTestRunner.lua "$@"
