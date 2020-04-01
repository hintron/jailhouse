#!/bin/bash
source ./common.sh > /dev/null

# Point to the input data directory
input_dir="$1"

# Allow the input data directory to be a relative path
case $input_dir in
    /*) ;;
    *) input_dir="$(pwd)/$input_dir" ;;
esac

if [[ "$input_dir" == "$(pwd)" ]]; then
    echo "No source data dir specified. Exiting..."
    exit
fi

new_output_dir=$(pwd)/tmp_pp_output
rm -rf $new_output_dir
mkdir -p $new_output_dir

input_sizes=()

echo "Input: $input_dir"
echo "Output: $new_output_dir"

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


post_process_data $new_output_dir $TIMESTAMP
