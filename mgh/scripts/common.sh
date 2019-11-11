#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# Note that the inmate libraries assume that the cmdline string will be stored
# at 0x1000 and will have a size of CMDLINE_BUFFER_SIZE.
CMDLINE_OFFSET=0x1000

JAILHOUSE_BIN=../../tools/jailhouse

# Throttle mode values
TM_ALTERNATING=0 # default
TM_DEADLINE=1

# Workload mode values
WM_SHA3=0
WM_CACHE_ANALYSIS=1
WM_COUNT_SET_BITS=2 # default

# Count Set Bits Mode values
CSBM_SLOW=0
CSBM_FASTER=1
CSBM_FASTEST=2 # default

# Inputs are through globals with the following names and values:
# DEBUG_MODE=["true", "false"]
# LOCAL_BUFFER=["true", "false"]
# THROTTLE_MODE=[TM_ALTERNATING=0,TM_DEADLINE=1]
# WORKLOAD_MODE=[WM_SHA3=0,WM_CACHE_ANALYSIS=1,WM_COUNT_SET_BITS=2]
# COUNT_SET_BITS_MODE=[CSBM_SLOW=0,CSBM_FASTER=1,CSBM_FASTEST=2]
# POLLUTE_CACHE=["true", "false"]
function set_cmdline {
    local CMDLINE=""
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
    echo $CMDLINE
    # Do `CMDLINE=$(set_cmdline)` to capture the output of this function
}
