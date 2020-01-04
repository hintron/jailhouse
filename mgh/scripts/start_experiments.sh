#!/bin/bash
source ./common.sh > /dev/null

# If true, just start the inmate and listen to the output. Don't generate and
# send inputs.
INMATE_DEBUG=0
# INMATE_DEBUG=1

VTUNE_MODE=$VTUNE_MODE_MA

# TODO: Make this experiment-dependent later
INTERFERENCE_WORKLOAD=$INTF_HANDBRAKE
# INTERFERENCE_WORKLOAD=$INTF_RANDOM

ITERATIONS=10
INPUT_SIZE_START=$((1 * $MiB))
INPUT_SIZE_END=$((40 * $MiB))
INPUT_SIZE_STEP=$((1 * $MiB))
# ITERATIONS=1
# INPUT_SIZE_START=$((14 * $MiB))
# INPUT_SIZE_END=$((15 * $MiB))
# INPUT_SIZE_STEP=$((1 * $MiB))
# ITERATIONS=4
# INPUT_SIZE_START=$((14 * $MiB))
# INPUT_SIZE_END=$((16 * $MiB))
# INPUT_SIZE_STEP=$((100 * $KiB))
# We have up to 40 MiB, which is 41.9E6 bytes

THROTTLE_ITERATIONS=$(($ITERATIONS / 2))

# If RUN_ON_LINUX is enabled, this says to run the workloads under Intel VTune
RUN_WITH_VTUNE=1

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
