#!/bin/zsh
source ~/.zshrc 2>/dev/null
cd "$(dirname "$0")"
love ./ 2>&1 | tee logs/client.log

