#!/bin/bash
cd "${BASH_SOURCE%/*}"

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

# Parameters:
#   DEBUG_MODE=["true", "false"]
#   LOCAL_BUFFER=["true", "false"]
#   THROTTLE_MODE=[TM_ALTERNATING=0,TM_DEADLINE=1]
#   WORKLOAD_MODE=[WM_SHA3=0,WM_CACHE_ANALYSIS=1,WM_COUNT_SET_BITS=2]
#   COUNT_SET_BITS_MODE=[CSBM_SLOW=0,CSBM_FASTER=1,CSBM_FASTEST=2]
#   POLLUTE_CACHE=["true", "false"]
#
# Do `CMDLINE=$(set_cmdline)` to capture the output of this function
# Make sure to use " " later whenever using $CMDLINE, or else only first item
# will be used.
function set_cmdline {
    local CMDLINE=""
    if [ ! -z $DEBUG_MODE ]; then
        CMDLINE="${CMDLINE} debug=$DEBUG_MODE"
    fi
    if [ ! -z $LOCAL_BUFFER ]; then
        CMDLINE="${CMDLINE} lb=$LOCAL_BUFFER"
    fi
    if [ ! -z $THROTTLE_MODE ]; then
        CMDLINE="${CMDLINE} tm=$THROTTLE_MODE"
    fi
    if [ ! -z $WORKLOAD_MODE ]; then
        CMDLINE="${CMDLINE} wm=$WORKLOAD_MODE"
    fi
    if [ ! -z $COUNT_SET_BITS_MODE ]; then
        CMDLINE="${CMDLINE} csbm=$COUNT_SET_BITS_MODE"
    fi
    if [ ! -z $POLLUTE_CACHE ]; then
        CMDLINE="${CMDLINE} pc=$POLLUTE_CACHE"
    fi

    # Remove leading whitespace
    # https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
    CMDLINE="$(echo -e "${CMDLINE}" | sed -e 's/^[[:space:]]*//')"
    echo $CMDLINE
}

# End the inmate cell at position 1
function sign_drivers {
    # See https://askubuntu.com/questions/760671/could-not-load-vboxdrv-after-upgrade-to-ubuntu-16-04-and-i-want-to-keep-secur/768310#768310

    # cd  ~/code/jailhouse/mgh/scripts
    # openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -nodes -days 36500 -subj "/CN=MGH Custom Driver Key (for Jailhouse)/"

    # Before signing these drivers, the keys need to be accepted by mokutil

    sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./MOK.priv ./MOK.der ../../driver/jailhouse.ko
    modinfo ../../driver/jailhouse.ko
    sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./MOK.priv ./MOK.der ../uio-kernel-module/uio_ivshmem.ko
    modinfo ../uio-kernel-module/uio_ivshmem.ko
}

function load_uio_driver {
    sudo modprobe uio
    sudo insmod ../uio-kernel-module/uio_ivshmem.ko
    lsmod | grep -i uio
}

function load_jailhouse_driver {
    sudo insmod ../../driver/jailhouse.ko
    lsmod | grep -i jail
}

function load_drivers {
    load_uio_driver
    load_jailhouse_driver
}

function rm_jailhouse_driver {
    sudo rmmod jailhouse.ko
}

function rm_uio_driver {
    sudo rmmod uio_ivshmem.ko
}

function rm_drivers {
    rm_jailhouse_driver
    rm_uio_driver
}

function start_root {
    echo "sudo $JAILHOUSE_BIN enable $1"
    sudo $JAILHOUSE_BIN enable "$1"
}

# Parameters:
#   INMATE_CELL
#   INMATE_NAME
#   INMATE_PROGRAM
#   INMATE_CMDLINE
#
# Invocation:
#   start_inmate $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE"
#
# Make sure $CMDLINE is in quotes, or else only the first space-delimited item
# will make it through.
function start_inmate {
    INMATE_CELL="$1"
    INMATE_NAME="$2"
    INMATE_PROGRAM="$3"
    INMATE_CMDLINE="$4"
    # Start the inmate with the following three commands
    echo "sudo $JAILHOUSE_BIN cell create $INMATE_CELL"
    sudo $JAILHOUSE_BIN cell create $INMATE_CELL

    if [ ! -z "$INMATE_CMDLINE" ] && [ "$INMATE_CMDLINE" != "" ]; then
        echo "sudo $JAILHOUSE_BIN cell load $INMATE_NAME $INMATE_PROGRAM -s \"$INMATE_CMDLINE\" -a $CMDLINE_OFFSET"
        sudo $JAILHOUSE_BIN cell load $INMATE_NAME $INMATE_PROGRAM -s "$INMATE_CMDLINE" -a $CMDLINE_OFFSET
    else
        echo "sudo $JAILHOUSE_BIN cell load $INMATE_NAME $INMATE_PROGRAM"
        sudo $JAILHOUSE_BIN cell load $INMATE_NAME $INMATE_PROGRAM
    fi
    echo "sudo $JAILHOUSE_BIN cell start $INMATE_NAME"
    sudo $JAILHOUSE_BIN cell start $INMATE_NAME
}

# End the inmate cell at position 1
function end_inmate {
    # Get string "Name RootCell InmateCellName"
    local tmp=$(sudo $JAILHOUSE_BIN cell list | awk '{print $2}')
    # Convert to array
    tmp2=($tmp)
    # Get InmateCellName
    inmate=${tmp2[2]}
    if [ ! -z $inmate ]; then
        echo "sudo $JAILHOUSE_BIN cell destroy $inmate"
        sudo $JAILHOUSE_BIN cell destroy $inmate
    else
        echo "No inmate was running"
    fi
}

function end_root {
    sudo $JAILHOUSE_BIN disable
}

# End the inmate cell at position 1
function show_cells {
    sudo $JAILHOUSE_BIN cell list
}