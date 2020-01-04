#!/bin/bash
source ./common.sh > /dev/null

# $1: Workload mode
function main {
    ./start_experiment.sh $WM_COUNT_SET_BITS
    ./start_experiment.sh $WM_SHA3
    ./start_experiment.sh $WM_RANDOM_ACCESS
    # ./start_experiment.sh $WM_RANDOM_ACCESS 0 1
    # ./start_experiment.sh $WM_COUNT_SET_BITS 0 0 $TMODE_DISABLED
}

# Call main here to allow for forward declaration (like Python)
# See https://stackoverflow.com/questions/13588457/forward-function-declarations-in-a-bash-or-a-shell-script
main "$@"
