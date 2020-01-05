#!/bin/bash
source ./common.sh > /dev/null

# $1 - Workload (default $WM_COUNT_SET_BITS)
# $2 - Interference workload (default $INTF_HANDBRAKE)
# $3 - RUN_ON_LINUX (default 0)
# $4 - THROTTLE_MODE (default $TMODE_ITERATION)
function main {
    # ./start_experiment.sh $WM_COUNT_SET_BITS
    # ./start_experiment.sh $WM_SHA3
    # ./start_experiment.sh $WM_RANDOM_ACCESS
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_NONE 1
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE 1
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE 1
    ./start_experiment.sh $WM_SHA3 $INTF_HANDBRAKE 1
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE 0 $TMODE_DISABLED
}

# Call main here to allow for forward declaration (like Python)
# See https://stackoverflow.com/questions/13588457/forward-function-declarations-in-a-bash-or-a-shell-script
main "$@"
