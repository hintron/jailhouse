#!/bin/bash
source ./common.sh > /dev/null

INPUT_FILE=tmp.input

# TODO: Don't call a separate script - rather, turn that into a shell function
# and call the function. That way, variables can easily be passed!

# TODO: Use a configuration file instead of passing a thousand variables
# Have a default file, with modifications to the default
# https://unix.stackexchange.com/questions/175648/use-config-file-for-my-shell-script

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

    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_HANDBRAKE $RM_INMATE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_SHA3      $RM_INMATE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_CSB       $RM_INMATE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_RA        $RM_INMATE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE      $RM_INMATE

    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_HANDBRAKE $RM_INMATE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_SHA3      $RM_INMATE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_CSB       $RM_INMATE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_RA        $RM_INMATE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE      $RM_INMATE

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

    # # # Create a 20 MiB random file
    # # create_random_file $((2**20 * 20)) $INPUT_FILE
    # # # Create a 20 MiB file of all 'X' characters
    # # create_inmate_local_input_file $INPUT_FILE
    # # Create a 20 MiB random file using the prng as the inmate
    # create_inmate_local_random_input_file $INPUT_FILE
    # # If the workload is executed in the inmate, and the input file is
    # # `<local-input-uniform>`, then make the inmate generate its own 20 MiB input of all
    # # X's.
    # # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_INMATE          $TMODE_DISABLED "<local-input-uniform>"
    # # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_INMATE          $TMODE_DISABLED "<local-input-random>"
    # # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_INMATE          $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_LINUX           $TMODE_DISABLED $INPUT_FILE
    # # ./start_experiment.sh $WM_SHA3           $INTF_NONE $RM_LINUX_JAILHOUSE $TMODE_DISABLED $INPUT_FILE

    # # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_INMATE          $TMODE_DISABLED "<local-input-uniform>"
    # # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_INMATE          $TMODE_DISABLED "<local-input-random>"
    # # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_INMATE          $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_LINUX           $TMODE_DISABLED $INPUT_FILE
    # # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_NONE $RM_LINUX_JAILHOUSE $TMODE_DISABLED $INPUT_FILE

    # # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_INMATE          $TMODE_DISABLED "<local-input-uniform>"
    # # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_INMATE          $TMODE_DISABLED "<local-input-random>"
    # # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_INMATE          $TMODE_DISABLED $INPUT_FILE
    # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_LINUX           $TMODE_DISABLED $INPUT_FILE
    # # ./start_experiment.sh $WM_RANDOM_ACCESS  $INTF_NONE $RM_LINUX_JAILHOUSE $TMODE_DISABLED $INPUT_FILE
    # rm $INPUT_FILE


    # # Test different throttling parameters on 10x of a 20 MiB LOCAL input with RA interference workload and RA inmate workload
    # create_inmate_local_input_file $INPUT_FILE
    # # This is the default setting
    # # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE 1000 50000
    # # Try some deviations in spin loop iterations
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE
    # # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 50000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 45000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 40000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 35000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 30000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 25000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 20000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 15000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 10000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 9000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 8000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 7000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 6000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 5000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 4000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 3000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 2000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 1000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 500
    # # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE 500 5000
    # rm $INPUT_FILE

    # # Test different throttling parameters on 10x of a 20 MiB LOCAL input with RA interference workload and RA inmate workload
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 50000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 45000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 40000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 35000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 30000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 25000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 20000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 15000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 10000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 9000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 8000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 7000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 6000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 5000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 4000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 3000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 2000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 1000
    # ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION "" "" 500

    # ##########################################################################
    # Throttle Response Take 2: 2020-5-4; 2020-5-5
    # ##########################################################################
    # See how output reacts to changes in spin loop iterations
    # 20 MiB random input over IVSHMEM for RA, CSB, and SHA3 inmate workloads
    # RA interference workload
    # Do 10 runs at each setting
    # Cool down for 1 minute after completing 10-run sets at each setting
    # Cool down for 30 minutes after each workload so the next workload has a fresh start
    # (Defaults are a 1000 ms preemption timer loop and 50000 spin loop iterations)
    # (Sudo timeout happens every 15 minutes, so disable it)
    create_random_file $((2**20 * 20)) $INPUT_FILE

    # # Initial test run to make sure things look ok
    # ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 10000

    # SHA3
    for (( i = 80000; i >= 10000; i=i-5000 )); do
        ./start_experiment.sh $WM_SHA3 $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" $i
        sleep 60
    done
    for (( i = 9000; i >= 1000; i=i-1000 )); do
        ./start_experiment.sh $WM_SHA3 $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" $i
        sleep 60
    done
    ./start_experiment.sh $WM_SHA3 $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 500
    sleep 60
    ./start_experiment.sh $WM_SHA3 $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 0

    # Allow the CPU to cool down for 30 min
    sleep 1800

    # CSB
    for (( i = 80000; i >= 10000; i=i-5000 )); do
        ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" $i
        sleep 60
    done
    for (( i = 9000; i >= 1000; i=i-1000 )); do
        ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" $i
        sleep 60
    done
    ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 500
    sleep 60
    ./start_experiment.sh $WM_COUNT_SET_BITS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 0

    # Allow the CPU to cool down for 30 min
    sleep 1800

    # RA
    for (( i = 80000; i >= 10000; i=i-5000 )); do
        ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" $i
        sleep 60
    done
    for (( i = 9000; i >= 1000; i=i-1000 )); do
        ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" $i
        sleep 60
    done
    ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 500
    sleep 60
    ./start_experiment.sh $WM_RANDOM_ACCESS $INTF_RA $RM_INMATE $TMODE_ITERATION $INPUT_FILE "" 0

    rm $INPUT_FILE
    # # #####################################
    # # End
    # # #####################################


}

# Call main here to allow for forward declaration (like Python)
# See https://stackoverflow.com/questions/13588457/forward-function-declarations-in-a-bash-or-a-shell-script
main "$@"
