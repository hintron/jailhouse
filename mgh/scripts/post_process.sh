#!/bin/bash
source ./common.sh > /dev/null

# Point to the input data directory
input_dir="$1"
output_dir="$2"

# Allow the input data directory to be a relative path
case $input_dir in
    /*) ;;
    *) input_dir="$(pwd)/$input_dir" ;;
esac

if [[ "$input_dir" == "$(pwd)" ]]; then
    echo "No source data dir specified. Exiting..."
    exit
fi

if [ -z "$output_dir" ]; then
    echo "Using ./tmp_pp_output/ as output dir"
    output_dir=$(pwd)/tmp_pp_output
    rm -rf $output_dir
    mkdir -p $output_dir
else
    echo "Using input dir as output dir"
    output_dir=$input_dir
fi

input_sizes=()

echo "Input: $input_dir"
echo "Output: $output_dir"

# Extract parameters from the experiment file!
INMATE_DEBUG=$(grep_token_in_file "INMATE_DEBUG: " $input_dir/experiment_*.txt)
INPUT_SIZE_START=$(grep_token_in_file "INPUT_SIZE_START: " $input_dir/experiment_*.txt)
INPUT_SIZE_END=$(grep_token_in_file "INPUT_SIZE_END: " $input_dir/experiment_*.txt)
INPUT_SIZE_STEP=$(grep_token_in_file "INPUT_SIZE_STEP: " $input_dir/experiment_*.txt)
INPUT_FILE=$(grep_token_in_file "INPUT_FILE: " $input_dir/experiment_*.txt)
INTERFERENCE_WORKLOAD=$(grep_token_in_file "INTERFERENCE_WORKLOAD_RAW: " $input_dir/experiment_*.txt)
JAILHOUSE_OUTPUT_BASENAME=$(grep_token_in_file "JAILHOUSE_OUTPUT_BASENAME: " $input_dir/experiment_*.txt)
JAILHOUSE_OUTPUT_FILE="$input_dir/$JAILHOUSE_OUTPUT_BASENAME"
LINUX_OUTPUT_BASENAME=$(grep_token_in_file "LINUX_OUTPUT_BASENAME: " $input_dir/experiment_*.txt)
LINUX_OUTPUT_FILE="$input_dir/$LINUX_OUTPUT_BASENAME"
RUN_MODE=$(grep_token_in_file "RUN_MODE_RAW: " $input_dir/experiment_*.txt)
RUN_WITH_VTUNE=$(grep_token_in_file "RUN_WITH_VTUNE: " $input_dir/experiment_*.txt)
THROTTLE_MODE=$(grep_token_in_file "THROTTLE_MODE_RAW: " $input_dir/experiment_*.txt)
# THROTTLE_MECHANISM=$(grep_token_in_file "THROTTLE_MECHANISM_RAW: " $input_dir/experiment_*.txt)
TIMESTAMP=$(grep_token_in_file "TIMESTAMP: " $input_dir/experiment_*.txt)
# VTUNE_MODE=$(grep_token_in_file "VTUNE_MODE_RAW: " $input_dir/experiment_*.txt)
VTUNE_OUTPUT_BASENAME=$(grep_token_in_file "VTUNE_OUTPUT_BASENAME: " $input_dir/experiment_*.txt)
VTUNE_OUTPUT_FILE="$input_dir/$VTUNE_OUTPUT_BASENAME"
WORKLOAD_MODE=$(grep_token_in_file "WORKLOAD_MODE_RAW: " $input_dir/experiment_*.txt)
LOCAL_INPUT_MODE=$(grep_token_in_file "LOCAL_INPUT_MODE_RAW: " $input_dir/experiment_*.txt)

# Temporary hack for backwards compatibility
if [ "$LOCAL_INPUT_MODE" == "" ]; then
    LOCAL_INPUT_MODE=$(grep_token_in_file "LOCAL_INPUT_MODE: " $input_dir/experiment_*.txt)
    case "$LOCAL_INPUT_MODE" in
    "NONE")
        LOCAL_INPUT_MODE=$LI_NONE
        ;;
    "RANDOM")
        LOCAL_INPUT_MODE=$LI_RANDOM
        ;;
    "UNIFORM")
        LOCAL_INPUT_MODE=$LI_UNIFORM
        ;;
    *)
        echo "ERROR: Unknown local input mode '$LOCAL_INPUT_MODE'. Assuming LI_NONE"
        LOCAL_INPUT_MODE=$LI_NONE
        ;;
    esac
fi

if [ -f "$input_dir/$TIMESTAMP.input" ]; then
    INPUT_FILE=$input_dir/$TIMESTAMP.input
fi

post_process_data $output_dir $TIMESTAMP
