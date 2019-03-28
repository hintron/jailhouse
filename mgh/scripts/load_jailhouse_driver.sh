#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
sudo insmod ../../driver/jailhouse.ko
lsmod | grep -i jail