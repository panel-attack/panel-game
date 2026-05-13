#!/bin/zsh
# CLI runner for the cross-perspective trace diff util.
#
# Usage:
#   zsh run_trace_diff.sh <left> <right> [--filter=send|recv]
#
# Each side can be either a trace_archive bundle dir or a single .jsonl
# file. Exit 0 = clean diff, 1 = divergences, 2 = arg error.
#
# Same luarocks-path setup as run_server_tests.sh so lfs / dkjson resolve
# correctly on macOS where the bundled .so files are Linux-built.
source ~/.zshrc 2>/dev/null
eval "$(luarocks path --local --lua-version 5.1)"
set -o pipefail
cd "$(dirname "$0")"

luajit traceDiff.lua "$@"
