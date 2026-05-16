#!/bin/zsh
#
# Launches a small bench of clients with mixed-realism network profiles so
# state-sync / catch-up / reconnect bugs surface locally.
#
# Profiles live in run_client.sh (see header). Mix-and-match below.
# Comment / uncomment lines to vary the bench.

# Do not let each run_client invocation kill already launched clients.
# PA_KILL_EXISTING=false PA_NETWORK_PROFILE=sluggish_wifi    zsh run_client.sh Lala &
# PA_KILL_EXISTING=false PA_NETWORK_PROFILE=mobile_train     zsh run_client.sh Bevy &
# PA_KILL_EXISTING=false PA_NETWORK_PROFILE=transcontinental zsh run_client.sh Koozie &
# PA_KILL_EXISTING=false PA_NETWORK_PROFILE=satellite        zsh run_client.sh Hayley &
PA_KILL_EXISTING=false PA_NETWORK_PROFILE=pathological     zsh run_client.sh Amber &
PA_KILL_EXISTING=false PA_NETWORK_PROFILE=pathological     zsh run_client.sh Brian &
PA_KILL_EXISTING=false PA_NETWORK_PROFILE=pathological     zsh run_client.sh Gromit &

# If interrupted, stop active background jobs started by this script.
trap 'kill $(jobs -pr) 2>/dev/null || true' INT TERM

wait
