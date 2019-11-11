#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
echo "MGH: Starting Bazooka inmate"

source ./common.sh

################################################################################
# Set inputs here. To use defaults, comment out and leave unset.
# See common.sh --> set_cmdline
################################################################################
DEBUG_MODE="true"
LOCAL_BUFFER="true"
THROTTLE_MODE=$TM_ALTERNATING
WORKLOAD_MODE=$WM_COUNT_SET_BITS
COUNT_SET_BITS_MODE=$CSBM_FASTEST
POLLUTE_CACHE="true"
# Generate command line arguments based on input
CMDLINE=$(set_cmdline)
################################################################################
INMATE_NAME=bazooka-inmate
INMATE_CELL=../../configs/x86/bazooka-inmate.cell
INMATE_PROGRAM=../../inmates/demos/x86/mgh-demo.bin
################################################################################

# Start the inmate with the following three commands
echo "sudo $JAILHOUSE_BIN cell create $INMATE_CELL"
sudo $JAILHOUSE_BIN cell create $INMATE_CELL

if [ "$CMDLINE" != "" ]; then
    echo "sudo $JAILHOUSE_BIN cell load $INMATE_NAME $INMATE_PROGRAM -s \"$CMDLINE\" -a $CMDLINE_OFFSET"
    sudo $JAILHOUSE_BIN cell load $INMATE_NAME $INMATE_PROGRAM -s "$CMDLINE" -a $CMDLINE_OFFSET
else
    echo "sudo $JAILHOUSE_BIN cell load $INMATE_NAME $INMATE_PROGRAM"
    sudo $JAILHOUSE_BIN cell load $INMATE_NAME $INMATE_PROGRAM
fi
echo "sudo $JAILHOUSE_BIN cell start $INMATE_NAME"
sudo $JAILHOUSE_BIN cell start $INMATE_NAME
