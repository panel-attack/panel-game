#!/bin/zsh

# Do not let each run_client invocation kill already launched clients.
PA_KILL_EXISTING=false PA_NETWORK_LAG_MIN_MS=120 PA_NETWORK_LAG_MAX_MS=180 zsh run_client.sh Lala &
PA_KILL_EXISTING=false PA_NETWORK_LAG_MIN_MS=80 PA_NETWORK_LAG_MAX_MS=400 zsh run_client.sh Bevy &
PA_KILL_EXISTING=false PA_NETWORK_LAG_MIN_MS=200 PA_NETWORK_LAG_MAX_MS=280 zsh run_client.sh Koozie &
# PA_KILL_EXISTING=false PA_NETWORK_LAG_MIN_MS=400 PA_NETWORK_LAG_MAX_MS=700 zsh run_client.sh Hayley &
PA_KILL_EXISTING=false PA_NETWORK_LAG_MIN_MS=20 PA_NETWORK_LAG_MAX_MS=600 zsh run_client.sh Amber &

# If interrupted, stop active background jobs started by this script.
trap 'kill $(jobs -pr) 2>/dev/null || true' INT TERM

wait