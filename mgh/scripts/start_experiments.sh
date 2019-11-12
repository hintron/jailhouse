#!/bin/bash
source ./common.sh
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
JAILHOUSE_OUTPUT_FILE="output/jailhouse_${experiment_time}.txt"
EXPERIMENT_OUTPUT_FILE="output/experiment_${experiment_time}.txt"
################################################################################
# Experiment-wide setup
################################################################################
touch $JAILHOUSE_OUTPUT_FILE
touch $EXPERIMENT_OUTPUT_FILE
echo "MGH: Experiments" >> $EXPERIMENT_OUTPUT_FILE

reset_jailhouse_all >> $EXPERIMENT_OUTPUT_FILE 2>&1

echo "Start time: $experiment_time" >> $JAILHOUSE_OUTPUT_FILE
echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

# Start recording experiment output
# Put process in the background and kill it once done
sudo jailhouse console -f >> $JAILHOUSE_OUTPUT_FILE &
tailf_pid=$!

echo "tailf_pid: $tailf_pid" >> $EXPERIMENT_OUTPUT_FILE

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
INMATE_CMDLINE=$(set_cmdline) >> $EXPERIMENT_OUTPUT_FILE 2>&1
################################################################################

end_jailhouse >> $EXPERIMENT_OUTPUT_FILE 2>&1
echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
echo "Experiment 1" >> $JAILHOUSE_OUTPUT_FILE
echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
start_jailhouse $ROOT_CELL $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE" >> $EXPERIMENT_OUTPUT_FILE 2>&1

# Run X ITERATIONS from 1 to X
for ((i = 0 ; i < $ITERATIONS ; i++)); do
    echo "Iteration $i" >> $EXPERIMENT_OUTPUT_FILE
    create_random_file_max $INPUT_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1
    send_inmate_input $INPUT_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1
done

# ################################################################################
# ################################################################################
# # Experiment 2
# ################################################################################
#
# TODO
#
# ################################################################################
# Final Cleanup
# ################################################################################

# Flush any buffers
echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
echo "End Experiments" >> $JAILHOUSE_OUTPUT_FILE
echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE

# The input is just random data, so really no sense in keeping it around rn
echo "sudo rm $INPUT_FILE" >> $EXPERIMENT_OUTPUT_FILE
sudo rm $INPUT_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1

echo "sudo kill $tailf_pid" >> $EXPERIMENT_OUTPUT_FILE
sudo kill $tailf_pid >> $EXPERIMENT_OUTPUT_FILE 2>&1
# end_jailhouse_processes >> $EXPERIMENT_OUTPUT_FILE 2>&1

end_inmate >> $EXPERIMENT_OUTPUT_FILE 2>&1
end_root >> $EXPERIMENT_OUTPUT_FILE 2>&1
