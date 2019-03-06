[Back to README-MGH.md](../README-MGH.md)
# Docs

This is a collection of personal notes and external documentation. Some docs
are copied here locally for convenience.

## Contents:

#### Jailhouse Inter-cell Communication

Jailhouse doc explaining inter cell communication with shared memory and
ivshmem.

See [Documentation/inter-cell-communication.txt](../../Documentation/inter-cell-communication.txt)


#### Jailhouse paper

This is a paper, written by the Jailhouse devs, introducing Jailhouse.

See https://arxiv.org/pdf/1705.06932.pdf


#### _Linux Device Drivers_, Chapter 12: PCI Drivers

A good chapter on how PCI Drivers work.

See https://static.lwn.net/images/pdf/LDD3/ch12.pdf


#### Linux Device Driver Tutorial

A simple tutorial on how to write a linux kernel module.

See http://derekmolloy.ie/writing-a-linux-kernel-module-part-1-introduction/


#### Linux PCI Driver Overview - pci.txt

This explains the sysfs API for PCI devices/drivers.

https://www.kernel.org/doc/Documentation/PCI/pci.txt
Also included [here](pci.txt) for convenience.

#### Linux PCI - sysfs-pci.txt

This explains the sysfs API for PCI devices/drivers.

See https://www.kernel.org/doc/Documentation/filesystems/sysfs-pci.txt
Also included [here](sysfs-pci.txt) for convenience.


#### Linux UIO - uio-howto.rst

This explains how the Linux UIO kernel module system works, and what things
can be done with _/dev/uio0_.

See https://www.kernel.org/doc/Documentation/driver-api/uio-howto.rst
Also included [here](uio-howto.rst) for convenience.


#### QEMU ivshmem-spec.txt
The ivshmem virtual PCI device spec from QEMU. Jailhouse's is slightly
different.

See https://github.com/qemu/qemu/blob/master/docs/specs/ivshmem-spec.txt
Also included [here](ivshmem-spec.txt) for convenience.


#### README.jailhouse
The readme of the ivshmem-guest-code project, on the jailhouse branch

See https://github.com/henning-schild-work/ivshmem-guest-code/blob/jailhouse/README.jailhouse
Also included [here](README.jailhouse) for convenience.


#### device_spec.txt

This explains the Jailhouse version of the ivshmem PCI device, and is based off
of QEMU's ivshmem-spec.txt. This if from the jailhouse branch of
ivshmem-guest-code.

See https://github.com/henning-schild-work/ivshmem-guest-code/blob/jailhouse/device_spec.txt
Also included [here](device_spec.txt) for convenience.
