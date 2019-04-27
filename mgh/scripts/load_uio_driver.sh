#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
sudo modprobe uio
sudo insmod ../uio-kernel-module/uio_ivshmem.ko
lsmod | grep -i uio