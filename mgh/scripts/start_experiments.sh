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
ITERATIONS=10
# ITERATIONS=20
# ITERATIONS=100
experiment_time="$(timestamp)"
INPUT_FILE="input/input_${experiment_time}.txt"
JAILHOUSE_OUTPUT_FILE="output/jailhouse_${experiment_time}.txt"
EXPERIMENT_OUTPUT_FILE="output/experiment_${experiment_time}.txt"
OUTPUT_DATA_FILE="output/data_${experiment_time}.csv"
OUTPUT_FREQ_FILE="output/freq_${experiment_time}.csv"
INTERFERENCE_WORKLOAD_OUTPUT="output/interference_${experiment_time}.txt"
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
sudo jailhouse console -f >> $JAILHOUSE_OUTPUT_FILE 2>&1 &
tailf_pid=$!

echo "tailf_pid: $tailf_pid" >> $EXPERIMENT_OUTPUT_FILE

################################################################################
# Experiment 1
################################################################################
# Inmate inputs
################################################################################
DEBUG_MODE="true"
# LOCAL_BUFFER="true"
THROTTLE_MODE=$TMODE_ITERATION
# THROTTLE_MECHANISM=$TMECH_CLOCK
# WORKLOAD_MODE=$WM_SHA3
# WORKLOAD_MODE=$WM_RANDOM_ACCESS
# COUNT_SET_BITS_MODE=$CSBM_FASTEST
# POLLUTE_CACHE="true"
THROTTLE_ITERATIONS=$(($ITERATIONS / 2))
# Generate command line arguments based on input
INMATE_CMDLINE=$(set_cmdline) >> $EXPERIMENT_OUTPUT_FILE 2>&1
################################################################################
# Start recording experiment output

# Put process in the background and kill it once done
start_handbrake_demo >> $INTERFERENCE_WORKLOAD_OUTPUT 2>&1 &
# NOTE: $! doesn't get the proper PID of HandBrakeCLI, so just kill it by name

echo "Wait 10 seconds for handbrake (pid=$handbrake_pid) to spin up" >> $EXPERIMENT_OUTPUT_FILE
sleep 10

end_jailhouse >> $EXPERIMENT_OUTPUT_FILE 2>&1
echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
echo "Experiment 1" >> $JAILHOUSE_OUTPUT_FILE
echo "*******************************************************" >> $JAILHOUSE_OUTPUT_FILE
start_jailhouse $ROOT_CELL $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE" >> $EXPERIMENT_OUTPUT_FILE 2>&1

# input_sizes=(1000000 5000000 10000000)
# for input_size in "${input_sizes[@]}"; do
for ((input_size = 1000000 ; input_size < 11000000 ; input_size += 1000000)); do
    echo "Input Size=$input_size" >> $EXPERIMENT_OUTPUT_FILE
    echo "---------------------------------------------------------" >> $EXPERIMENT_OUTPUT_FILE
    # Run X ITERATIONS from 1 to X
    for ((i = 0 ; i < $ITERATIONS ; i++)); do
        echo "Iteration $i: Input Size=$input_size" >> $EXPERIMENT_OUTPUT_FILE
        create_random_file $input_size $INPUT_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1
        send_inmate_input $INPUT_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1
    done
done

echo "sudo killall HandBrakeCLI" >> $EXPERIMENT_OUTPUT_FILE 2>&1
sudo killall HandBrakeCLI >> $EXPERIMENT_OUTPUT_FILE 2>&1


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

# Let's wait for the last iteration to print everything
sleep 5

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

# Let's catch our breath
sleep 1

grep_output_data $JAILHOUSE_OUTPUT_FILE $OUTPUT_DATA_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1
grep_freq_data $JAILHOUSE_OUTPUT_FILE $OUTPUT_FREQ_FILE >> $EXPERIMENT_OUTPUT_FILE 2>&1
