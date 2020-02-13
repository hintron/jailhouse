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

# Note that the inmate libraries assume that the cmdline string will be stored
# at 0x1000 and will have a size of CMDLINE_BUFFER_SIZE.
CMDLINE_OFFSET=0x1000
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
TMECH_PAUSE=2 # Not yet implemented

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
INTF_NONE=0
INTF_HANDBRAKE=1
INTF_RANDOM=2

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
LOCAL_INPUT_TOKEN="<local-input>"

function log_parameters {
    echo "#####################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Common Parameters #" >> $EXPERIMENT_OUTPUT_FILE
    echo "#####################" >> $EXPERIMENT_OUTPUT_FILE
    echo "TIMESTAMP: $experiment_time" >> $EXPERIMENT_OUTPUT_FILE
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
        if [ "$INPUT_FILE" != "$LOCAL_INPUT_TOKEN" ]; then
            echo "INPUT_FILE size: $(get_size_of_file_bytes $INPUT_FILE) Bytes" >> $EXPERIMENT_OUTPUT_FILE
        fi
    fi
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

    printf "INTERFERENCE_WORKLOAD: " >> $EXPERIMENT_OUTPUT_FILE
    case "$INTERFERENCE_WORKLOAD" in
    "$INTF_NONE")
        echo "INTF_NONE" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$INTF_HANDBRAKE")
        echo "INTF_HANDBRAKE" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    "$INTF_RANDOM")
        echo "INTF_RANDOM" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    ""|"Unspecified")
        echo "Unspecified" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    *)
        echo "Unknown" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    esac
    echo "INTERFERENCE_WORKLOAD_RAW: $INTERFERENCE_WORKLOAD" >> $EXPERIMENT_OUTPUT_FILE

    echo "#########################" >> $EXPERIMENT_OUTPUT_FILE
    echo "# Linux-only Parameters #" >> $EXPERIMENT_OUTPUT_FILE
    echo "#########################" >> $EXPERIMENT_OUTPUT_FILE
    echo "RUN_WITH_VTUNE: $RUN_WITH_VTUNE" >> $EXPERIMENT_OUTPUT_FILE
    echo "VTUNE_OUTPUT_FILE: $VTUNE_OUTPUT_FILE" >> $EXPERIMENT_OUTPUT_FILE
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
    "$TMECH_PAUSE")
        echo "TMECH_PAUSE" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    ""|"Unspecified")
        echo "Unspecified" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    *)
        echo "Unknown" >> $EXPERIMENT_OUTPUT_FILE
        ;;
    esac
    echo "THROTTLE_MECHANISM_RAW: $THROTTLE_MECHANISM" >> $EXPERIMENT_OUTPUT_FILE

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
    if [ "$INPUT_FILE" == "$LOCAL_INPUT_TOKEN" ]; then
        CMDLINE="${CMDLINE} li=1"
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
    local input_file="$1"
    if [ "$INPUT_FILE" == "$LOCAL_INPUT_TOKEN" ]; then
        input_file="tmp.txt"
        create_inmate_local_input_file $input_file
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

    if [ "$INPUT_FILE" == "$LOCAL_INPUT_TOKEN" ]; then
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
        run_vtune $2 "${WORKLOAD_BIN_DIR}/sha3-512" -f "$1"
    else
        "${WORKLOAD_BIN_DIR}/sha3-512" -f "$1"
    fi
}

function sha3_linux_str {
    if [ "$RUN_WITH_VTUNE" == 1 ]; then
        run_vtune $2 "${WORKLOAD_BIN_DIR}/sha3-512" -s "$1"
    else
        "${WORKLOAD_BIN_DIR}/sha3-512" -s "$1"
    fi
}

function count_set_bits_linux_file {
    if [ "$RUN_WITH_VTUNE" == 1 ]; then
        run_vtune $2 "${WORKLOAD_BIN_DIR}/count-set-bits" "$1"
    else
        "${WORKLOAD_BIN_DIR}/count-set-bits" "$1"
    fi
}

function random_access_linux_file {
    if [ "$RUN_WITH_VTUNE" == 1 ]; then
        run_vtune $2 "${WORKLOAD_BIN_DIR}/random-access" "$1"
    else
        "${WORKLOAD_BIN_DIR}/random-access" "$1"
    fi
}

function clear_sync_byte_shmem {
    sudo $MGH_DEMO_PY -c
}

# Send input to the inmate via file
function send_inmate_input {
    local input_file="$1"
    if [ "$input_file" == "$LOCAL_INPUT_TOKEN" ]; then
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

    if [ "$input_file" == "$LOCAL_INPUT_TOKEN" ]; then
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

function grep_freq_data {
    local in_file="$1"
    grep_token_in_file_to_file "MGHFREQ:" $in_file
}

# Use awk to get all lines of a csv where column $token_column == $token.
# Then, grab the value in $output_column and append to a comma-separated list.
# Output as "$token|$csv_list".
function grep_token_columns_csv {
    local token="$1"
    local token_column="$2"
    local output_column="$3"
    local in_file="$4"

    # Use awk to find the lines where $token_column == $token, use cut to get
    # the column $output_column, replace all newlines with commas, replace the
    # last comma with a newline, and prepend "$token|".
    awk  -F ',' "\$$token_column == $token" $in_file | cut -f$output_column -d, | tr '\n' ',' | sed "s/.$/\n/" | sed "s/^/$token|/"
}
# https://stackoverflow.com/questions/26148546/grep-keeping-lines-that-has-specific-string-in-certain-column

function grep_output_data_throttled {
    local in_file="$1"
    grep_token_in_file_to_file "MGHOUT:is_throttled,\|MGHOUT:1," $in_file
}

function grep_output_data_unthrottled {
    local in_file="$1"
    grep_token_in_file_to_file "MGHOUT:is_throttled,\|MGHOUT:0," $in_file
}

function grep_output_freq_throttled {
    local in_file="$1"
    grep_token_in_file_to_file "MGHFREQ:is_throttled,\|MGHFREQ:1," $in_file
}

function grep_output_freq_unthrottled {
    local in_file="$1"
    grep_token_in_file_to_file "MGHFREQ:is_throttled,\|MGHFREQ:0," $in_file
}

# Grep a file for all lines with a token, remove that token from the output,
# remove additional carriage returns (since grep puts a single carriage return
# at the start, then adds carriage returns to all newlines), and store the
# output in a file.
function grep_token_in_file_to_file {
    local token="$1"
    local in_file="$2"

    grep_token_in_file $token $in_file
}

function grep_all_but_token_in_file_to_file {
    local token="$1"
    local in_file="$2"

    # echo "grep -v \"$token\" $in_file | sed \"s/${token}//\" | sed \"s/\r//\""
    grep -v "$token" $in_file | sed "s/${token}//" | sed "s/\r//"
}

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

function start_handbrake {
    local INPUT="$1"
    local OUTPUT="$2"

    HandBrakeCLI -i $INPUT -o $OUTPUT
}

function start_handbrake_demo {
    local TIMESTAMP=$(timestamp)

    local INPUT="/home/hintron/Videos/sources/i_am_legend.m2ts"
    local OUTPUT="/home/hintron/Videos/jailhouse_outputs/run_$TIMESTAMP"

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
    # grep_all_but_token_in_file_to_file "amplxe:" $input_data_file > $vtune_runs_file
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
    local input_data_file="$1"
    local output_dir="$2"
    local time="$3"

    local unthrottled_data="$output_dir/unthrottled_${time}.csv"
    local unthrottled_avg_data="$output_dir/unthrottled_avg_${time}.csv"
    local unthrottled_freq="$output_dir/unthrottled_freq_${time}.csv"

    local throttled_data="$output_dir/throttled_${time}.csv"
    local throttled_avg_data="$output_dir/throttled_avg_${time}.csv"
    local throttled_freq="$output_dir/throttled_freq_${time}.csv"

    # Do not print out all MGHFREQ lines. Avg freq is already in MGHOUT
    local input_sizes=()
    generate_input_size_range $INPUT_SIZE_START $INPUT_SIZE_END $INPUT_SIZE_STEP

    # Separate throttled and unthrottled data
    grep_output_data_unthrottled $input_data_file > $unthrottled_data
    grep_output_freq_unthrottled $input_data_file > $unthrottled_freq

    if [ "$INPUT_FILE" == "" ]; then
        # Aggregate iterations for each input size
        for input_size in "${input_sizes[@]}"; do
            grep_token_columns_csv "$input_size" 2 3 $unthrottled_data >> $unthrottled_avg_data
        done
    elif [ "$INPUT_FILE" == "$LOCAL_INPUT_TOKEN" ]; then
        grep_token_columns_csv "$LOCAL_INPUT_SIZE" 2 3 $unthrottled_data >> $unthrottled_avg_data
    else
        grep_token_columns_csv "$(get_size_of_file_bytes $INPUT_FILE)" 2 3 $unthrottled_data >> $unthrottled_avg_data
    fi

    if [ "$THROTTLE_MODE" != "$TMODE_DISABLED" ]; then
        grep_output_data_throttled $input_data_file > $throttled_data
        grep_output_freq_throttled $input_data_file > $throttled_freq
        if [ "$INPUT_FILE" == "" ]; then
            # Aggregate iterations for each input size
            for input_size in "${input_sizes[@]}"; do
                grep_token_columns_csv "$input_size" 2 3 $throttled_data >> $throttled_avg_data
            done
        else
            grep_token_columns_csv "$(get_size_of_file_bytes $INPUT_FILE)" 2 3 $throttled_data >> $throttled_avg_data
        fi
    fi
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