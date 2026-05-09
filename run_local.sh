#!/bin/zsh
source ~/.zshrc 2>/dev/null
cd "$(dirname "$0")"

# Open server in a new terminal window
osascript -e 'tell app "Terminal" to do script "cd '"$(pwd)"' && bash run_server.sh"'

# Run client in this window
love ./
