#!/bin/zsh
source ~/.zshrc 2>/dev/null
cd "$(dirname "$0")"
LOVE_IDENTITY="Panel Attack ${1:-1}" PLAYER_NAME="${1:-Player1}" love ./

