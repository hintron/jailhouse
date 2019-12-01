#!/bin/bash
cd "${BASH_SOURCE%/*}"

# Note that the inmate libraries assume that the cmdline string will be stored
# at 0x1000 and will have a size of CMDLINE_BUFFER_SIZE.
CMDLINE_OFFSET=0x1000
MiB=$((2 ** 20))
KiB=$((2 ** 10))

JAILHOUSE_BIN=../../tools/jailhouse

# Throttle mode values
TMODE_ALTERNATING=0 # default
TMODE_DEADLINE=1
TMODE_ITERATION=2

# Throttle mechanism values
TMECH_CLOCK=0
TMECH_SPIN=1 # default
TMECH_PAUSE=2 # Not yet implemented

# Workload mode values
WM_SHA3=0
WM_CACHE_ANALYSIS=1
WM_COUNT_SET_BITS=2 # default
WM_RANDOM_ACCESS=3 # default

# Count Set Bits Mode values
CSBM_SLOW=0
CSBM_FASTER=1
CSBM_FASTEST=2 # default

# Interference Workloads
INTF_HANDBRAKE=0
INTF_RANDOM=1


# Parameters:
#   DEBUG_MODE
#   LOCAL_BUFFER
#   THROTTLE_MODE
#   THROTTLE_MECHANISM
#   WORKLOAD_MODE
#   COUNT_SET_BITS_MODE
#   POLLUTE_CACHE
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
        CMDLINE="${CMDLINE} tmode=$THROTTLE_MODE"
    fi
    if [ ! -z $THROTTLE_MECHANISM ]; then
        CMDLINE="${CMDLINE} tmech=$THROTTLE_MECHANISM"
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
    if [ ! -z $THROTTLE_ITERATIONS ]; then
        CMDLINE="${CMDLINE} throttleiter=$THROTTLE_ITERATIONS"
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
    # End any existing console processes
    end_jailhouse_processes
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

# Combine start_root and start_inmate
function start_jailhouse {
    start_root "$1"
    # Clear the sync byte of shared memory to 0
    clear_sync_byte_shmem
    start_inmate "$2" "$3" "$4" "$5"
}

# End the inmate cell at position 1
function show_cells {
    sudo $JAILHOUSE_BIN cell list
}

function build_jailhouse {
    cur_dir=$(pwd)
    cd ../..
    make CC=gcc-7 > /dev/null
    sudo make install CC=gcc-7 > /dev/null
    cd mgh/uio-kernel-module
    make > /dev/null
    sudo make install > /dev/null
    cd "$cur_dir"
}

function clean_jailhouse {
    cur_dir=$(pwd)
    cd ../..
    make clean
    cd mgh/uio-kernel-module
    make clean
    cd "$cur_dir"
}

# End any Jailhouse Linux processes (sudo jailhouse console -f), since anything
# pending on the Jailhouse console will prevent unloading the driver.
function end_jailhouse_processes {
    echo 'sudo killall -e "jailhouse"'
    sudo killall -e "jailhouse"
    # Give it some time to kill stuff
    sleep 1
}

# Try to unload and stop everything
function end_jailhouse {
    # Try ending inmate if running
    end_inmate
    # Try ending root if running
    end_root
}

# Stop everything, rebuild, and reload drivers
function reset_jailhouse_all {
    # Stop root and inmate
    end_jailhouse
    # try removing drivers
    rm_drivers
    build_jailhouse
    load_drivers
}

function create_random_file_max {
    file="$1"
    # Create the maximum-sized input possible
    # Current max size is (40 MB - 8)
    size=$(((2**20 * 40)- 8))
    create_random_file $size $file
}

# 1: Size in bytes
# 2: file name to overwrite
function create_random_file {
    size="$1"
    file="$2"

    if [ -z $file ]; then
        file="__tmp.txt"
    fi

    # echo "head -c $size < /dev/urandom > $file"
    head -c $size < /dev/urandom > $file
}
# See https://unix.stackexchange.com/questions/33629/how-can-i-populate-a-file-with-random-data

# $1: Input file to work on
# $2: (optional) The workload mode. Defaults to Count Set Bits.
function get_expected_output {
    if [ "$2" == $WM_SHA3 ]; then
        sha3_linux_file "$1"
    elif [ "$2" == $WM_RANDOM_ACCESS ]; then
        random_access_linux_file "$1"
    else
        # This is the default
        count_set_bits_linux_file "$1"
    fi
}

# Requires rhash to be installed on the system
# `sudo apt install rhash`
# See mgh/sha3/test.sh
function sha3_linux_file {
    rhash --sha3-512 "$1" | cut -f 1 -d " "
}

function sha3_linux_str {
    printf "$1" | rhash --sha3-512 - | cut -f 1 -d " "
}

function count_set_bits_linux_file {
    ../workloads/build/count-set-bits "$1"
}

function random_access_linux_file {
    ../workloads/build/random-access "$1"
}

function clear_sync_byte_shmem {
    sudo ../uio-userspace/mgh-demo.py -c
}

# Send input to the inmate via file
function send_inmate_input {
    input_file="$1"

    if [ -z $input_file ]; then
        echo "error: no input file"
        return
    fi

    # Send input to inmate
    sudo ../uio-userspace/mgh-demo.py -f $input_file
}

# https://stackoverflow.com/questions/17066250/create-timestamp-variable-in-bash-script
function timestamp {
    date +"%Y-%m-%d_%H-%M-%S"
}

function grep_freq_data {
    in_file="$1"
    out_file="$2"
    grep_token_in_file_to_file "MGHFREQ:" $in_file $out_file
}

function grep_output_data {
    in_file="$1"
    out_file="$2"
    grep_token_in_file_to_file "MGHOUT:" $in_file $out_file
}

# Grep a file for all lines with a token, remove that token from the output,
# remove additional carriage returns (since grep puts a single carriage return
# at the start, then adds carriage returns to all newlines), and store the
# output in a file.
function grep_token_in_file_to_file {
    token="$1"
    in_file="$2"
    out_file="$3"

    grep_token_in_file $token $in_file > $out_file
}

function grep_token_in_file {
    token="$1"
    in_file="$2"

    echo "grep \"$token\" $in_file | sed \"s/${token}//\" | sed \"s/\r//\""
    grep "$token" $in_file | sed "s/${token}//" | sed "s/\r//"
}

function grep_token_in_str {
    token="$1"
    str="$2"

    echo "$str" | grep "$token" | sed "s/${token}//" | sed "s/\r//"
}

function start_handbrake {
    INPUT="$1"
    OUTPUT="$2"

    HandBrakeCLI -i $INPUT -o $OUTPUT
}

function start_handbrake_demo {
    TIMESTAMP=$(timestamp)

    INPUT="/home/hintron/Videos/sources/i_am_legend.m2ts"
    OUTPUT="/home/hintron/Videos/jailhouse_outputs/run_$TIMESTAMP"

    start_handbrake $INPUT $OUTPUT

    # Delete output?
    # Pass video file to sha function?
    # Specify chapters with -c? Doesn't seem to work...
}

function start_random_access_demo {
    echo "TODO: Need to implement start_random_access_demo"
}

function stop_handbrake {
    echo "sudo killall HandBrakeCLI"
    sudo killall HandBrakeCLI
    # NOTE: $! doesn't get the proper PID of HandBrakeCLI, so kill it by name
}

function stop_random_demo {
    echo "TODO: Need to implement stop_random_demo"
    # TODO: Killall on a program name?
}

function start_interference_workload {
    if [ "$1" == $INTF_HANDBRAKE ]; then
        start_handbrake_demo
    elif [ "$1" == $INTF_RANDOM ]; then
        start_random_access_demo
    fi
}

function stop_interference_workload {
    if [ "$1" == $INTF_HANDBRAKE ]; then
        stop_handbrake
    elif [ "$1" == $INTF_RANDOM ]; then
        stop_random_demo
    fi
}
