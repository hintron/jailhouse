#!/bin/bash
source ./common.sh
################################################################################
# Script-wide inputs here
################################################################################
ROOT_CELL=../../configs/x86/bazooka-root.cell
INMATE_CELL=../../configs/x86/bazooka-inmate.cell
INMATE_NAME=bazooka-inmate
INMATE_PROGRAM=../../inmates/demos/x86/mgh-demo.bin
ITERATIONS=10
# ITERATIONS=2
THROTTLE_ITERATIONS=$(($ITERATIONS / 2))
INPUT_SIZE_START=$MiB
INPUT_SIZE_END=$((40*$INPUT_SIZE_START))
# INPUT_SIZE_END=$((2*$INPUT_SIZE_START))
INPUT_SIZE_STEP=$((1*$INPUT_SIZE_START))
# We have up to 40 MiB, which is 41.9E6 bytes
experiment_time="$(timestamp)"
INPUT_FILE_BASE="input/input_${experiment_time}"
JAILHOUSE_OUTPUT_FILE="output/jailhouse_${experiment_time}.txt"
EXPERIMENT_OUTPUT_FILE="output/experiment_${experiment_time}.txt"
OUTPUT_DATA_FILE="output/data_${experiment_time}.csv"
OUTPUT_FREQ_FILE="output/freq_${experiment_time}.csv"
INTERFERENCE_WORKLOAD_OUTPUT="output/interference_${experiment_time}.txt"
# TODO: Make this experiment-dependent later
INTERFERENCE_WORKLOAD=$INTF_HANDBRAKE
# INTERFERENCE_WORKLOAD=$INTF_RANDOM

function main {
    ################################################################################
    # Script-wide setup
    ################################################################################
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

    # Pre-generate all input sizes beforehand

    input_sizes=()
    for ((input_size = $INPUT_SIZE_START; input_size < $INPUT_SIZE_END; input_size += $INPUT_SIZE_STEP)); do
        input_sizes+=($input_size)
    done
    input_sizes_count=${#input_sizes[@]}

    experiment_counter=1

    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Experiment $experiment_counter" >> $EXPERIMENT_OUTPUT_FILE
    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE
    ################################################################################
    # Inmate inputs
    ################################################################################
    # DEBUG_MODE="true"
    # LOCAL_BUFFER="true"
    THROTTLE_MODE=$TMODE_ITERATION
    # THROTTLE_MECHANISM=$TMECH_CLOCK
    # WORKLOAD_MODE=$WM_COUNT_SET_BITS
    # COUNT_SET_BITS_MODE=$CSBM_FASTEST
    # POLLUTE_CACHE="true"
    # Generate command line arguments based on input above
    INMATE_CMDLINE=$(set_cmdline) >> $EXPERIMENT_OUTPUT_FILE 2>&1
    ################################################################################
    start_experiment $experiment_counter
    experiment_counter=$(($experiment_counter + 1))

    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Experiment $experiment_counter" >> $EXPERIMENT_OUTPUT_FILE
    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE
    ################################################################################
    # Inmate inputs
    ##################################################################################
    WORKLOAD_MODE=$WM_RANDOM_ACCESS
    INMATE_CMDLINE=$(set_cmdline) >> $EXPERIMENT_OUTPUT_FILE 2>&1
    ##################################################################################
    start_experiment $experiment_counter
    experiment_counter=$(($experiment_counter + 1))


    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Experiment $experiment_counter" >> $EXPERIMENT_OUTPUT_FILE
    echo "################################################################################" >> $EXPERIMENT_OUTPUT_FILE
    ################################################################################
    # Inmate inputs
    ##################################################################################
    WORKLOAD_MODE=$WM_SHA3
    INMATE_CMDLINE=$(set_cmdline) >> $EXPERIMENT_OUTPUT_FILE 2>&1
    ##################################################################################
    start_experiment $experiment_counter
    experiment_counter=$(($experiment_counter + 1))

    # ################################################################################
    # Final Cleanup
    # ################################################################################

    # Let's wait for the last iteration to print everything
    sleep 5

    # Flush any buffers
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
    echo "End Experiments" >> $JAILHOUSE_OUTPUT_FILE
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

    echo "sudo kill $tailf_pid" >> $EXPERIMENT_OUTPUT_FILE
    sudo kill $tailf_pid >> $EXPERIMENT_OUTPUT_FILE 2>&1
    # end_jailhouse_processes >> $EXPERIMENT_OUTPUT_FILE 2>&1

    end_inmate >> $EXPERIMENT_OUTPUT_FILE 2>&1
    end_root >> $EXPERIMENT_OUTPUT_FILE 2>&1

    # Let's catch our breath
    sleep 1

    grep_output_data $JAILHOUSE_OUTPUT_FILE $OUTPUT_DATA_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1
    # TODO: Enable once I am convinced it's accurate and useful
    # grep_freq_data $JAILHOUSE_OUTPUT_FILE $OUTPUT_FREQ_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1
}

# The only param passed in is the experiment number. All other inputs are
# globals
function start_experiment {
    experiment_count="$1"

    # Start recording experiment output
    end_jailhouse >> $EXPERIMENT_OUTPUT_FILE 2>&1

    echo "Wait for handbrake to ramp up" >> $EXPERIMENT_OUTPUT_FILE
    start_interference_workload $INTERFERENCE_WORKLOAD >> $INTERFERENCE_WORKLOAD_OUTPUT 2>&1 &

    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
    echo "Experiment $experiment_count" >> $JAILHOUSE_OUTPUT_FILE
    echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

    start_jailhouse $ROOT_CELL $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE" >> $EXPERIMENT_OUTPUT_FILE 2>&1

    # This will in effect be a 2d array of input files with pregenerated random data
    random_inputs=()
    expected_outputs=()
    for ((i = 0 ; i < $input_sizes_count ; i++)); do
        for ((j = 0 ; j < $ITERATIONS ; j++)); do
            # flatten 2d (i,j) index into a single flat index
            index=$(($i * $ITERATIONS + $j))
            input_file="${INPUT_FILE_BASE}_${index}.bin"
            # echo "$input_file" >> $EXPERIMENT_OUTPUT_FILE 2>&1
            create_random_file ${input_sizes[$i]} $input_file >> $EXPERIMENT_OUTPUT_FILE 2>&1
            random_inputs+=($input_file)
            # Calculate and capture expected outputs to compare with inmate outputs
            # later
            expected_output=$(get_expected_output $input_file $WORKLOAD_MODE)
            # echo "expected_output $index: $expected_output" >> $EXPERIMENT_OUTPUT_FILE 2>&1
            expected_outputs+=($expected_output)
        done
    done

    for ((i = 0 ; i < $input_sizes_count ; i++)); do
        input_size=${input_sizes[$i]}
        echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE
        echo "Input Size=$input_size" >> $EXPERIMENT_OUTPUT_FILE
        echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE
        for ((j = 0 ; j < $ITERATIONS ; j++)); do
            # flatten 2d (i,j) index into a single flat index
            index=$(($i * $ITERATIONS + $j))
            if [ "$j" != "0" ]; then
                echo "---------------------------------------------------------" >> $EXPERIMENT_OUTPUT_FILE
            fi
            echo "Iteration $j ($index):" >> $EXPERIMENT_OUTPUT_FILE

            input_file=${random_inputs[$index]}
            inmate_output=$(send_inmate_input $input_file)
            echo "$inmate_output" >> $EXPERIMENT_OUTPUT_FILE 2>&1
            inmate_output_value=$(grep_token_in_str "Inmate output: " "$inmate_output")
            expected_output_value="${expected_outputs[$index]}"

            # Validate inmate output against pre-calculated values
            if [ "$inmate_output_value" != "$expected_output_value" ]; then
                echo "Error: inmate output != expected!" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                echo "    inmate_output_value  : $inmate_output_value" >> $EXPERIMENT_OUTPUT_FILE 2>&1
                echo "    expected_output_value: $expected_output_value" >> $EXPERIMENT_OUTPUT_FILE 2>&1
            else
                echo "Inmate output matches expected output" >> $EXPERIMENT_OUTPUT_FILE 2>&1
            fi
        done
    done
    echo "*********************************************************" >> $EXPERIMENT_OUTPUT_FILE

    stop_interference_workload $INTERFERENCE_WORKLOAD >> $EXPERIMENT_OUTPUT_FILE 2>&1

    for input_file in ${random_inputs[@]}; do
        # The input is just random data, so really no sense in keeping it around rn
        echo "sudo rm $input_file" >> $EXPERIMENT_OUTPUT_FILE
        sudo rm $input_file >> $EXPERIMENT_OUTPUT_FILE 2>&1
    done
}

# Call main here to allow for forward declaration (like Python)
# See https://stackoverflow.com/questions/13588457/forward-function-declarations-in-a-bash-or-a-shell-script
main "$@"
