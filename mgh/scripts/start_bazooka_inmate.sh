#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
echo "MGH: Starting Bazooka inmate"
# Note that the inmate libraries assume that the cmdline string will be stored
# at 0x1000 and will have a size of CMDLINE_BUFFER_SIZE.
CMDLINE_OFFSET=0x1000

JAILHOUSE_BIN=../../tools/jailhouse

# Throttle mode values
ALTERNATING=0 # default
DEADLINE=1

# Workload mode values
SHA3=0
CACHE_ANALYSIS=1
COUNT_SET_BITS=2 # default

# Count Set Bits Mode values
SLOW=0
FASTER=1
FASTEST=2 # default

################################################################################
# Set inputs here. To use defaults, comment out and leave unset.
################################################################################
# DEBUG_MODE="true"
# LOCAL_BUFFER="true"
# THROTTLE_MODE=$ALTERNATING
# WORKLOAD_MODE=$COUNT_SET_BITS
# COUNT_SET_BITS_MODE=$FASTEST
# POLLUTE_CACHE="true"
################################################################################
INMATE_NAME=bazooka-inmate
INMATE_CELL=../../configs/x86/bazooka-inmate.cell
INMATE_PROGRAM=../../inmates/demos/x86/mgh-demo.bin
################################################################################

CMDLINE=""
if [ -v DEBUG_MODE ]; then
    CMDLINE="${CMDLINE} debug=$DEBUG_MODE"
fi
if [ -v LOCAL_BUFFER ]; then
    CMDLINE="${CMDLINE} lb=$LOCAL_BUFFER"
fi
if [ -v THROTTLE_MODE ]; then
    CMDLINE="${CMDLINE} tm=$THROTTLE_MODE"
fi
if [ -v WORKLOAD_MODE ]; then
    CMDLINE="${CMDLINE} wm=$WORKLOAD_MODE"
fi
if [ -v COUNT_SET_BITS_MODE ]; then
    CMDLINE="${CMDLINE} csbm=$COUNT_SET_BITS_MODE"
fi
if [ -v POLLUTE_CACHE ]; then
    CMDLINE="${CMDLINE} pc=$POLLUTE_CACHE"
fi

# Remove leading whitespace
# https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
CMDLINE="$(echo -e "${CMDLINE}" | sed -e 's/^[[:space:]]*//')"

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