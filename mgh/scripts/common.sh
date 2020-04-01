#!/bin/bash
if [ -d "${BASH_SOURCE%/*}" ]; then
    # echo "cd ${BASH_SOURCE%/*}"
    cd "${BASH_SOURCE%/*}"
fi

# jailhouse/mgh/scripts/
SCRIPTS_DIR=$(pwd)
pushd .. > /dev/null
MGH_DIR=$(pwd)
pushd .. > /dev/null
JAILHOUSE_DIR=$(pwd)
popd > /dev/null
popd > /dev/null

JAILHOUSE_BIN=$JAILHOUSE_DIR/tools/jailhouse
MGH_DEMO_PY="$MGH_DIR/uio-userspace/mgh-demo.py"
WORKLOAD_DIR="$MGH_DIR/workloads"
WORKLOAD_BIN_DIR="$WORKLOAD_DIR/build"
SHA3_BIN="$WORKLOAD_BIN_DIR/sha3-512"
CSB_BIN="$WORKLOAD_BIN_DIR/count-set-bits"
RA_BIN="$WORKLOAD_BIN_DIR/random-access"
PRNG_BIN="$WORKLOAD_BIN_DIR/prng"

# Note that the inmate libraries assume that the cmdline string will be stored
# at 0x1000 and will have a size of CMDLINE_BUFFER_SIZE.
CMDLINE_OFFSET=0x1000
GiB=$((2 ** 30))
MiB=$((2 ** 20))
KiB=$((2 ** 10))

# Throttle mode values
TMODE_ALTERNATING=0 # default
TMODE_DEADLINE=1
TMODE_ITERATION=2
TMODE_DISABLED=3

# Throttle mechanism values
TMECH_CLOCK=0
TMECH_SPIN=1 # default

# Workload mode values
WM_SHA3=0
WM_CACHE_ANALYSIS=1
WM_COUNT_SET_BITS=2 # default
WM_RANDOM_ACCESS=3
WM_INMATE_DEBUG=4

# Count Set Bits Mode values
CSBM_SLOW=0
CSBM_FASTER=1
CSBM_FASTEST=2 # default

# Interference Workloads
INTF_NONE="none"
INTF_HANDBRAKE="handbrake"
INTF_RA="random-access"
INTF_CSB="count-set-bits"
INTF_SHA3="sha-3"

# VTune Analysis Modes
VTUNE_MODE_MA=0 # Memory Access
VTUNE_MODE_UE=1 # Microarchitectural Exploration

# run modes
RM_INMATE=0 # Do not run workloads in Linux
RM_LINUX=1 # Run in Linux, but NOT in the root cell in Jailhouse
RM_LINUX_JAILHOUSE=2 # Run in Linux under root cell in Jailhouse

CELL_ROOT=0
CELL_INMATE_1=1

# This needs to already be on the path
VTUNE_BIN=amplxe-cl

NO_TURBO_INTERFACE=/sys/devices/system/cpu/intel_pstate/no_turbo
DEBUG_MODE="true"

# local input is currently hardwired to 20 MiB
LOCAL_INPUT_SIZE="20971520"

# Local Input modes
LI_NONE=0 # No local input
LI_RANDOM=1 # Generate a local input file with random data
LI_UNIFORM=2 # Generate a local input file of all Xs

function log_parameters {
    echo "#####################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Common Parameters #" >> $EXPERIMENT_OUTPUT_FILE
    echo "#####################" >> $EXPERIMENT_OUTPUT_FILE
    echo "TIMESTAMP: $experiment_time" >> $EXPERIMENT_OUTPUT_FILE
    echo "Jailhouse Git commit: $COMMIT" >> $EXPERIMENT_OUTPUT_FILE
    echo "JAILHOUSE_OUTPUT_BASENAME: $JAILHOUSE_OUTPUT_BASENAME" >> $EXPERIMENT_OUTPUT_FILE
    echo "JAILHOUSE_OUTPUT_FILE: $JAILHOUSE_OUTPUT_FILE" >> $EXPERIMENT_OUTPUT_FILE
    printf "RUN_MODE: " >> $EXPERIMENT_OUTPUT_FILE
    case "$RUN_MODE" in
    "$RM_INMATE")
        echo "RM_INMATE" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$RM_LINUX")
        echo "RM_LINUX" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$RM_LINUX_JAILHOUSE")
        echo "RM_LINUX_JAILHOUSE" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    ""|"Unspecified")
        echo "Unspecified" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    *)
        echo "Unknown" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    esac
    echo "RUN_MODE_RAW: $RUN_MODE" >> $EXPERIMENT_OUTPUT_FILE

    echo "DISABLE_TURBO_BOOST: $DISABLE_TURBO_BOOST" >> $EXPERIMENT_OUTPUT_FILE
    echo "DEBUG_MODE: $DEBUG_MODE" >> $EXPERIMENT_OUTPUT_FILE
    echo "INMATE_DEBUG: $INMATE_DEBUG" >> $EXPERIMENT_OUTPUT_FILE
    if [ "$INPUT_FILE" == "" ]; then
        echo "INPUT_SIZE_START: $INPUT_SIZE_START" >> $EXPERIMENT_OUTPUT_FILE
        echo "INPUT_SIZE_END: $INPUT_SIZE_END" >> $EXPERIMENT_OUTPUT_FILE
        echo "INPUT_SIZE_STEP: $INPUT_SIZE_STEP" >> $EXPERIMENT_OUTPUT_FILE
    else
        echo "INPUT_FILE: $INPUT_FILE" >> $EXPERIMENT_OUTPUT_FILE
        if [ "$LOCAL_INPUT_MODE" == "$LI_NONE" ]; then
            echo "INPUT_FILE size: $(get_size_of_file_bytes $INPUT_FILE) Bytes" >> $EXPERIMENT_OUTPUT_FILE
        fi
    fi
    echo "LOCAL_INPUT_MODE_RAW: $LOCAL_INPUT_MODE"
    echo "ITERATIONS: $ITERATIONS" >> $EXPERIMENT_OUTPUT_FILE

    printf "WORKLOAD_MODE: " >> $EXPERIMENT_OUTPUT_FILE
    case "$WORKLOAD_MODE" in
    "$WM_SHA3")
        echo "WM_SHA3" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$WM_CACHE_ANALYSIS")
        echo "WM_CACHE_ANALYSIS" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$WM_COUNT_SET_BITS")
        echo "WM_COUNT_SET_BITS" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$WM_RANDOM_ACCESS")
        echo "WM_RANDOM_ACCESS" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$WM_INMATE_DEBUG")
        echo "WM_INMATE_DEBUG" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    ""|"Unspecified")
        echo "Unspecified" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    *)
        echo "Unknown" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    esac
    echo "WORKLOAD_MODE_RAW: $WORKLOAD_MODE" >> $EXPERIMENT_OUTPUT_FILE
    echo "INTERFERENCE_WORKLOAD: $INTERFERENCE_WORKLOAD" >> $EXPERIMENT_OUTPUT_FILE

    echo "#########################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Linux-only Parameters #" >> $EXPERIMENT_OUTPUT_FILE
    echo "#########################" >> $EXPERIMENT_OUTPUT_FILE
    echo "RUN_WITH_VTUNE: $RUN_WITH_VTUNE" >> $EXPERIMENT_OUTPUT_FILE
    echo "VTUNE_OUTPUT_BASENAME: $VTUNE_OUTPUT_BASENAME" >> $EXPERIMENT_OUTPUT_FILE
    echo "VTUNE_OUTPUT_FILE: $VTUNE_OUTPUT_FILE" >> $EXPERIMENT_OUTPUT_FILE
    echo "LINUX_OUTPUT_BASENAME: $LINUX_OUTPUT_BASENAME" >> $EXPERIMENT_OUTPUT_FILE
    echo "LINUX_OUTPUT_FILE: $LINUX_OUTPUT_FILE" >> $EXPERIMENT_OUTPUT_FILE
    printf "VTUNE_MODE: " >> $EXPERIMENT_OUTPUT_FILE
    case "$VTUNE_MODE" in
    "$VTUNE_MODE_MA")
        echo "VTUNE_MODE_MA" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$VTUNE_MODE_UE")
        echo "VTUNE_MODE_UE" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    ""|"Unspecified")
        echo "Unspecified" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    *)
        echo "Unknown" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    esac
    echo "VTUNE_MODE_RAW: $VTUNE_MODE" >> $EXPERIMENT_OUTPUT_FILE

    echo "##########################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Inmate-only Parameters #" >> $EXPERIMENT_OUTPUT_FILE
    echo "##########################" >> $EXPERIMENT_OUTPUT_FILE
    echo "THROTTLE_ITERATIONS: $THROTTLE_ITERATIONS" >> $EXPERIMENT_OUTPUT_FILE
    printf "THROTTLE_MODE: " >> $EXPERIMENT_OUTPUT_FILE
    case "$THROTTLE_MODE" in
    "$TMODE_ALTERNATING")
        echo "TMODE_ALTERNATING" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$TMODE_DEADLINE")
        echo "TMODE_DEADLINE" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$TMODE_ITERATION")
        echo "TMODE_ITERATION" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$TMODE_DISABLED")
        echo "TMODE_DISABLED" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    ""|"Unspecified")
        echo "Unspecified" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    *)
        echo "Unknown" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    esac
    echo "THROTTLE_MODE_RAW: $THROTTLE_MODE" >> $EXPERIMENT_OUTPUT_FILE

    printf "THROTTLE_MECHANISM: " >> $EXPERIMENT_OUTPUT_FILE
    case "$THROTTLE_MECHANISM" in
    "$TMECH_CLOCK")
        echo "TMECH_CLOCK" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$TMECH_SPIN")
        echo "TMECH_SPIN" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    ""|"Unspecified")
        echo "Unspecified" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    *)
        echo "Unknown" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    esac
    echo "THROTTLE_MECHANISM_RAW: $THROTTLE_MECHANISM" >> $EXPERIMENT_OUTPUT_FILE
    printf "LOCAL_INPUT_MODE: " >> $EXPERIMENT_OUTPUT_FILE
    case "$LOCAL_INPUT_MODE" in
    "$LI_NONE")
        echo "NONE" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$LI_RANDOM")
        echo "RANDOM" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$LI_UNIFORM")
        echo "UNIFORM" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    *)
        echo "Unknown" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    esac
    echo "PREEMPTION_TIMEOUT: $PREEMPTION_TIMEOUT" >> $EXPERIMENT_OUTPUT_FILE
    echo "SPIN_LOOP_ITERATIONS: $SPIN_LOOP_ITERATIONS" >> $EXPERIMENT_OUTPUT_FILE

    echo "##################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# End Parameters #" >> $EXPERIMENT_OUTPUT_FILE
    echo "##################" >> $EXPERIMENT_OUTPUT_FILE
}

# Parameters:
#   DEBUG_MODE
#   LOCAL_BUFFER
#   THROTTLE_MODE
#   THROTTLE_MECHANISM
#   WORKLOAD_MODE
#   COUNT_SET_BITS_MODE
#   POLLUTE_CACHE
#   THROTTLE_ITERATIONS
#   INPUT_FILE
#   PREEMPTION_TIMEOUT
#   SPIN_LOOP_ITERATIONS
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
    if [ ! -z "$LOCAL_INPUT_MODE" ] && [ "$LOCAL_INPUT_MODE" != "$LI_NONE" ]; then
        CMDLINE="${CMDLINE} li=$LOCAL_INPUT_MODE"
    fi
    if [ ! -z $PREEMPTION_TIMEOUT ]; then
        CMDLINE="${CMDLINE} pt=$PREEMPTION_TIMEOUT"
    fi
    if [ ! -z $SPIN_LOOP_ITERATIONS ]; then
        CMDLINE="${CMDLINE} sli=$SPIN_LOOP_ITERATIONS"
    fi

    # Remove leading whitespace
    # https://stackoverflow.com/questions/369758/how-to-trim-whitespace-from-a-bash-variable
    CMDLINE="$(echo -e "${CMDLINE}" | sed -e 's/^[[:space:]]*//')"
    echo $CMDLINE
}

function ns_to_s {
    local ns="$1"
    python3 -c "print(float($1)/float(1000000000))"
}

function ns_to_ms {
    local ns="$1"
    python3 -c "print(float($1)/float(1000000))"
}

function cycles_to_seconds {
    local cycles="$1"
    # This has proved to be invariant on my system
    local TSC_FREQUENCY=3696003000
    python3 -c "print(float($cycles)/float($TSC_FREQUENCY))"
}
# https://unix.stackexchange.com/questions/40786/how-to-do-integer-float-calculations-in-bash-or-other-languages-frameworks

function disable_turbo_boost {
    echo "Disabling Turbo Boost"
    echo "1" | sudo tee "$NO_TURBO_INTERFACE"
}

function enable_turbo_boost {
    echo "Enabling Turbo Boost"
    echo "0" | sudo tee "$NO_TURBO_INTERFACE"
}

# End the inmate cell at position 1
function sign_drivers {
    # See https://askubuntu.com/questions/760671/could-not-load-vboxdrv-after-upgrade-to-ubuntu-16-04-and-i-want-to-keep-secur/768310#768310

    # cd  ~/code/jailhouse/mgh/scripts
    # openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -nodes -days 36500 -subj "/CN=MGH Custom Driver Key (for Jailhouse)/"

    # Before signing these drivers, the keys need to be accepted by mokutil

    sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 $SCRIPTS_DIR/MOK.priv $SCRIPTS_DIR/MOK.der $JAILHOUSE_DIR/driver/jailhouse.ko
    modinfo $JAILHOUSE_DIR/driver/jailhouse.ko
    sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 $SCRIPTS_DIR/MOK.priv $SCRIPTS_DIR/MOK.der $MGH_DIR/uio-kernel-module/uio_ivshmem.ko
    modinfo $MGH_DIR/uio-kernel-module/uio_ivshmem.ko
}

function load_uio_driver {
    sudo modprobe uio
    sudo insmod $MGH_DIR/uio-kernel-module/uio_ivshmem.ko
    lsmod | grep -i uio
}

function load_jailhouse_driver {
    sudo insmod $JAILHOUSE_DIR/driver/jailhouse.ko
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

function get_size_of_file_bytes {
    wc -c < "$1"
}

function get_size_of_string_bytes {
    # https://stackoverflow.com/questions/4988155/is-there-a-bash-command-that-can-tell-the-size-of-a-shell-variable
    printf "$1" | wc -c
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
    local INMATE_CELL="$1"
    local INMATE_NAME="$2"
    local INMATE_PROGRAM="$3"
    local INMATE_CMDLINE="$4"
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
    local tmp2=($tmp)
    # Get InmateCellName
    local inmate=${tmp2[2]}
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

function jailhouse_root_total_vmexits {
    jailhouse_cell_total_vmexits $CELL_ROOT
}

function jailhouse_inmate_total_vmexits {
    jailhouse_cell_total_vmexits $CELL_INMATE_1
}

function jailhouse_cell_total_vmexits {
    cat "/sys/devices/jailhouse/cells/$1/statistics/vmexits_total"
}

# End the inmate cell at position 1
function show_cells {
    sudo $JAILHOUSE_BIN cell list
}

function build_jailhouse {
    pushd $JAILHOUSE_DIR > /dev/null

    # Setting CFLAGS somehow royally screws things up, but this is how to do it
    # make CFLAGS=-DMGH_X86_THROTTLE_CAPABILITY CC=gcc-7 > /dev/null
    # sudo make install CFLAGS=-DMGH_X86_THROTTLE_CAPABILITY CC=gcc-7 > /dev/null

    make CC=gcc-7 > /dev/null
    sudo make install CC=gcc-7 > /dev/null

    pushd $MGH_DIR/uio-kernel-module > /dev/null
    make > /dev/null
    sudo make install > /dev/null

    popd > /dev/null
    popd > /dev/null
}

# Build the workloads in Linux
# Use gcc-7 to match the version of gcc that Jailhouse is using.
# Pass -no-pie to the linker or else it will err saying:
# "... can not be used when making a PIE object; recompile with -fPIE"
# Apparently PIC/PIE is enabled by default on my Linux system, so explicitly
# disable it. Jailhouse, on the other hand, produces object files with -no-pie.
function build_linux_workloads {
    pushd $WORKLOAD_DIR > /dev/null
    rm -rf build > /dev/null
    LDFLAGS=-no-pie CC=gcc-7 meson build > /dev/null
    ninja -C build > /dev/null
    popd > /dev/null
}

function clean_jailhouse {
    pushd $JAILHOUSE_DIR > /dev/null
    make clean

    pushd $MGH_DIR/uio-kernel-module > /dev/null
    make clean

    popd > /dev/null
    popd > /dev/null
}

# End any Jailhouse Linux processes (sudo jailhouse console -f), since anything
# pending on the Jailhouse console will prevent unloading the driver.
function end_jailhouse_processes {
    # echo 'sudo killall -e "jailhouse"'
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
    end_jailhouse
    rm_drivers
    build_jailhouse
    load_drivers
}

function create_random_file_max {
    local file="$1"
    # Create the maximum-sized input possible
    # Current max size is (40 MB - 8)
    local size=$(((2**20 * 40)- 8))
    create_random_file $size $file
}

# The inmate is hardcoded to generate a local 20 MiB input of all `X` characters
function create_inmate_local_input_file {
    create_repeated_char_file 'X' $1 $((2**20 * 20))
}

# The inmate is hardcoded to generate a local 20 MiB input of all `X` characters
function create_inmate_local_random_input_file {
    prng $((2**20 * 20)) $1
}

# 1: String to repeatedly print to file (no newline)
# 2: file name to write to
# 3: Number of times to repeatedly print the string
function create_repeated_char_file {
    local char="$1"
    local file="$2"
    local size="$3"
    local char_size=$(get_size_of_string_bytes $char)
    # Only 1-byte chars are currently allowed
    if (($char_size > 1)); then
        echo "Only 1-byte strings are supported for create_repeated_file (char_size=$char_size)"
        return
    fi

    # https://stackoverflow.com/questions/3211891/creating-string-of-repeated-characters-in-shell-script
    head -c $size < /dev/zero | tr '\0' "$char" > "$file"
}

# 1: Size in bytes
# 2: file name to overwrite
function create_random_file {
    local size="$1"
    local file="$2"

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
    local input_file="tmp.txt"
    if [ "$LOCAL_INPUT_MODE" == "$LI_UNIFORM" ]; then
        create_inmate_local_input_file $input_file
    elif [ "$LOCAL_INPUT_MODE" == "$LI_RANDOM" ]; then
        create_inmate_local_random_input_file $input_file
    else
        input_file="$1"
    fi

    if [ "$3" == $WM_SHA3 ]; then
        # If we are running exclusively in Linux, run the actual workload, not
        # the golden standard, so we can profile things
        if [[ "$RUN_MODE" > "$RM_INMATE" ]]; then
            sha3_linux_file $input_file "$2"
        else
            sha3_linux_file_golden $input_file "$2"
        fi
    elif [ "$3" == $WM_RANDOM_ACCESS ]; then
        random_access_linux_file $input_file "$2"
    else
        # This is the default
        count_set_bits_linux_file $input_file "$2"
    fi
    if [ "$LOCAL_INPUT_MODE" != "$LI_NONE" ]; then
        rm $input_file
    fi
}

# Requires rhash to be installed on the system
# `sudo apt install rhash`
# See mgh/sha3/test.sh
function sha3_linux_file_golden {
    rhash --sha3-512 "$1" | cut -f 1 -d " "
}

function sha3_linux_str_golden {
    printf "$1" | rhash --sha3-512 - | cut -f 1 -d " "
}

function sha3_linux_file {
    if [ "$RUN_WITH_VTUNE" == 1 ]; then
        run_vtune $2 "$SHA3_BIN" -f "$1"
    else
        "$SHA3_BIN" -f "$1"
    fi
}

function sha3_linux_str {
    if [ "$RUN_WITH_VTUNE" == 1 ]; then
        run_vtune $2 "$SHA3_BIN" -s "$1"
    else
        "$SHA3_BIN" -s "$1"
    fi
}

function count_set_bits_linux_file {
    if [ "$RUN_WITH_VTUNE" == 1 ]; then
        run_vtune $2 "$CSB_BIN" "$1"
    else
        "$CSB_BIN" "$1"
    fi
}

function random_access_linux_file {
    if [ "$RUN_WITH_VTUNE" == 1 ]; then
        run_vtune $2 "$RA_BIN" "$1"
    else
        "$RA_BIN" "$1"
    fi
}

function clear_sync_byte_shmem {
    sudo $MGH_DEMO_PY -c
}

# Send input to the inmate via file
function send_inmate_input {
    local input_file="$1"
    if [ "$LOCAL_INPUT_MODE" != "$LI_NONE" ]; then
        # Go through the motions so the inmate knows to generate its own input
        local input_file="bogus_input.txt"
        touch $input_file
    fi

    if [ -z $input_file ]; then
        echo "error: no input file"
        return
    fi

    # Send input to inmate
    sudo $MGH_DEMO_PY -f $input_file

    if [ "$LOCAL_INPUT_MODE" != "$LI_NONE" ]; then
        rm $input_file
    fi
}

function run_vtune {
    local iteration_counter=$1
    # Get rid of iteration_counter from $@
    shift

    echo "iteration_counter: $iteration_counter" >> $VTUNE_OUTPUT_FILE 2>&1
    local vtune_result_dir="${VTUNE_RESULTS_BASE}_vtune${iteration_counter}"
    local vtune_report_file="${vtune_result_dir}/report_${iteration_counter}.txt"

    if [ "$VTUNE_MODE" == "$VTUNE_MODE_MA" ]; then
        vtune_mem_access $vtune_result_dir "$@"
    else
        vtune_uarch_explore $vtune_result_dir "$@"
    fi
    # Create a report and save it
    amplxe-cl -report summary -r $vtune_result_dir -format=csv > $vtune_report_file 2>&1
}

function vtune_mem_access {
    local result_dir=$1
    # Get rid of the result dir from $@
    shift

    echo "$VTUNE_BIN \
    -collect memory-access \
    -knob analyze-mem-objects=true \
    -knob mem-object-size-min-thres=1 \
    -app-working-dir=$VTUNE_OUTPUT_DIR \
    -result-dir=$result_dir \
    -- $@" >> $VTUNE_OUTPUT_FILE 2>&1

    pushd $VTUNE_OUTPUT_DIR > /dev/null
    $VTUNE_BIN \
    -collect memory-access \
    -knob analyze-mem-objects=true \
    -knob mem-object-size-min-thres=1 \
    -app-working-dir $VTUNE_OUTPUT_DIR \
    -result-dir=$result_dir \
    -- "$@" >> $VTUNE_OUTPUT_FILE 2>&1
    popd > /dev/null
}

function vtune_uarch_explore {
    local result_dir=$1
    # Get rid of the result dir from $@
    shift

    echo "$VTUNE_BIN \
    -collect uarch-exploration \
    -knob collect-memory-bandwidth=true \
    -app-working-dir=$VTUNE_OUTPUT_DIR \
    -result-dir=$result_dir \
    -- $@" >> $VTUNE_OUTPUT_FILE 2>&1

    pushd $VTUNE_OUTPUT_DIR > /dev/null
    $VTUNE_BIN \
    -collect uarch-exploration \
    -knob collect-memory-bandwidth=true \
    -app-working-dir $VTUNE_OUTPUT_DIR \
    -result-dir=$result_dir \
    -- "$@" >> $VTUNE_OUTPUT_FILE 2>&1
    popd > /dev/null
}

# https://stackoverflow.com/questions/17066250/create-timestamp-variable-in-bash-script
function timestamp {
    date +"%Y-%m-%d_%H-%M-%S"
}
function get_git_commit {
    git rev-parse HEAD
}

# Get the $output_column of all lines where $token == $token_column and merge
# them together into a single comman-separated list.
# Output as "$before$csv_list$after". $before and $after default to "".
function aggregate_column_csv {
    local token="$1"
    local token_col="$2"
    local output_col="$3"
    local in_file="$4"
    local before="$5"
    local after="$6"
    aggregate_custom_csv "$token" "$token_col" "\$$output_col" "$in_file" "$before" "$after"
}
# https://stackoverflow.com/questions/26148546/grep-keeping-lines-that-has-specific-string-in-certain-column




# Same as aggregate_column_csv, except $output_col is customizable to print
# multiple columns in any format
function aggregate_custom_csv {
    local token="$1"
    local token_column="$2"
    local print_txt="$3"
    local in_file="$4"
    local before="$5"
    local after="$6"

    # Use awk to find the lines where $token_column == $token and print out
    # column $output_column, replace all newlines with commas, replace the
    # last comma with a newline, prepend $before, and append $after.
    tmp="\$$token_column == \"$token\" {print($print_txt)}"
    awk -F ',' "$tmp" $in_file | tr '\n' ',' | sed "s/,$/\n/" | sed "s/^/$before/" | sed "s/$/$after/"
}
# https://stackoverflow.com/questions/26148546/grep-keeping-lines-that-has-specific-string-in-certain-column

function grep_output_data_throttled {
    local in_file="$1"
    grep_token_in_file "MGHOUT:is_throttled,\|MGHOUT:1," $in_file
}

function grep_output_data_unthrottled {
    local in_file="$1"
    grep_token_in_file "MGHOUT:is_throttled,\|MGHOUT:0," $in_file
}

function grep_output_freq_throttled {
    local in_file="$1"
    grep_token_in_file "MGHFREQ:is_throttled,\|MGHFREQ:1," $in_file
}

function grep_output_freq_unthrottled {
    local in_file="$1"
    grep_token_in_file "MGHFREQ:is_throttled,\|MGHFREQ:0," $in_file
}

# input file should be the output of grep_output_freq_[un]throttled
# freq = (max_freq * aperf) / mperf
# max_perf = $3
# aperf = $4
# mperf = $5
function aggregate_avg_freq {
    local input_file="$1"
    local input_size="$2"
    aggregate_custom_csv "$input_size" 2 "\$3,\"*\",\$4,\"/\",\$5" $input_file "=AVERAGE(" ")"
}

function grep_all_but_token_in_file {
    local token="$1"
    local in_file="$2"

    # echo "grep -v \"$token\" $in_file | sed \"s/${token}//\" | sed \"s/\r//\""
    grep -v "$token" $in_file | sed "s/${token}//" | sed "s/\r//"
}

# Grep a file for all lines with a token, remove that token from the output,
# remove additional carriage returns (since grep puts a single carriage return
# at the start, then adds carriage returns to all newlines)
function grep_token_in_file {
    local token="$1"
    local in_file="$2"

    # echo "grep \"$token\" $in_file | sed \"s/${token}//\" | sed \"s/\r//\""
    grep "$token" $in_file | sed "s/${token}//" | sed "s/\r//"
}

function grep_token_in_str {
    local token="$1"
    local str="$2"

    echo "$str" | grep "$token" | sed "s/${token}//" | sed "s/\r//"
}

function start_handbrake_demo {
    local TIMESTAMP=$(timestamp)
    local INPUT="$SOURCES_DIR/i_am_legend.m2ts"
    local OUTPUT="$OUTPUT_DIR/handbrake_$TIMESTAMP.bin"

    HandBrakeCLI -i $INPUT -o $OUTPUT >> $INTERFERENCE_WORKLOAD_OUTPUT 2>&1 &
    workload_pid=$!
}

function stop_handbrake {
    echo "sudo killall HandBrakeCLI"
    sudo killall HandBrakeCLI
    # NOTE: $! doesn't get the proper PID of HandBrakeCLI, so kill it by name
}

function start_workload_demo {
    $SCRIPTS_DIR/workload-demo.sh "$1" >> $INTERFERENCE_WORKLOAD_OUTPUT 2>&1 &
    workload_pid=$!
}

function stop_workload_demo {
    local pid=$1
    kill $pid
}

# Starts the interference workload in the background and set the global
# workload_pid.
function start_interference_workload {
    local workload="$1"
    if [ "$workload" == $INTF_HANDBRAKE ]; then
        start_handbrake_demo
    elif [ "$workload" != $INTF_NONE ]; then
        start_workload_demo $workload
    fi
}

# Stop the interference workload.
# If handbrake, kill it by name, else kill it by pid.
function stop_interference_workload {
    local workload="$1"
    if [ "$workload" == $INTF_HANDBRAKE ]; then
        stop_handbrake
    elif [ "$workload" != $INTF_NONE ]; then
        local pid="$2"
        stop_workload_demo "$pid"
    fi
}

# Jailhouse currently prints newlines as carriage return + line feed, which can
# mess up awk big time. So strip out all carriage returns.
# See https://stackoverflow.com/questions/60203007/awk-is-only-matching-the-first-line-when-matching-against-first-column
function sanitize_console_output {
    local input_file="$1"
    local output_file="$2"

    # Remove all carriage return characters
    tr -d '\r' < "$input_file" > "$output_file"

    # To turn newlines into CR + LF (e.g. for UARTs or Windows), do this instead
    # Remove all \r, add a \n to end of file if dne, and add \r before all \n
    # tr -d '\r' < "$input_file" | sed -e '$a\' | sed 's/$/\r/' > "$output_file"
}


# Global inputs:
# $RUN_MODE
# $INMATE_DEBUG
# $VTUNE_OUTPUT_FILE
# $JAILHOUSE_OUTPUT_FILE
# ...more passed to inner functions
function post_process_data {
    local output_dir="$1"
    local time="$2"
    if [[ "$RUN_MODE" > "$RM_INMATE" ]]; then
        post_process_data_linux $VTUNE_OUTPUT_FILE $output_dir $time
    else
        post_process_data_jailhouse $JAILHOUSE_OUTPUT_FILE $output_dir $time
    fi
}

# Global inputs:
# $RUN_WITH_VTUNE
function post_process_data_linux {
    local input_data_file="$1"
    local output_dir="$2"
    local time="$3"

    if [ "$RUN_WITH_VTUNE" != 1 ]; then
        return
    fi

    local vtune_runs_file="$output_dir/vtune_runs_${time}.txt"
    # vtune_times_file="$OUTPUT_DIR/vtune_times_${time}.txt"

    # Create a condensed list of VTune output folders
    grep_token_in_file "amplxe: Using result path " $input_data_file > $vtune_runs_file
    # grep_token_in_file "Elapsed Time: " $input_data_file > $vtune_times_file
    # grep_all_but_token_in_file "amplxe:" $input_data_file > $vtune_runs_file
}

# Global inputs:
# $INMATE_DEBUG
# $INPUT_SIZE_START
# $INPUT_SIZE_END
# $INPUT_SIZE_STEP
# $INPUT_FILE
# $THROTTLE_MODE
function post_process_data_jailhouse {
    # Don't post-process the short-circuited inmate debug mode's output
    if [ "$INMATE_DEBUG" == 1 ]; then
        return
    fi

    # local inputs:
    local input_data_file_dirty="$1"
    local output_dir="$2"
    local time="$3"

    # TSC freq shouldn't ever change for my system, but it will on other systems
    # local tsc_freq=$(grep_token_in_file "MGH: Maximum Non-Turbo Frequency: " $input_data_file)
    local tsc_freq=3700000000

    # # Use a sanitized version of the input
    local input_data_file="$output_dir/jailhouse_clean_${time}.txt"
    sanitize_console_output $input_data_file_dirty $input_data_file

    # Create a file for potential columns in a spreadsheet
    local input_sizes_b_data="$output_dir/input_sizes_b_${time}.txt"
    local input_sizes_mb_data="$output_dir/input_sizes_mb_${time}.txt"

    # _<file_name> means it's only an intermediate file ('private')
    # <file_name> means it's a drop in for a spreadsheet column ('public')
    local unthrottled_cycles="$output_dir/_cycles_unthrottled_${time}.csv"
    # local unthrottled_cycles_flat="$output_dir/_cycles_flat_unthrottled_${time}.txt"
    local unthrottled_avg_dur_s="$output_dir/dur_avg_s_unthrottled_${time}.txt"
    local unthrottled_avg_dur_ms="$output_dir/dur_avg_ms_unthrottled_${time}.txt"
    local unthrottled_freq="$output_dir/_freq_unthrottled_${time}.csv"
    local unthrottled_freq_avg="$output_dir/freq_avg_unthrottled_${time}.txt"

    local throttled_cycles="$output_dir/_cycles_throttled_${time}.csv"
    # local throttled_cycles_flat="$output_dir/_cycles_flat_throttled_${time}.txt"
    local throttled_avg_dur_s="$output_dir/dur_avg_s_throttled_${time}.txt"
    local throttled_avg_dur_ms="$output_dir/dur_avg_ms_throttled_${time}.txt"
    local throttled_freq="$output_dir/_freq_throttled_${time}.csv"
    local throttled_freq_avg="$output_dir/freq_avg_throttled_${time}.txt"

    # Do not print out all MGHFREQ lines. Avg freq is already in MGHOUT
    local input_sizes=()
    generate_input_size_range $INPUT_SIZE_START $INPUT_SIZE_END $INPUT_SIZE_STEP

    # Separate throttled and unthrottled data for further processing
    grep_output_data_unthrottled $input_data_file > $unthrottled_cycles
    grep_output_freq_unthrottled $input_data_file > $unthrottled_freq

    if [ "$INPUT_FILE" == "" ]; then
        # Aggregate iterations for each input size
        for input_size in "${input_sizes[@]}"; do
            process_cycle_data_unthrottled
        done
    else
        if [ "$LOCAL_INPUT_MODE" != "$LI_NONE" ]; then
            input_size="$LOCAL_INPUT_SIZE"
        else
            input_size="$(get_size_of_file_bytes $INPUT_FILE)"
        fi
        process_cycle_data_unthrottled
    fi

    if [ "$THROTTLE_MODE" != "$TMODE_DISABLED" ]; then
        grep_output_data_throttled $input_data_file > $throttled_cycles
        grep_output_freq_throttled $input_data_file > $throttled_freq
        if [ "$INPUT_FILE" == "" ]; then
            # Aggregate iterations for each input size
            for input_size in "${input_sizes[@]}"; do
                process_cycle_data_throttled
            done
        else
            if [ "$LOCAL_INPUT_MODE" != "$LI_NONE" ]; then
                input_size="$LOCAL_INPUT_SIZE"
            else
                input_size="$(get_size_of_file_bytes $INPUT_FILE)"
            fi
            process_cycle_data_throttled
        fi
    fi
}

# Pull out common functionality so it can be done in a for loop or stand-alone
function process_cycle_data_unthrottled {
    echo "$input_size" >> $input_sizes_b_data
    echo "=$input_size/$MiB" >> $input_sizes_mb_data
    # aggregate_column_csv "$input_size" 2 3 $unthrottled_cycles "$input_size|" >> $unthrottled_cycles_flat
    aggregate_column_csv "$input_size" 2 3 $unthrottled_cycles "=AVERAGE(" ")\/$tsc_freq" >> $unthrottled_avg_dur_s
    aggregate_column_csv "$input_size" 2 3 $unthrottled_cycles "=AVERAGE(" ")*1000\/$tsc_freq" >> $unthrottled_avg_dur_ms
    aggregate_avg_freq $unthrottled_freq "$input_size" >> $unthrottled_freq_avg
}

function process_cycle_data_throttled {
    # aggregate_column_csv "$input_size" 2 3 $throttled_cycles "$input_size|" >> $throttled_cycles_flat
    aggregate_column_csv "$input_size" 2 3 $throttled_cycles "=AVERAGE(" ")\/$tsc_freq" >> $throttled_avg_dur_s
    aggregate_column_csv "$input_size" 2 3 $throttled_cycles "=AVERAGE(" ")*1000\/$tsc_freq" >> $throttled_avg_dur_ms
    aggregate_avg_freq $throttled_freq "$input_size" >> $throttled_freq_avg
}

# Calculates the input sizes based on start, end, and step, and adds to an
# already existing input_sizes array.
# IN/OUT: $input_size
function generate_input_size_range {
    local start="$1"
    local end="$2"
    local step="$3"
    for ((input_size = "$start"; input_size < "$end"; input_size += "$step")); do
        input_sizes+=($input_size)
    done
}

# Calculate a pseudo random number in a similar way as the inmate, and output
# the binary data into an output file.
function prng {
    local size="$1"
    local output="$2"
    # Get a random seed based on the Unix timestamp
    local seed=$(date +%s)

    $PRNG_BIN $size $seed $output
}
# https://stackoverflow.com/questions/17066250/create-timestamp-variable-in-bash-script