#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

SRC="/home/hintron/code/CoreFreq"
KMOD="$SRC/corefreqk.ko"
DAEMON="$SRC/corefreqd"
CLI="$SRC/corefreq-cli"

sudo insmod $KMOD
sudo sudo systemctl restart corefreqd.service
sudo systemctl status corefreqd.service
$CLI