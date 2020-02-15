#!/bin/bash
source ./common.sh > /dev/null

# Point to the input data directory
data_output_dir="$1"

# Allow the input data directory to be a relative path
case $data_output_dir in
    /*) ;;
    *) data_output_dir="$(pwd)/$data_output_dir" ;;
esac

if [[ "$data_output_dir" == "$(pwd)" ]]; then
    echo "No source data dir specified. Exiting..."
    exit
fi

new_output_dir=$(pwd)/tmp_pp_output
rm -rf $new_output_dir
mkdir -p $new_output_dir

input_sizes=()

echo "Input: $data_output_dir"
echo "Output: $new_output_dir"

# Extract parameters from the experiment file!
INMATE_DEBUG=$(grep_token_in_file "INMATE_DEBUG: " $data_output_dir/experiment_*.txt)
INPUT_SIZE_START=$(grep_token_in_file "INPUT_SIZE_START: " $data_output_dir/experiment_*.txt)
INPUT_SIZE_END=$(grep_token_in_file "INPUT_SIZE_END: " $data_output_dir/experiment_*.txt)
INPUT_SIZE_STEP=$(grep_token_in_file "INPUT_SIZE_STEP: " $data_output_dir/experiment_*.txt)
INPUT_FILE=$(grep_token_in_file "INPUT_FILE: " $data_output_dir/experiment_*.txt)
INTERFERENCE_WORKLOAD=$(grep_token_in_file "INTERFERENCE_WORKLOAD_RAW: " $data_output_dir/experiment_*.txt)
JAILHOUSE_OUTPUT_BASENAME=$(grep_token_in_file "JAILHOUSE_OUTPUT_BASENAME: " $data_output_dir/experiment_*.txt)
JAILHOUSE_OUTPUT_FILE="$data_output_dir/$JAILHOUSE_OUTPUT_BASENAME"
LINUX_OUTPUT_BASENAME=$(grep_token_in_file "LINUX_OUTPUT_BASENAME: " $data_output_dir/experiment_*.txt)
LINUX_OUTPUT_FILE="$data_output_dir/$LINUX_OUTPUT_BASENAME"
RUN_MODE=$(grep_token_in_file "RUN_MODE_RAW: " $data_output_dir/experiment_*.txt)
RUN_WITH_VTUNE=$(grep_token_in_file "RUN_WITH_VTUNE: " $data_output_dir/experiment_*.txt)
THROTTLE_MODE=$(grep_token_in_file "THROTTLE_MODE_RAW: " $data_output_dir/experiment_*.txt)
# THROTTLE_MECHANISM=$(grep_token_in_file "THROTTLE_MECHANISM_RAW: " $data_output_dir/experiment_*.txt)
TIMESTAMP=$(grep_token_in_file "TIMESTAMP: " $data_output_dir/experiment_*.txt)
# VTUNE_MODE=$(grep_token_in_file "VTUNE_MODE_RAW: " $data_output_dir/experiment_*.txt)
VTUNE_OUTPUT_BASENAME=$(grep_token_in_file "VTUNE_OUTPUT_BASENAME: " $data_output_dir/experiment_*.txt)
VTUNE_OUTPUT_FILE="$data_output_dir/$VTUNE_OUTPUT_BASENAME"
WORKLOAD_MODE=$(grep_token_in_file "WORKLOAD_MODE_RAW: " $data_output_dir/experiment_*.txt)

post_process_data $new_output_dir $TIMESTAMP
