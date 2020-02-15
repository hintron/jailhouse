#!/bin/bash
source ../scripts/common.sh

INPUT="workload_demo_input.bin"

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function main {
    HELP_STR="Please specify a workload (\`sha3\`, \`csb\`, or \`ra\`)"
    pids=()
    WORKLOAD="$1"
    THREADS="$2"

    WORKLOAD_BIN=""
    case "$WORKLOAD" in
        "sha3"|"sha-3" )
            WORKLOAD_BIN="$SHA3_BIN -f"
            ;;
        "csb"|"count-set-bits" )
            WORKLOAD_BIN=$CSB_BIN
            ;;
        "ra"|"random-access" )
            WORKLOAD_BIN=$RA_BIN
            ;;
        * )
            echo "$HELP_STR"
            exit
            ;;
    esac

    if [ -z $THREADS ]; then
        THREADS=6
    fi

    # Warning: with a 1 GiB input file, this will take about 1 GiB of memory per
    # thread
    echo "Creating a 1 GiB ($GiB B) file of random data to run the workloads on"
    create_random_file $GiB $INPUT
    echo "Starting up $THREADS $WORKLOAD workloads in parallel"

    # Continuously work on stuff until this gets killed
    i=0
    while :
    do
        printf "Iteration $i: Workload PIDs:"
        # Since the workloads are all single-threaded, run one per core
        for (( j = 0; j < THREADS; j++ )); do
            $WORKLOAD_BIN $INPUT > /dev/null &
            pid=$!
            printf " $pid"
            pids+=($pid)
            if [[ $j == $((THREADS-1)) ]]; then
                echo ""
            fi
        done

        # Wait for all workloads to finish
        wait
        # Clear all the finished PIDs
        pids=()
        i=$((i+1))
    done
}

# For proper cleanup, either do ctrl-c in foreground or do `kill -s INT <pid>`
function ctrl_c() {
    echo "Cancelling all background workload tasks"
    for pid in "${pids[@]}"
    do
       echo "Killing PID $pid"
       kill $pid
    done
    echo "Removing $INPUT"
    rm $INPUT
    exit
}

main "$@"
