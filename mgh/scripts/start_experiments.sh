#!/bin/bash
source ./common.sh
echo "MGH: Experiments"
################################################################################
# Set Jailhouse inputs here
################################################################################
ROOT_CELL=../../configs/x86/bazooka-root.cell
INMATE_CELL=../../configs/x86/bazooka-inmate.cell
INMATE_NAME=bazooka-inmate
INMATE_PROGRAM=../../inmates/demos/x86/mgh-demo.bin
################################################################################
# Experiment-wide inputs here
################################################################################
ITERATIONS=20
# ITERATIONS=100
# TODO: Get a timestamp?
experiment_time="$(timestamp)"
INPUT_FILE="input/input_${experiment_time}.txt"
OUTPUT_FILE="output/output_${experiment_time}.txt"
################################################################################
# Experiment-wide setup
################################################################################
reset_jailhouse_all

touch $OUTPUT_FILE
echo "Start time: $experiment_time" >> $OUTPUT_FILE
echo "*******************************************************" >> $OUTPUT_FILE

# Start recording experiment output
# Put process in the background and kill it once done
sudo jailhouse console -f >> $OUTPUT_FILE &
tailf_pid=$!

echo "tailf_pid: $tailf_pid"

################################################################################
# Experiment 1
################################################################################
# Inmate inputs
################################################################################
# DEBUG_MODE="true"
# LOCAL_BUFFER="true"
# THROTTLE_MODE=$TM_DEADLINE
# WORKLOAD_MODE=$WM_COUNT_SET_BITS
# COUNT_SET_BITS_MODE=$CSBM_FASTEST
# POLLUTE_CACHE="true"
# Generate command line arguments based on input
INMATE_CMDLINE=$(set_cmdline)
################################################################################

end_jailhouse
echo "*******************************************************" >> $OUTPUT_FILE
echo "Experiment 1" >> $OUTPUT_FILE
echo "*******************************************************" >> $OUTPUT_FILE
start_jailhouse $ROOT_CELL $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE"

# Run X ITERATIONS from 1 to X
for ((i = 0 ; i < $ITERATIONS ; i++)); do
    echo "Iteration $i"
    create_random_file_max $INPUT_FILE
    send_inmate_input $INPUT_FILE
done


echo "sudo kill $tailf_pid"
sudo kill $tailf_pid




# ################################################################################
# ################################################################################
# # Experiment 2
# ################################################################################
# # Inmate inputs
# ################################################################################
# DEBUG_MODE="true"
# LOCAL_BUFFER="true"
# THROTTLE_MODE=$TM_DEADLINE
# WORKLOAD_MODE=$WM_COUNT_SET_BITS
# COUNT_SET_BITS_MODE=$CSBM_FASTEST
# POLLUTE_CACHE="true"
# # Generate command line arguments based on input
# INMATE_CMDLINE=$(set_cmdline)
# ################################################################################

# reset_jailhouse
# start_jailhouse $ROOT_CELL $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM $INMATE_CMDLINE




# ################################################################################
# Final Cleanup
# ################################################################################

# Flush any buffers
echo "*******************************************************" >> $OUTPUT_FILE
echo "End Experiments" >> $OUTPUT_FILE
echo "*******************************************************" >> $OUTPUT_FILE

# echo "sudo rm $INPUT_FILE"
# sudo rm $INPUT_FILE

end_jailhouse_processes


end_inmate
end_root
