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

VTUNE_MODE=$VTUNE_MODE_UE
# VTUNE_MODE=$VTUNE_MODE_MA

# This says to run the workloads under Intel VTune (Linux-only)
# RUN_WITH_VTUNE=1
RUN_WITH_VTUNE=0
# When doing Linux workloads, turn off Turbo Boost (not sure this works...)
DISABLE_TURBO_BOOST=1
# DISABLE_TURBO_BOOST=0

# If 1, check the inmate's output to make sure it matches expected output
# This can cause extra slowdown when enabled. Only applicable with RM_INMATE.
VALIDATE_INMATE_RESULT=0
# VALIDATE_INMATE_RESULT=1

# # 1-39 MiB Data Set
ITERATIONS=10
# INPUT_SIZE_START=$((1 * $MiB))
# INPUT_SIZE_END=$((40 * $MiB))
# INPUT_SIZE_STEP=$((1 * $MiB))

# # Short Range Data Set
# ITERATIONS=2
# INPUT_SIZE_START=$((20 * $MiB))
# INPUT_SIZE_END=$((21 * $MiB))
# INPUT_SIZE_STEP=$((1 * $MiB))

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

# common.sh will have set up SCRIPTS_DIR, MGH_DIR, and JAILHOUSE_DIR

ROOT_CELL=$JAILHOUSE_DIR/configs/x86/bazooka-root.cell
INMATE_CELL=$JAILHOUSE_DIR/configs/x86/bazooka-inmate.cell
INMATE_NAME=bazooka-inmate
INMATE_PROGRAM=$JAILHOUSE_DIR/inmates/demos/x86/mgh-demo.bin
experiment_time="$(timestamp)"
COMMIT="$(get_git_commit)"
OUTPUT_DIR="$SCRIPTS_DIR/output/${experiment_time}"
INPUT_DIR="$SCRIPTS_DIR/input"
SOURCES_DIR="~/Videos/sources"
JAILHOUSE_OUTPUT_BASENAME="jailhouse_${experiment_time}.txt"
JAILHOUSE_OUTPUT_FILE="$OUTPUT_DIR/$JAILHOUSE_OUTPUT_BASENAME"
LINUX_OUTPUT_BASENAME="linux_output_${experiment_time}.txt"
LINUX_OUTPUT_FILE="$OUTPUT_DIR/$LINUX_OUTPUT_BASENAME"
EXPERIMENT_OUTPUT_FILE="$OUTPUT_DIR/experiment_${experiment_time}.txt"
VTUNE_OUTPUT_DIR="$OUTPUT_DIR/vtune"
VTUNE_RESULTS_BASE="$VTUNE_OUTPUT_DIR/${experiment_time}"
VTUNE_OUTPUT_BASENAME="vtune_output_${experiment_time}.txt"
VTUNE_OUTPUT_FILE="$OUTPUT_DIR/$VTUNE_OUTPUT_BASENAME"
OUTPUT_DATA_FILE="$OUTPUT_DIR/data_${experiment_time}.csv"
OUTPUT_FREQ_FILE="$OUTPUT_DIR/freq_${experiment_time}.csv"
INTERFERENCE_WORKLOAD_OUTPUT="$OUTPUT_DIR/interference_${experiment_time}.txt"
INTERFERENCE_RAMPUP_TIME=30

LOCAL_INPUT_UNIFORM_TOKEN="<local-input-uniform>"
LOCAL_INPUT_RANDOM_TOKEN="<local-input-random>"
LOCAL_INPUT_MODE=$LI_NONE # Must be initialized

input_sizes=()
input_sizes_count=0
workload_pid=""


function main {
    ############################################################################
    # Script-wide setup
    ############################################################################
    # make output folder if it doesn't already exist
    mkdir -p $OUTPUT_DIR

    echo "=======================================================" >> $EXPERIMENT_OUTPUT_FILE
    echo "Starting script at $experiment_time" >> $EXPERIMENT_OUTPUT_FILE
    echo "=======================================================" >> $EXPERIMENT_OUTPUT_FILE

    # Set script inputs as globals
    WORKLOAD_MODE=${1:-$WM_COUNT_SET_BITS}
    INTERFERENCE_WORKLOAD=${2:-$INTF_HANDBRAKE}
    RUN_MODE=${3:-$RM_INMATE}
    THROTTLE_MODE=${4:-$TMODE_ITERATION}
    INPUT_FILE=${5:-""}
    PREEMPTION_TIMEOUT=${6:-""}
    SPIN_LOOP_ITERATIONS=${7:-""}

    # See if local input mode is used
    case "$INPUT_FILE" in
    "$LOCAL_INPUT_UNIFORM_TOKEN")
        LOCAL_INPUT_MODE=$LI_UNIFORM
        ;;
    "$LOCAL_INPUT_RANDOM_TOKEN")
        LOCAL_INPUT_MODE=$LI_RANDOM
        ;;
    *)
        ;;
    esac

    # VTune doesn't work under a hypervisor, at least not out of the box
    if [ "$RUN_MODE" == "$RM_LINUX_JAILHOUSE" ] && [ "$RUN_WITH_VTUNE" == 1 ]; then
        echo "Error: Cannot run Linux under Jailhouse while also running a Linux workload under VTune. Canceling experiment." >> $EXPERIMENT_OUTPUT_FILE
        return
    fi

    if [ "$ITERATIONS" == 0 ]; then
        echo "Error: Need at least 1 iteration for the experiments to work" >> $EXPERIMENT_OUTPUT_FILE
        return
    fi

    if [ "$ITERATIONS" == 1 ] && [ "$THROTTLE_MODE" == "$TMODE_ITERATION" ]; then
        echo "Error: Need >= 2 iterations for iteration throttle mode to work" >> $EXPERIMENT_OUTPUT_FILE
        return
    fi

    if [ "$LOCAL_INPUT_MODE" != "$LI_NONE" ] && [ "$RUN_MODE" != "$RM_INMATE" ]; then
        echo "Error: Local file input mode ($LOCAL_INPUT_MODE) can only be used with run mode RM_INMATE. Canceling experiment..." >> $EXPERIMENT_OUTPUT_FILE
        return
    fi

    if [ "$DISABLE_TURBO_BOOST" == 1 ]; then
        disable_turbo_boost >> $EXPERIMENT_OUTPUT_FILE
    fi

    if [[ "$RUN_MODE" > "$RM_INMATE" ]]; then
        if [ "$RUN_WITH_VTUNE" == 1 ]; then
            mkdir -p $VTUNE_OUTPUT_DIR
        fi
        build_linux_workloads >> $EXPERIMENT_OUTPUT_FILE 2>&1
    fi

    if [ "$RUN_MODE" == "$RM_INMATE" ] || [ "$RUN_MODE" == "$RM_LINUX_JAILHOUSE" ]; then
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
    if [ "$RUN_MODE" == "$RM_LINUX_JAILHOUSE" ]; then
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
        if [ "$INPUT_FILE" == "" ]; then
            # Generate input sizes and append to global input_sizes array
            generate_input_size_range $INPUT_SIZE_START $INPUT_SIZE_END $INPUT_SIZE_STEP
            input_sizes_count=${#input_sizes[@]}
        else
            # We only need to iterate over one file
            input_sizes_count=1
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

    if [ "$RUN_MODE" == "$RM_INMATE" ] || [ "$RUN_MODE" == "$RM_LINUX_JAILHOUSE" ]; then
        # Flush any buffers
        echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
        echo "Ending experiments at $(timestamp)" >> $JAILHOUSE_OUTPUT_FILE
        echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

        echo "Killing interference workload at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE 2>&1

        echo "sudo kill $tailf_pid" >> $EXPERIMENT_OUTPUT_FILE
        sudo kill $tailf_pid >> $EXPERIMENT_OUTPUT_FILE 2>&1

        echo "Killing any Jailhouse processes workload at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE 2>&1
        end_jailhouse_processes >> $EXPERIMENT_OUTPUT_FILE 2>&1

        if [ "$RUN_MODE" == "$RM_INMATE" ]; then
            echo "Shutting down Jailhouse inmate at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE 2>&1
            end_inmate >> $EXPERIMENT_OUTPUT_FILE 2>&1
        fi
        echo "Shutting down Jailhouse root at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE 2>&1
        end_root >> $EXPERIMENT_OUTPUT_FILE 2>&1
    fi

    # Clean up any leftover stuff
    echo "Removing drivers at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE 2>&1
    rm_drivers >> $EXPERIMENT_OUTPUT_FILE 2>&1

    echo "Post processing data at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE 2>&1
    post_process_data $OUTPUT_DIR $experiment_time

    echo "Ending experiments at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE
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

    if [[ "$RUN_MODE" > "$RM_INMATE" ]]; then
        prep_experiment_linux
    else
        prep_experiment_jailhouse
    fi
}

function start_experiment {
    # Print out the experimental parameters
    log_parameters
    prep_experiment

    if [ "$INPUT_FILE" == "" ] ; then
        generate_random_inputs
    fi

    # If running on Linux, don't do this step until the interference workload
    # is running!
    if [ "$RUN_MODE" == "$RM_INMATE" ] && [ "$INPUT_FILE" == "" ] && [ "$VALIDATE_INMATE_RESULT" == 1 ]; then
        generate_expected_outputs
    fi

    if [ "$INTERFERENCE_WORKLOAD" != "$INTF_NONE" ]; then
        start_interference_workload $INTERFERENCE_WORKLOAD
        echo "Wait $INTERFERENCE_RAMPUP_TIME seconds for interference workload $INTERFERENCE_WORKLOAD (PID $workload_pid) to ramp up" >> $EXPERIMENT_OUTPUT_FILE
        sleep $INTERFERENCE_RAMPUP_TIME
    fi

    if [[ "$RUN_MODE" > "$RM_INMATE" ]]; then
        # Now that the interference workload is running, run the workloads on
        # Linux
        if [ "$INPUT_FILE" == "" ]; then
            generate_expected_outputs
        fi

        echo "MGHOUT:index,input_size(B),workload_output_duration(ms)" >> $LINUX_OUTPUT_FILE
    fi

    # If $INPUT_FILE is specified, $input_sizes_count is just 1
    for ((i = 0 ; i < $input_sizes_count ; i++)); do
        if [ "$INPUT_FILE" == "" ]; then
            local input_size=${input_sizes[$i]}
        elif [ "$LOCAL_INPUT_MODE" == "$LI_NONE" ]; then
            local input_size=$(get_size_of_file_bytes $INPUT_FILE)
        fi
        echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE
        case "$LOCAL_INPUT_MODE" in
        "$LI_NONE")
            echo "Input Size=$input_size" >> $EXPERIMENT_OUTPUT_FILE
            ;;
        "$LI_UNIFORM")
            echo "Input Local UNIFORM" >> $EXPERIMENT_OUTPUT_FILE
            ;;
        "$LI_RANDOM")
            echo "Input Local RANDOM" >> $EXPERIMENT_OUTPUT_FILE
            ;;
        *)
            ;;
        esac
        echo "Starting at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE
        echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE
        for ((j = 0 ; j < $ITERATIONS ; j++)); do
            local vmexits_start=0
            local vmexits_end=0
            # flatten 2d (i,j) index into a single flat index
            local index=$(($i * $ITERATIONS + $j))
            if [ "$j" != "0" ]; then
                echo "---------------------------------------------------------" >> $EXPERIMENT_OUTPUT_FILE
            fi
            echo "Iteration $j ($index) starting at $(timestamp):" >> $EXPERIMENT_OUTPUT_FILE

            if [ "$VALIDATE_INMATE_RESULT" == 1 ] || [ "$RUN_MODE" != "$RM_INMATE" ]; then
                if [ "$INPUT_FILE" == "" ]; then
                    local expected_output_value="${expected_outputs[$index]}"
                else
                    local start_time_ns=$(date +%s%N)
                    if [[ "$RUN_MODE" == "$RM_LINUX_JAILHOUSE" ]]; then
                        vmexits_start=$(jailhouse_root_total_vmexits)
                    fi
                    local expected_output_value=$(get_expected_output $INPUT_FILE $index $WORKLOAD_MODE)
                    if [[ "$RUN_MODE" == "$RM_LINUX_JAILHOUSE" ]]; then
                        vmexits_end=$(jailhouse_root_total_vmexits)
                    fi
                    local end_time_ns=$(date +%s%N)
                    local duration_ns=$(($end_time_ns-$start_time_ns))
                    local duration_ms=$(ns_to_ms $duration_ns)
                fi
            fi

            if [[ "$RUN_MODE" > "$RM_INMATE" ]]; then
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
                if [ "$RUN_MODE" == "$RM_LINUX_JAILHOUSE" ]; then
                    local vmexits_delta=$((vmexits_end - vmexits_start))
                    echo "Root cell vmexits delta: $vmexits_delta = ($vmexits_end - $vmexits_start)" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                fi
                # Put Linux workload timing data into jailhouse output file
                echo "MGHOUT:$index,$input_size,$workload_output_duration" >> $LINUX_OUTPUT_FILE
            else
                vmexits_start=$(jailhouse_inmate_total_vmexits)
                if [ "$INPUT_FILE" == "" ]; then
                    workload_output=$(send_inmate_input ${random_inputs[$index]})
                else
                    workload_output=$(send_inmate_input $INPUT_FILE)
                fi
                vmexits_end=$(jailhouse_inmate_total_vmexits)
                echo "$workload_output" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                workload_output_value=$(grep_token_in_str "Inmate output: " "$workload_output")
                local vmexits_delta=$((vmexits_end - vmexits_start))
                echo "Inmate vmexits delta: $vmexits_delta = ($vmexits_end - $vmexits_start)" >> $EXPERIMENT_OUTPUT_FILE 2>&1

                if [ "$VALIDATE_INMATE_RESULT" == 1 ]; then
                    # Validate workload output against pre-calculated values
                    if [ "$workload_output_value" != "$expected_output_value" ]; then
                        echo "Error: workload output != expected!" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                        echo "    workload_output_value  : $workload_output_value" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                        echo "    expected_output_value: $expected_output_value" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                    else
                        echo "Workload output matches expected output" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                    fi
                fi
            fi
            echo "Iteration $j ($index) ending at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE 2>&1
        done
    done
    echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE

    if [ "$INTERFERENCE_WORKLOAD" != "$INTF_NONE" ]; then
        echo "Stopping workload $INTERFERENCE_WORKLOAD (pid=$workload_pid) at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE
        stop_interference_workload $INTERFERENCE_WORKLOAD $workload_pid >> $EXPERIMENT_OUTPUT_FILE 2>&1
    fi

    if [ "$INPUT_FILE" == "" ] ; then
        echo "Removing all generated random input files at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE
        for input_file in ${random_inputs[@]}; do
            # The input is just random data, so really no sense in keeping it around rn
            # echo "sudo rm $input_file" >> $EXPERIMENT_OUTPUT_FILE
            sudo rm $input_file >> $EXPERIMENT_OUTPUT_FILE 2>&1
        done
    elif [ "$LOCAL_INPUT_MODE" == "$LI_NONE" ]; then
        # Skip input file deletion if input was specified
        # copy the input file for future reference
        cp "$INPUT_FILE" "$OUTPUT_DIR/${experiment_time}.input"
    fi
    echo "Ending start_experiment at $(timestamp)" >> $EXPERIMENT_OUTPUT_FILE 2>&1
}

function handle_ctlc()
{
    echo ""
    echo "Handling ctrl-c"
    if [ "$workload_pid" != "" ]; then
        echo "Canceling interference workload $INTERFERENCE_WORKLOAD"
        stop_interference_workload $INTERFERENCE_WORKLOAD $workload_pid
    fi
    echo "Ending Jailhouse"
    end_jailhouse
    echo "Removing Drivers"
    rm_drivers
    exit
}

trap handle_ctlc SIGINT


# Call main here to allow for forward declaration (like Python)
# See https://stackoverflow.com/questions/13588457/forward-function-declarations-in-a-bash-or-a-shell-script
main "$@"
