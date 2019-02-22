#!/bin/bash

QEMU=link/qemu
IMAGE_FILE=link/img
INITRD_FILE=link/initrd
KERNEL_FILE=link/kernel

# IMAGE_FILE=images/img
# IMAGE_FILE=images/backup
# INITRD_FILE=images/initrd
# KERNEL_FILE=images/kernel
# INITRD_FILE=images/initrd96
# KERNEL_FILE=images/kernel96
# INITRD_FILE=images/initrd73kall
# KERNEL_FILE=images/kernel73kall
# INITRD_FILE=images/initrd-uio
# KERNEL_FILE=images/kernel-uio

SUDO="sudo"

QEMU_EXTRA_ARGS=" \
	-cpu kvm64,-kvm_pv_eoi,-kvm_steal_time,-kvm_asyncpf,-kvmclock,+vmx,+arat \
	-smp 4 \
	-enable-kvm -machine q35,kernel_irqchip=split \
	-serial vc \
	-device ide-hd,drive=disk \
	-device intel-iommu,intremap=on,x-buggy-eim=on \
	-device intel-hda,addr=1b.0 -device hda-duplex \
	-device e1000e,addr=2.0,netdev=net"
KERNEL_CMDLINE=" \
	root=/dev/sda intel_iommu=off memmap=82M\$0x3a000000 \
	vga=0x305"
# Try to get Docker working: enable cgroup memory for Debian.
# See https://slurm.schedmd.com/cgroups.html
#	vga=0x305 cgroup_enable=memory swapaccount=1"

$SUDO ${QEMU} \
	-drive file=${IMAGE_FILE},discard=unmap,if=none,id=disk,format=raw \
	-m 1G -serial mon:stdio -netdev user,id=net \
	-kernel ${KERNEL_FILE} -append "${KERNEL_CMDLINE}" \
	-initrd ${INITRD_FILE} ${QEMU_EXTRA_ARGS} "$@"

# NOTE: Changing the alloted memory will mess up Jailhouse.
# See https://groups.google.com/forum/#!topic/jailhouse-dev/yvGRjoHVBSc