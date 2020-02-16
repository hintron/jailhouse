#!/bin/bash
source ./common.sh > /dev/null

INPUT_FILE=tmp.input

# $1 - Workload (default $WM_COUNT_SET_BITS)
# $2 - Interference workload (default $INTF_HANDBRAKE)
# $3 - RUN_MODE (default $RM_INMATE)
# $4 - THROTTLE_MODE (default $TMODE_ITERATION)
# $5 - INPUT_FILE - If specified, then the input file will be used as the input
#       for all the iterations of the workload. The input range vars will be
#       ignored
function main {
    # Run different combinations of interference workloads and inmate workloads
    # ./start_experiment.sh $WM_SHA3           $INTF_HANDBRAKE $RM_INMATE
    # ./start_experiment.sh $WM_SHA3           $INTF_SHA3      $RM_INMATE
    # ./start_experiment.sh $WM_SHA3           $INTF_CSB       $RM_INMATE
    # ./start_experiment.sh $WM_SHA3           $INTF_RA        $RM_INMATE
    # ./start_experiment.sh $WM_SHA3           $INTF_NONE      $RM_INMATE

    ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_HANDBRAKE $RM_INMATE
    ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_SHA3      $RM_INMATE
    ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_CSB       $RM_INMATE
    ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_RA        $RM_INMATE
    ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE      $RM_INMATE

    ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_HANDBRAKE $RM_INMATE
    ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_SHA3      $RM_INMATE
    ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_CSB       $RM_INMATE
    ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_RA        $RM_INMATE
    ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE      $RM_INMATE

    # Run three types of inmate workloads with interference workload + throttle
    # ./start_experiment.sh $WM_SHA3           $INTF_HANDBRAKE $RM_INMATE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_HANDBRAKE $RM_INMATE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_HANDBRAKE $RM_INMATE

    # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_INMATE

    # # Run three types of inmate workloads without interference workload + throttle
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_INMATE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_INMATE
    # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_INMATE

    # # Run three types of *Linux* workloads with interference workload + throttle
    # ./start_experiment.sh $WM_SHA3           $INTF_HANDBRAKE $RM_LINUX
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_HANDBRAKE $RM_LINUX
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_HANDBRAKE $RM_LINUX

    # # Run CSB inmate workload without any throttling
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_INMATE $TMODE_DISABLED

    # # Run three types of Linux workloads without interference workload
    # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_LINUX
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_LINUX
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_LINUX

    # # Compare Linux workload to inmate workload with small (KB) inputs
    # create_random_file $((2**10 * 1)) tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_INMATE $TMODE_DISABLED tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_LINUX  $TMODE_DISABLED tmp.input
    # create_random_file $((2**10 * 10)) tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_INMATE $TMODE_DISABLED tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_LINUX  $TMODE_DISABLED tmp.input
    # create_random_file $((2**10 * 100)) tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_INMATE $TMODE_DISABLED tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_LINUX  $TMODE_DISABLED tmp.input
    # create_random_file $((2**10 * 1000)) tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_INMATE $TMODE_DISABLED tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_LINUX  $TMODE_DISABLED tmp.input
    # create_random_file $((2**10 * 10000)) tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_INMATE $TMODE_DISABLED tmp.input
    # ./start_experiment.sh $WM_SHA3 $INTF_NONE $RM_LINUX  $TMODE_DISABLED tmp.input

    # # Create a 20 MiB random file
    # create_random_file $((2**20 * 20)) $INPUT_FILE
    # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_LINUX           $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_LINUX_JAILHOUSE $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_INMATE          $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_LINUX           $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_LINUX_JAILHOUSE $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_INMATE          $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_LINUX           $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_LINUX_JAILHOUSE $TMODE_DISABLED $INPUT_FILE
    # rm $INPUT_FILE

    # # Create a 20 MiB file of all 'X' characters
    # create_inmate_local_input_file $INPUT_FILE
    # # If the workload is executed in the inmate, and the input file is
    # # `<local-input>`, then make the inmate generate its own 20 MiB input of all
    # # X's.
    # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_INMATE          $TMODE_DISABLED "<local-input>"
    # # Execute the same input in the inmate, but this time pass it over the
    # # shared memory channel instead.
    # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_INMATE          $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_LINUX_JAILHOUSE $TMODE_DISABLED $INPUT_FILE

    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_INMATE          $TMODE_DISABLED "<local-input>"
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_INMATE          $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_LINUX_JAILHOUSE $TMODE_DISABLED $INPUT_FILE

    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_INMATE          $TMODE_DISABLED "<local-input>"
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_INMATE          $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_LINUX_JAILHOUSE $TMODE_DISABLED $INPUT_FILE
    # rm $INPUT_FILE
}

# Call main here to allow for forward declaration (like Python)
# See https://stackoverflow.com/questions/13588457/forward-function-declarations-in-a-bash-or-a-shell-script
main "$@"
