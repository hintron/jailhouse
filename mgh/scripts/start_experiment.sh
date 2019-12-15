#!/bin/bash
source ./common.sh > /dev/null
################################################################################
# Script-wide inputs here
################################################################################
RUN_ON_LINUX=0

ROOT_CELL=../../configs/x86/bazooka-root.cell
INMATE_CELL=../../configs/x86/bazooka-inmate.cell
INMATE_NAME=bazooka-inmate
INMATE_PROGRAM=../../inmates/demos/x86/mgh-demo.bin
ITERATIONS=10
# ITERATIONS=4
THROTTLE_ITERATIONS=$(($ITERATIONS / 2))
INPUT_SIZE_START=$((14 * $MiB))
# INPUT_SIZE_END=$((16 * $MiB))
INPUT_SIZE_END=$((40 * $MiB))
INPUT_SIZE_STEP=$((1 * $MiB))
# INPUT_SIZE_STEP=$((100 * $KiB))
# We have up to 40 MiB, which is 41.9E6 bytes
experiment_time="$(timestamp)"
OUTPUT_DIR="output/${experiment_time}"
JAILHOUSE_OUTPUT_FILE="$OUTPUT_DIR/jailhouse_${experiment_time}.txt"
EXPERIMENT_OUTPUT_FILE="$OUTPUT_DIR/experiment_${experiment_time}.txt"
OUTPUT_DATA_FILE="$OUTPUT_DIR/data_${experiment_time}.csv"
OUTPUT_FREQ_FILE="$OUTPUT_DIR/freq_${experiment_time}.csv"
OUTPUT_DATA_THROTTLED_FILE="$OUTPUT_DIR/throttled_${experiment_time}.csv"
OUTPUT_DATA_THROTTLED_AVG_FILE="$OUTPUT_DIR/throttled_avg_${experiment_time}.csv"
OUTPUT_FREQ_THROTTLED_FILE="$OUTPUT_DIR/throttled_freq_${experiment_time}.csv"
OUTPUT_DATA_UNTHROTTLED_FILE="$OUTPUT_DIR/unthrottled_${experiment_time}.csv"
OUTPUT_DATA_UNTHROTTLED_AVG_FILE="$OUTPUT_DIR/unthrottled_avg_${experiment_time}.csv"
OUTPUT_FREQ_UNTHROTTLED_FILE="$OUTPUT_DIR/unthrottled_freq_${experiment_time}.csv"
INTERFERENCE_WORKLOAD_ENABLE=0
INTERFERENCE_WORKLOAD_OUTPUT="$OUTPUT_DIR/interference_${experiment_time}.txt"
# TODO: Make this experiment-dependent later
INTERFERENCE_WORKLOAD=$INTF_HANDBRAKE
# INTERFERENCE_WORKLOAD=$INTF_RANDOM
INTERFERENCE_RAMPUP_TIME=15


################################################################################
# Experiment-wide inmate inputs
################################################################################
# If true, just start the inmate and listen to the output. Don't generate and
# send inputs.
INMATE_DEBUG=0
# INMATE_DEBUG=1

THROTTLE_MODE=$TMODE_ITERATION
# THROTTLE_MODE=$TMODE_DISABLED
DEBUG_MODE="true"
# LOCAL_BUFFER="true"
# THROTTLE_MECHANISM=$TMECH_CLOCK
# WORKLOAD_MODE=$WM_COUNT_SET_BITS
# COUNT_SET_BITS_MODE=$CSBM_FASTEST
# POLLUTE_CACHE="true"

function main {
    ############################################################################
    # Script-wide setup
    ############################################################################
    # make output folder if it doesn't already exist
    mkdir -p $OUTPUT_DIR

    echo "Starting experiments at $experiment_time" >> $EXPERIMENT_OUTPUT_FILE
    echo "=======================================================" >> $EXPERIMENT_OUTPUT_FILE

    reset_jailhouse_all >> $EXPERIMENT_OUTPUT_FILE 2>&1

    echo "Start time: $experiment_time" >> $JAILHOUSE_OUTPUT_FILE
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

    # Start recording experiment output
    # Put process in the background and kill it once done
    sudo jailhouse console -f >> $JAILHOUSE_OUTPUT_FILE 2>&1 &
    tailf_pid=$!
    echo "tailf_pid: $tailf_pid" >> $EXPERIMENT_OUTPUT_FILE

    # Return early if just running tests in inmate with no inputs
    if [ "$INMATE_DEBUG" == 1 ]; then
        WORKLOAD_MODE=$WM_INMATE_DEBUG
        prep_experiment

        result=1
        count=0
        max_count=15
        while [ "$result" == 1 ]; do
            echo "$count seconds: running..." >> $EXPERIMENT_OUTPUT_FILE
            grep "MGH: Finish" $JAILHOUSE_OUTPUT_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1
            result=$!
            sleep 5
            count=$((count + 5))
            if [ $count > $max_count ]; then
                echo "Timed out: count:$count > max_count:$max_count" >> $EXPERIMENT_OUTPUT_FILE
                result=1
            fi
        done
        echo "$count s: Finished!" >> $EXPERIMENT_OUTPUT_FILE
    else
        # Pre-generate all input sizes beforehand
        generate_input_size_range

        ######################################################################
        # Inmate inputs
        ######################################################################
        WORKLOAD_MODE=${1:-$WM_COUNT_SET_BITS}
        INTERFERENCE_WORKLOAD_ENABLE=${2:-1}
        RUN_ON_LINUX=${3:-0}
        THROTTLE_MODE=${4:-$TMODE_ITERATION}
        ######################################################################
        start_experiment_jailhouse

        # Let's wait for the last iteration to print everything
        sleep 5
    fi

    # ##########################################################################
    # Final Cleanup
    # ##########################################################################

    # Flush any buffers
    end_time="$(timestamp)"
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
    echo "Ending experiments at $end_time" >> $JAILHOUSE_OUTPUT_FILE
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

    echo "sudo kill $tailf_pid" >> $EXPERIMENT_OUTPUT_FILE
    sudo kill $tailf_pid >> $EXPERIMENT_OUTPUT_FILE 2>&1
    # end_jailhouse_processes >> $EXPERIMENT_OUTPUT_FILE 2>&1

    end_inmate >> $EXPERIMENT_OUTPUT_FILE 2>&1
    end_root >> $EXPERIMENT_OUTPUT_FILE 2>&1

    echo "Ending experiments at $end_time" >> $EXPERIMENT_OUTPUT_FILE

    if [ "$INMATE_DEBUG" == 0 ]; then
        post_process_data
    fi
}

# Calculates the input sizes
# IN: $INPUT_SIZE_START
# IN: $INPUT_SIZE_END
# IN: $INPUT_SIZE_STEP
# OUT: $input_sizes
# OUT: $input_sizes_count
function generate_input_size_range {
    input_sizes=()
    for ((input_size = $INPUT_SIZE_START; input_size < $INPUT_SIZE_END; input_size += $INPUT_SIZE_STEP)); do
        input_sizes+=($input_size)
    done
    input_sizes_count=${#input_sizes[@]}
}

# Generates random inputs and stores them in random_inputs
# IN: $input_sizes
# IN: $input_sizes_count
# IN: $ITERATIONS
# OUT: $random_inputs
function generate_random_inputs {
    INPUT_FILE_BASE="input/input_${experiment_time}"
    # This will in effect be a 2d array of input files with pregenerated random data
    random_inputs=()
    for ((i = 0 ; i < $input_sizes_count ; i++)); do
        for ((j = 0 ; j < $ITERATIONS ; j++)); do
            # flatten 2d (i,j) index into a single flat index
            index=$(($i * $ITERATIONS + $j))
            input_file="${INPUT_FILE_BASE}_${index}.bin"
            create_random_file ${input_sizes[$i]} $input_file
            random_inputs+=($input_file)
        done
    done
}

# TODO: Get these Linux workloads to run under Intel VTune
# IN: $WORKLOAD_MODE
# IN: $ITERATIONS
# IN: $input_sizes_count
# IN: $random_inputs
# OUT: $expected_outputs
# OUT: $expected_output_times_ms
function generate_expected_outputs {
    expected_outputs=()
    expected_output_times_ms=()
    # This will in effect be a 2d array of expected output strings
    for ((i = 0 ; i < $input_sizes_count ; i++)); do
        for ((j = 0 ; j < $ITERATIONS ; j++)); do
            # flatten 2d (i,j) index into a single flat index
            index=$(($i * $ITERATIONS + $j))
            # Calculate and capture expected outputs
            start_time_ns=$(date +%s%N)
            expected_output=$(get_expected_output ${random_inputs[$index]} $WORKLOAD_MODE)
            end_time_ns=$(date +%s%N)
            duration_ns=$(($end_time_ns-$start_time_ns))
            duration_us=$(($duration_ns/1000))
            duration_ms=$(($duration_us/1000))
            expected_outputs+=($expected_output)
            expected_output_times_ms+=($duration_ms)
        done
    done
}

function post_process_data {
    grep_freq_data $JAILHOUSE_OUTPUT_FILE $OUTPUT_FREQ_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1

    # Separate throttled and unthrottled data
    grep_output_data_throttled $JAILHOUSE_OUTPUT_FILE > $OUTPUT_DATA_THROTTLED_FILE
    grep_output_data_unthrottled $JAILHOUSE_OUTPUT_FILE > $OUTPUT_DATA_UNTHROTTLED_FILE

    # Aggregate iterations for each input size
    for input_size in "${input_sizes[@]}"; do
        grep_token_columns_csv "$input_size" 2 3 $OUTPUT_DATA_THROTTLED_FILE >> $OUTPUT_DATA_THROTTLED_AVG_FILE
        grep_token_columns_csv "$input_size" 2 4 $OUTPUT_DATA_THROTTLED_FILE >> $OUTPUT_FREQ_THROTTLED_FILE
        grep_token_columns_csv "$input_size" 2 3 $OUTPUT_DATA_UNTHROTTLED_FILE >> $OUTPUT_DATA_UNTHROTTLED_AVG_FILE
        grep_token_columns_csv "$input_size" 2 4 $OUTPUT_DATA_UNTHROTTLED_FILE >> $OUTPUT_FREQ_UNTHROTTLED_FILE
    done
}

function start_experiment_linux {
    generate_random_inputs
}

function prep_experiment_jailhouse {
    INMATE_CMDLINE=$(set_cmdline) >> $EXPERIMENT_OUTPUT_FILE 2>&1
    start_jailhouse $ROOT_CELL $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE" >> $EXPERIMENT_OUTPUT_FILE 2>&1
}

function prep_experiment_linux {
    echo "TODO: prep_experiment_linux"
}

experiment_counter=1
function prep_experiment {
    # Start recording experiment output
    end_jailhouse >> $EXPERIMENT_OUTPUT_FILE 2>&1

    # Flush jailhouse output
    sleep 3
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Experiment $experiment_counter" >> $EXPERIMENT_OUTPUT_FILE
    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE

    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
    echo "Experiment $experiment_counter" >> $JAILHOUSE_OUTPUT_FILE
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

    if [ "$RUN_ON_LINUX" == 1 ]; then
        prep_experiment_linux
    else
        prep_experiment_jailhouse
    fi
}

function start_experiment_jailhouse {
    prep_experiment
    generate_random_inputs
    generate_expected_outputs

    if [ "$INTERFERENCE_WORKLOAD_ENABLE" == 1 ]; then
        start_interference_workload $INTERFERENCE_WORKLOAD >> $INTERFERENCE_WORKLOAD_OUTPUT 2>&1 &
        echo "Wait $INTERFERENCE_RAMPUP_TIME seconds for handbrake to ramp up" >> $EXPERIMENT_OUTPUT_FILE
        sleep $INTERFERENCE_RAMPUP_TIME
    fi

    for ((i = 0 ; i < $input_sizes_count ; i++)); do
        input_size=${input_sizes[$i]}
        echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE
        echo "Input Size=$input_size" >> $EXPERIMENT_OUTPUT_FILE
        echo "Time=$(timestamp)" >> $EXPERIMENT_OUTPUT_FILE
        echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE
        for ((j = 0 ; j < $ITERATIONS ; j++)); do
            # flatten 2d (i,j) index into a single flat index
            index=$(($i * $ITERATIONS + $j))
            if [ "$j" != "0" ]; then
                echo "---------------------------------------------------------" >> $EXPERIMENT_OUTPUT_FILE
            fi
            echo "Iteration $j ($index):" >> $EXPERIMENT_OUTPUT_FILE

            input_file=${random_inputs[$index]}
            expected_output_value="${expected_outputs[$index]}"

            if [ "$RUN_ON_LINUX" == 1 ]; then
                # On Linux, the workload output is just the expected value
                # already calculated
                workload_output_duration=${expected_output_times_ms[$index]}
                echo "Linux input size: $input_size" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                echo "Linux output: $expected_output_value" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                echo "Linux output duration: $workload_output_duration" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                # Put Linux workload timing data into jailhouse output file
                echo "MGHOUT:$index,$input_size,$workload_output_duration" >> $JAILHOUSE_OUTPUT_FILE
            else
                workload_output=$(send_inmate_input $input_file)
                echo "$workload_output" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                workload_output_value=$(grep_token_in_str "Inmate output: " "$workload_output")

                # Validate workload output against pre-calculated values
                if [ "$workload_output_value" != "$expected_output_value" ]; then
                    echo "Error: workload output != expected!" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                    echo "    workload_output_value  : $workload_output_value" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                    echo "    expected_output_value: $expected_output_value" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                else
                    echo "Workload output matches expected output" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                fi
            fi
        done
    done
    echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE

    if [ "$INTERFERENCE_WORKLOAD_ENABLE" == 1 ]; then
        stop_interference_workload $INTERFERENCE_WORKLOAD >> $EXPERIMENT_OUTPUT_FILE 2>&1
    fi

    for input_file in ${random_inputs[@]}; do
        # The input is just random data, so really no sense in keeping it around rn
        echo "sudo rm $input_file" >> $EXPERIMENT_OUTPUT_FILE
        sudo rm $input_file >> $EXPERIMENT_OUTPUT_FILE 2>&1
    done

    experiment_counter=$(($experiment_counter + 1))
}

# Call main here to allow for forward declaration (like Python)
# See https://stackoverflow.com/questions/13588457/forward-function-declarations-in-a-bash-or-a-shell-script
main "$@"
