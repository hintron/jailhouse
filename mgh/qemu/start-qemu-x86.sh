#!/bin/bash

# Make this script callable from anywhere
# https://stackoverflow.com/questions/6659689/referring-to-a-file-relative-to-executing-script
cd "${BASH_SOURCE%/*}" || exit

# Set defaults that can be overwritten
if [ -z "$QEMU" ]; then
	QEMU="/home/hintron/bin/qemu-system-x86_64"
fi
if [ -z "$IMAGE_FILE" ]; then
	IMAGE_FILE="images/demo-image-qemuamd64-jailhouse-demo-qemuamd64.ext4.img"
fi
if [ -z "$INITRD_FILE" ]; then
	INITRD_FILE="images/temp2/initrd.img-4.14.73"
fi
if [ -z "$KERNEL_FILE" ]; then
	KERNEL_FILE="images/temp2/vmlinuz-4.14.73"
fi
if [ -z "$SUDO" ]; then
	SUDO="sudo"
fi

echo "$QEMU"
echo "$IMAGE_FILE"
echo "$INITRD_FILE"
echo "$KERNEL_FILE"

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