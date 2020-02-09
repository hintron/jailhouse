#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

SRC="/home/hintron/code/CoreFreq"
KMOD="$SRC/corefreqk.ko"
CLI="corefreq-cli"

lsmod | grep corefreqk
success=$?

# If the corefreqk kernel module is not loaded already...
if [ $success != 0 ]; then
    sudo insmod $KMOD
    success=$?

    if [ $success != 0 ]; then
        echo "Failed to load corefreqk kernel module (rc=$success). Building and trying again..."
        ./build_corefreq.sh > /dev/null
        sudo insmod $KMOD
        success=$?
        if [ $success != 0 ]; then
            echo "Failed to load corefreqk kernel module even *after* building (rc=$success). Exiting..."
            exit
        fi
    fi
    echo "Loaded corefreqk"
    sudo systemctl restart corefreqd.service
    sudo systemctl status corefreqd.service
fi

# Start up the corefreq client
sudo $CLI