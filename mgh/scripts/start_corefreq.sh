#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

SRC="/home/hintron/code/CoreFreq"
KMOD="$SRC/corefreqk.ko"
CLI="corefreq-cli"

cd $SRC

sudo insmod $KMOD
sudo sudo systemctl restart corefreqd.service
sudo systemctl status corefreqd.service
sudo $CLI