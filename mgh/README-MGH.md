README - Hintron Fork of Jailhouse
====================================

[Checkout the TODO list here](mgh/TODO.md).

## Overview

The goal of this project is to use Jailhouse to get a real-time VM running
alongside a Linux VM on the same CPU and measure how isolated the workloads are.

Of interest is how the real-time VM with a real-time workload is affected when
the Linux VM is processing an intensive workload.

Development will be done with QEMU, for convenience, with the goal to eventually
run on actual hardware to get good performance results.

## Components

### Jailhouse

#### QEMU Demo

[_configs/x86/qemu-mgh.c_](configs/x86/qemu-mgh.c) is the root cell's resource
configuration of the virtual QEMU system. This file tells Jailhouse what
resources are available on the system for Jailhouse to partition. It creates a
file called _qemu-mgh.cell_ that is used by the `jailhouse cell create` command
to actually instantiate the root cell. It's based off of
[_configs/x86/qemu-x86.c_](configs/x86/qemu-x86.c).

[_configs/x86/mgh-demo.c_](configs/x86/mgh-demo.c) is the real-time cell's
resource configuration. It's simply a subset of _qemu-mgh.c_. It creates a file
called _mgh-demo.cell_ that is used by the `jailhouse cell create` command to
instantiate/partition the real-time cell (inmate). It's based off of
[_configs/x86/ivshmem-demo.c_](configs/x86/ivshmem-demo.c).

[_inmates/demos/x86/mgh-demo.c_](inmates/demos/x86/mgh-demo.c) is the main code
of the real-time inmate cell. This will generate mgh-demo.bin and is the
"program" loaded into the inmate via the `jailhouse cell load` command.
It has access to any resources specified in _mgh-demo.cell_. It's based off of
[_inmates/demos/x86/ivshmem-demo.c_](inmates/demos/x86/ivshmem-demo.c).

The root cell and inmate communicate over the Jailhouse ivshmem virtual PCI
device. The root Linux Jailhouse cell will use the uio-kernel-module and
uio-userspace code to talk to the inmate over this virtual PCI device from
Linux. The inmate will use the Jailhouse API directly to talk to the root cell
through the virtual PCI device.

#### Bazooka

bazooka-demo is an inmate demo based on apic-demo for my x86-64 Intel Kubuntu
18.04 "bazooka" machine. The root config is ?, and is generated from the x86
hardware generator. It's a work in progress.

#### Other Systems
The QEMU Jailhouse cells will need to be ported to work on each non-QEMU system.


### UIO IVSHMEM Kernel Module

mgh/uio-kernel-module contains a uio_ivshmem kernel module that
enables a Linux root cell to talk to an inmate in Jailhouse. This uses the UIO
kernel module framework.

Code is forked from https://github.com/henning-schild-work/ivshmem-guest-code,
specifically from the "jailhouse" branch.


### UIO Userspace Programs

mgh/uio-userspace contains userspace programs that the Linux root cell can use
to interact with the UIO Kernel Module

Code is forked from https://github.com/henning-schild-work/ivshmem-guest-code,
specifically from the "jailhouse" branch.


### QEMU

mgh/qemu contains helper scripts and documentation to create and run
Jailhouse-enabled QEMU images on any machine.

Images are created through jailhouse-images.


### Scripts

mgh/scripts contains helper scripts to get this project running *inside* a
Jailhouse-enabled QEMU image.


### Docs

mgh/docs contains additional external documents and resources.