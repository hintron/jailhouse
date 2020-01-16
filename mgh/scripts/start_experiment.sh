#!/bin/bash
source ./common.sh > /dev/null

################################################################################
#
# Script-wide inputs
#
################################################################################

# If true, just start the inmate and listen to the output. Don't generate and
# send inputs.
INMATE_DEBUG=0

# VTUNE_MODE=$VTUNE_MODE_UE
VTUNE_MODE=$VTUNE_MODE_MA

# If RUN_ON_LINUX is enabled, this says to run the workloads under Intel VTune
# RUN_WITH_VTUNE=1
RUN_WITH_VTUNE=0
# When doing Linux workloads, make Linux run on top of Jailhouse
LINUX_UNDER_JAILHOUSE=1
# LINUX_UNDER_JAILHOUSE=0
# When doing Linux workloads, turn off Turbo Boost
DISABLE_TURBO_BOOST=1
# DISABLE_TURBO_BOOST=0

# # 1-40 MiB Data Set
# ITERATIONS=10
# INPUT_SIZE_START=$((1 * $MiB))
# INPUT_SIZE_END=$((40 * $MiB))
# INPUT_SIZE_STEP=$((1 * $MiB))

# Short Range Data Set
ITERATIONS=1
INPUT_SIZE_START=$((14 * $MiB))
INPUT_SIZE_END=$((15 * $MiB))
INPUT_SIZE_STEP=$((1 * $MiB))

# # Short Step Data Set
# ITERATIONS=4
# INPUT_SIZE_START=$((14 * $MiB))
# INPUT_SIZE_END=$((16 * $MiB))
# INPUT_SIZE_STEP=$((100 * $KiB))
# # We have up to 40 MiB, which is 41.9E6 bytes

# Only used in Jailhouse
THROTTLE_ITERATIONS=$(($ITERATIONS / 2))

################################################################################
#
# End script-wide inputs
#
################################################################################

ROOT_CELL=$JAILHOUSE_DIR/configs/x86/bazooka-root.cell
INMATE_CELL=$JAILHOUSE_DIR/configs/x86/bazooka-inmate.cell
INMATE_NAME=bazooka-inmate
INMATE_PROGRAM=$JAILHOUSE_DIR/inmates/demos/x86/mgh-demo.bin
experiment_time="$(timestamp)"
OUTPUT_DIR="$SCRIPTS_DIR/output/${experiment_time}"
INPUT_DIR="$SCRIPTS_DIR/input"
WORKLOAD_DIR="$MGH_DIR/workloads"
WORKLOAD_BIN_DIR="$WORKLOAD_DIR/build"
MGH_DEMO_PY="$MGH_DIR/uio-userspace/mgh-demo.py"
JAILHOUSE_OUTPUT_FILE="$OUTPUT_DIR/jailhouse_${experiment_time}.txt"
LINUX_OUTPUT_FILE="$OUTPUT_DIR/linux_output_${experiment_time}.txt"
EXPERIMENT_OUTPUT_FILE="$OUTPUT_DIR/experiment_${experiment_time}.txt"
VTUNE_OUTPUT_DIR="$OUTPUT_DIR/vtune"
VTUNE_RESULTS_BASE="$VTUNE_OUTPUT_DIR/${experiment_time}"
VTUNE_OUTPUT_FILE="$OUTPUT_DIR/vtune_output_${experiment_time}.txt"
VTUNE_RUNS_FILE="$OUTPUT_DIR/vtune_runs_${experiment_time}.txt"
# VTUNE_TIMES_FILE="$OUTPUT_DIR/vtune_times_${experiment_time}.txt"
OUTPUT_DATA_FILE="$OUTPUT_DIR/data_${experiment_time}.csv"
OUTPUT_FREQ_FILE="$OUTPUT_DIR/freq_${experiment_time}.csv"
OUTPUT_DATA_THROTTLED_FILE="$OUTPUT_DIR/throttled_${experiment_time}.csv"
OUTPUT_DATA_THROTTLED_AVG_FILE="$OUTPUT_DIR/throttled_avg_${experiment_time}.csv"
OUTPUT_FREQ_THROTTLED_FILE="$OUTPUT_DIR/throttled_freq_${experiment_time}.csv"
OUTPUT_DATA_UNTHROTTLED_FILE="$OUTPUT_DIR/unthrottled_${experiment_time}.csv"
OUTPUT_DATA_UNTHROTTLED_AVG_FILE="$OUTPUT_DIR/unthrottled_avg_${experiment_time}.csv"
OUTPUT_FREQ_UNTHROTTLED_FILE="$OUTPUT_DIR/unthrottled_freq_${experiment_time}.csv"
INTERFERENCE_WORKLOAD_OUTPUT="$OUTPUT_DIR/interference_${experiment_time}.txt"
INTERFERENCE_RAMPUP_TIME=30

function main {
    ############################################################################
    # Script-wide setup
    ############################################################################
    # make output folder if it doesn't already exist
    mkdir -p $OUTPUT_DIR

    echo "=======================================================" >> $EXPERIMENT_OUTPUT_FILE
    echo "Starting script at $experiment_time" >> $EXPERIMENT_OUTPUT_FILE
    echo "=======================================================" >> $EXPERIMENT_OUTPUT_FILE

    # VTune doesn't work under a hypervisor, at least not out of the box
    if [ "$LINUX_UNDER_JAILHOUSE" == 1 ] && [ "$RUN_WITH_VTUNE" == 1 ]; then
        echo "Error: Cannot run Linux under Jailhouse while also running a Linux workload under VTune. Canceling experiment." >> $EXPERIMENT_OUTPUT_FILE
        return
    fi

    # Set script inputs as globals
    WORKLOAD_MODE=${1:-$WM_COUNT_SET_BITS}
    INTERFERENCE_WORKLOAD=${2:-$INTF_HANDBRAKE}
    RUN_ON_LINUX=${3:-0} # If 1, run workloads exclusively in Linux
    THROTTLE_MODE=${4:-$TMODE_ITERATION}
    INPUT_FILE=${5:-""}

    if [ "$DISABLE_TURBO_BOOST" == 1 ]; then
        disable_turbo_boost >> $EXPERIMENT_OUTPUT_FILE
    fi

    if [ "$RUN_ON_LINUX" == 1 ]; then
        if [ "$RUN_WITH_VTUNE" == 1 ]; then
            mkdir -p $VTUNE_OUTPUT_DIR
        fi
        reset_linux_all >> $EXPERIMENT_OUTPUT_FILE 2>&1
    fi

    if [ "$RUN_ON_LINUX" == 0 ] || [ "$LINUX_UNDER_JAILHOUSE" == 1 ]; then
        reset_jailhouse_all >> $EXPERIMENT_OUTPUT_FILE 2>&1
        echo "=======================================================" >> $JAILHOUSE_OUTPUT_FILE
        echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
        echo "Starting script at $experiment_time" >> $JAILHOUSE_OUTPUT_FILE
        echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
        # Start recording experiment output
        # Put process in the background and kill it once done
        sudo jailhouse console -f >> $JAILHOUSE_OUTPUT_FILE 2>&1 &
        tailf_pid=$!
        echo "tailf_pid: $tailf_pid" >> $EXPERIMENT_OUTPUT_FILE
    fi

    # Start the root cell here, so Linux is under Jailhouse
    if [ "$LINUX_UNDER_JAILHOUSE" == 1 ]; then
        start_root $ROOT_CELL >> $EXPERIMENT_OUTPUT_FILE
    fi

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
        if [ "$INPUT_FILE" != "" ]; then
            # Pre-generate all input sizes beforehand
            generate_input_size_range
        fi
        start_experiment

        # Let's wait for the last iteration to print everything
        sleep 5
    fi

    # ##########################################################################
    # Final Cleanup
    # ##########################################################################

    if [ "$DISABLE_TURBO_BOOST" == 1 ]; then
        enable_turbo_boost >> $EXPERIMENT_OUTPUT_FILE
    fi

    # Flush any buffers
    end_time="$(timestamp)"

    if [ "$RUN_ON_LINUX" == 0 ] || [ "$LINUX_UNDER_JAILHOUSE" == 1 ]; then
        echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
        echo "Ending experiments at $end_time" >> $JAILHOUSE_OUTPUT_FILE
        echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

        echo "sudo kill $tailf_pid" >> $EXPERIMENT_OUTPUT_FILE
        sudo kill $tailf_pid >> $EXPERIMENT_OUTPUT_FILE 2>&1
        # end_jailhouse_processes >> $EXPERIMENT_OUTPUT_FILE 2>&1

        if [ "$RUN_ON_LINUX" == 0 ]; then
            end_inmate >> $EXPERIMENT_OUTPUT_FILE 2>&1
        fi
        end_root >> $EXPERIMENT_OUTPUT_FILE 2>&1
    fi

    echo "Ending experiments at $end_time" >> $EXPERIMENT_OUTPUT_FILE

    if [ "$RUN_ON_LINUX" == 1 ]; then
        post_process_data_linux
    else
        if [ "$INMATE_DEBUG" == 0 ]; then
            post_process_data_jailhouse
        fi
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
    for ((input_size = "$INPUT_SIZE_START"; input_size < "$INPUT_SIZE_END"; input_size += "$INPUT_SIZE_STEP")); do
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
    INPUT_FILE_BASE="$INPUT_DIR/input_${experiment_time}"
    # This will in effect be a 2d array of input files with pregenerated random data
    random_inputs=()
    for ((i = 0 ; i < $input_sizes_count ; i++)); do
        for ((j = 0 ; j < $ITERATIONS ; j++)); do
            # flatten 2d (i,j) index into a single flat index
            local index=$(($i * $ITERATIONS + $j))
            local input_file="${INPUT_FILE_BASE}_${index}.bin"
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
            local index=$(($i * $ITERATIONS + $j))
            # Calculate and capture expected outputs
            local start_time_ns=$(date +%s%N)
            local expected_output=$(get_expected_output ${random_inputs[$index]} $index $WORKLOAD_MODE)
            local end_time_ns=$(date +%s%N)
            local duration_ns=$(($end_time_ns-$start_time_ns))
            local duration_ms=$(ns_to_ms $duration_ns)
            expected_outputs+=($expected_output)
            expected_output_times_ms+=($duration_ms)
        done
    done
}

function post_process_data_linux {
    if [ "$RUN_WITH_VTUNE" == 1 ]; then
        # Create a condensed list of VTune output folders
        grep_token_in_file "amplxe: Using result path " $VTUNE_OUTPUT_FILE > $VTUNE_RUNS_FILE
        # grep_token_in_file "Elapsed Time: " $VTUNE_OUTPUT_FILE > $VTUNE_TIMES_FILE
        # grep_all_but_token_in_file_to_file "amplxe:" $VTUNE_OUTPUT_FILE > $VTUNE_RUNS_FILE
    fi
}

function post_process_data_jailhouse {
    # Do not print out all MGHFREQ lines. Avg freq is already in MGHOUT

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

function prep_experiment_jailhouse {
    # Flush jailhouse output
    sleep 3
    echo "=======================================================" >> $JAILHOUSE_OUTPUT_FILE
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
    echo "Starting Experiment" >> $JAILHOUSE_OUTPUT_FILE
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

    local INMATE_CMDLINE=$(set_cmdline) >> $EXPERIMENT_OUTPUT_FILE 2>&1
    start_jailhouse $ROOT_CELL $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE" >> $EXPERIMENT_OUTPUT_FILE 2>&1
}

# TODO: fill in when necessary
function prep_experiment_linux {
    : # no-op placeholder
}

function prep_experiment {
    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Starting Experiment" >> $EXPERIMENT_OUTPUT_FILE
    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE

    if [ "$RUN_ON_LINUX" == 1 ]; then
        prep_experiment_linux
    else
        prep_experiment_jailhouse
    fi
}

function start_experiment {
    # Print out the experimental parameters
    log_parameters

    prep_experiment

    if [ "$INPUT_FILE" != "" ] ; then
        generate_random_inputs
    fi
    # If running on Linux, don't do this step until the interference workload
    # is running!
    if [ "$RUN_ON_LINUX" == 0 ] && [ "$INPUT_FILE" != "" ]; then
        generate_expected_outputs
    fi

    if [ "$INTERFERENCE_WORKLOAD" != "$INTF_NONE" ]; then
        start_interference_workload $INTERFERENCE_WORKLOAD >> $INTERFERENCE_WORKLOAD_OUTPUT 2>&1 &
        echo "Wait $INTERFERENCE_RAMPUP_TIME seconds for handbrake to ramp up" >> $EXPERIMENT_OUTPUT_FILE
        sleep $INTERFERENCE_RAMPUP_TIME
    fi

    if [ "$RUN_ON_LINUX" == 1 ]; then
        # Now that the interference workload is running, run the workloads on
        # Linux
        if [ "$INPUT_FILE" != "" ]; then
            generate_expected_outputs
        fi

        echo "MGHOUT:index,input_size(B),workload_output_duration(ms)" >> $LINUX_OUTPUT_FILE
    fi
    for ((i = 0 ; i < $input_sizes_count ; i++)); do
        if [ "$INPUT_FILE" == "" ]; then
            local input_size=${input_sizes[$i]}
        else
            local input_size=$(get_size_of_file_bytes $INPUT_FILE)
        fi
        echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE
        echo "Input Size=$input_size" >> $EXPERIMENT_OUTPUT_FILE
        echo "Time=$(timestamp)" >> $EXPERIMENT_OUTPUT_FILE
        echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE
        for ((j = 0 ; j < $ITERATIONS ; j++)); do
            # flatten 2d (i,j) index into a single flat index
            local index=$(($i * $ITERATIONS + $j))
            if [ "$j" != "0" ]; then
                echo "---------------------------------------------------------" >> $EXPERIMENT_OUTPUT_FILE
            fi
            echo "Iteration $j ($index):" >> $EXPERIMENT_OUTPUT_FILE

            if [ "$INPUT_FILE" == "" ]; then
                local input_file=${random_inputs[$index]}
            else
                local input_file="$INPUT_FILE"
            fi

            if [ "$INPUT_FILE" == "" ]; then
                local expected_output_value="${expected_outputs[$index]}"
            else
                local start_time_ns=$(date +%s%N)
                local expected_output_value=$(get_expected_output $INPUT_FILE $index $WORKLOAD_MODE)
                local end_time_ns=$(date +%s%N)
                local duration_ns=$(($end_time_ns-$start_time_ns))
                local duration_ms=$(ns_to_ms $duration_ns)
            fi

            if [ "$RUN_ON_LINUX" == 1 ]; then
                # On Linux, the workload output is just the expected value
                # already calculated
                if [ "$INPUT_FILE" == "" ]; then
                    local workload_output_duration=${expected_output_times_ms[$index]}
                else
                    local workload_output_duration=$duration_ms
                fi
                echo "Linux input size: $input_size" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                echo "Linux output: $expected_output_value" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                echo "Linux output duration: $workload_output_duration" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                # Put Linux workload timing data into jailhouse output file
                echo "MGHOUT:$index,$input_size,$workload_output_duration" >> $LINUX_OUTPUT_FILE
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

        # If input file was specified, break out of the input range loop
        # (we only need to execute one set of iterations)
        if [ "$INPUT_FILE" != "" ]; then
            break;
        fi
    done
    echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE

    if [ "$INTERFERENCE_WORKLOAD" != "$INTF_NONE" ]; then
        stop_interference_workload $INTERFERENCE_WORKLOAD >> $EXPERIMENT_OUTPUT_FILE 2>&1
    fi

    if [ "$INPUT_FILE" == "" ] ; then
        echo "Removing all generated random input files..." >> $EXPERIMENT_OUTPUT_FILE
        for input_file in ${random_inputs[@]}; do
            # The input is just random data, so really no sense in keeping it around rn
            # echo "sudo rm $input_file" >> $EXPERIMENT_OUTPUT_FILE
            sudo rm $input_file >> $EXPERIMENT_OUTPUT_FILE 2>&1
        done
    else
        # Skip input file deletion if input was specified
        # copy the input file for future reference
        cp "$INPUT_FILE" "$OUTPUT_DIR/input_${experiment_time}"
    fi

}

# Call main here to allow for forward declaration (like Python)
# See https://stackoverflow.com/questions/13588457/forward-function-declarations-in-a-bash-or-a-shell-script
main "$@"
