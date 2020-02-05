#!/bin/bash

# Start the root cell with start-bazooka-root-linux.sh

INMATE_CELL="../../configs/x86/bazooka-inmate-linux.cell"

# Kubuntu 19.10 kernel
# # (The kernel image of Kubuntu is too large because it uncompresses to over 86
# MB, larger than the 75 MB given to the inmate)
# KERNEL="/home/hintron/code/linux/arch/x86/boot/bzImage-kubuntu1"
# INITRAMFS="./images/initramfs-kubuntu-19.10.bin"

# Vanilla Alpine kernel
# KERNEL="./images/vmlinuz-alpine-3.11.3.bin"

# Modified Alpine Linux kernel on the Linux queue/jailhouse branch with
# configs set to enable Jailhouse and IVSHMEM.
# TODO: This needs to be debugged with the serial port (it crashes after starup)
KERNEL="/home/hintron/code/linux/arch/x86/boot/bzImage-alpine-jailhouse"
INITRAMFS="./images/initramfs-alpine-3.11.3.bin"

sudo ../../tools/jailhouse cell linux $INMATE_CELL $KERNEL -i $INITRAMFS -c "console=ttyS0,115200"

# --write-params shows what the `jailhouse cell linux` command does under the
# covers, I think