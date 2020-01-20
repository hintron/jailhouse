README - Hintron Fork of Jailhouse
====================================

## Overview

The goal of this project is to use Jailhouse to get a real-time workload running
in an inmate alongside a Linux root cell and see how isolated the cells are.
In addition, we investigate whether a root cell throttling technique can improve
this isolation when the root cell is running an 'interference workload.'

## Components

### Jailhouse

This fork is currently based on Jailhouse 0.11, plus some upstream commits.
In addition, we have modified Jailhouse to use the VMX preemption timer
mechanism to do optional throttling of the root cell.

##### Bazooka Demo

The Bazooka demo is an inmate demo configured to run on my x86-64 Intel Kubuntu
19.10 machine named "bazooka." It is based on the
[apic-demo](../inmates/demos/x86/apic-demo.c) and
[ivshmem-demo](../inmates/demos/x86/ivshmem-demo.c) inmate demos.

The root cell config is at
[_bazooka-root.c_](../configs/x86/bazooka-root.c),
and the inmate cell config is at
[_bazooka-inmate.c_](../configs/x86/bazooka-inmate.c). These will compile down
to _bazooka-root.cell_ and _bazooka-inmate.cell_, respectively.
The root cell config was based off of the following command:

    sudo ./tools/jailhouse config create --console ttyS4 <output_filename>

Some modifications were needed to fix some trouble spots, including incomplete
memory configuration masks for the NVIDIA GPU on Bazooka.

The program run in the inmate is
[_mgh-demo.c_](../inmates/demos/x86/mgh-demo.c), which compiles down to
_mgh-demo.bin_. This is the same inmate program that the QEMU and Inspiron demos
run.

Helper scripts have been used to streamline running the demo.
[_start_experiments.sh_](scripts/start_experiments.sh) is the highest-level
script, used to start multiple experiment one right after the other. This script
calls [_start_experiment.sh_](scripts/start_experiment.sh) for each experiment,
which builds everything, starts up Jailhouse, runs the selected workload,
records the output, and cleans everything up.
Many of the functions used for this have been placed in
[_common.sh_](scripts/common.sh).

There are other features as well, such as running the workload in Linux only,
running a Linux workload under Jailhouse or not, running a Linux workload
under Intel VTune, running the workload with an interference workload running
in Linux, determining the throttling mechanism, determining how many iterations
to run, determining what input files or input size ranges to use, whether to
disable Turbo Boost in Linux, and other options.

To manually start the root and inmate, along with the UIO infrastructure needed
for the IVSHMEM shared memory channel, cd to the _mgh/scripts_ directory and
do the following:

    ./clean.sh
    ./build.sh
    ./load_drivers.sh
    ./start_bazooka_root.sh
    ./start_bazooka_inmate.sh

By default, this will start the inmate with an alternating throttle, where it
will throttle the root on and off every 15 seconds.

To see the output of Jailhouse in real time, in a separate terminal do:

    sudo jailhouse console -f

Optionally start an interference workload in a separate terminal to keep the
root busy. E.g., encode a Blu-ray video file with handbrake:

    ./start_handbrake.sh

Also, optionally monitor core frequencies in a separate terminal using CoreFreq
with this script:

    ./start_corefreq.sh

Then, use [_mgh-demo.py_](uio-userspace/mgh-demo.py) to send input to the inmate
over a shared memory channel. This is a userspace program that uses the UIO
driver mechanism. The following script will continually feed the inmate the
largest random file that will fit over the currently-defined shared memory
channel configured in the bazooka cell configs:

    ./userspace_loop.sh

After closing out _userspace_loop.sh_, the interference workload, and CoreFreq,
do the following to clean up:

    ./end_inmate.sh
    ./end_root.sh
    ./remove_drivers.sh

To stop the inmate only and prevent any more root cell throttling, just do:

    ./end_inmate.sh

Currently, the only supported interference workload is Handbrake, and it's set
to encode a specific Blu-ray file.

##### Inspiron Demo

(NOTE: This likely doesn't work right now).

The Inspiron demo is an inmate demo configured to run on my x86-64 Intel
Kubuntu 19.10 Dell Inspiron laptop.

[_inspiron-root.c_](../configs/x86/inspiron-root.c) and
[_inspiron-inmate.c_](../configs/x86/inspiron-inmate.c) are the root and inmate
cell configuration files, respectively.


##### QEMU Demo

(NOTE: This doesn't work right now, since the configs aren't updated).

The root config is [_qemu-mgh.c_](../configs/x86/to-port/qemu-mgh.c)
(based off of [_qemu-x86.c_](../configs/x86/qemu-x86.c)).
This file tells Jailhouse what
resources are available on the system for Jailhouse to partition. It creates a
file called _qemu-mgh.cell_ that is used by the `jailhouse cell create` command
to actually instantiate the root cell.

[_mgh-demo.c_](../configs/x86/to-port/mgh-demo.c) is the real-time cell's
resource configuration. It creates a file
called _mgh-demo.cell_ that is used by the `jailhouse cell create` command to
instantiate/partition the real-time cell (inmate). It's based off of
[_ivshmem-demo.c_](../configs/x86/ivshmem-demo.c).

[_mgh-demo.c_](../inmates/demos/x86/mgh-demo.c) is the main code
of the real-time inmate cell. This will generate mgh-demo.bin and is the
"program" loaded into the inmate via the `jailhouse cell load` command.
It has access to any resources specified in _mgh-demo.cell_. It's based off of
[_ivshmem-demo.c_](../inmates/demos/x86/ivshmem-demo.c).

The root cell and inmate communicate over the Jailhouse ivshmem virtual PCI
device. The root Linux Jailhouse cell will use the uio-kernel-module and
uio-userspace code to talk to the inmate over this virtual PCI device from
Linux. The inmate will use the Jailhouse API directly to talk to the root cell
through the virtual PCI device.


### Docs

[_mgh/docs_](mgh/docs) contains additional external documents and resources.

See [_docs/README.md_](docs/README.md) for a listing of these resources.


### QEMU

[_mgh/qemu_](mgh/qemu) contains helper scripts and documentation to create and
run Jailhouse-enabled QEMU images on any machine.

Images are created via the
[jailhouse-images](https://github.com/siemens/jailhouse-images) project.

See [qemu/README.md](qemu/README.md) for more information.


### Scripts

[_mgh/scripts_](mgh/scripts) contains helper scripts to get this project running *inside* a
Jailhouse-enabled QEMU image.


### UIO IVSHMEM Kernel Module

[_mgh/uio-kernel-module_](mgh/uio-kernel-module) contains a uio_ivshmem kernel
module that enables a Linux root cell to talk to an inmate in Jailhouse. This
uses the UIO kernel module framework.

Code is adapted from https://github.com/henning-schild-work/ivshmem-guest-code,
specifically the "jailhouse" branch.

See [_uio-userspace/README.md_](uio-userspace/README.md) for how to build and
install.


### UIO Userspace Programs

[_mgh/uio-userspace_](mgh/uio-userspace) contains userspace programs that the
Linux root cell can use to interact with the UIO Kernel Module

Code is forked from https://github.com/henning-schild-work/ivshmem-guest-code,
specifically from the "jailhouse" branch.

See [_uio-userspace/README.md_](uio-userspace/README.md) for how to build and
run.


### Workloads

[_mgh/workloads_](mgh/workloads) contains code for various workloads to run in both the inmate and
in Linux under the root cell.

 simple SHA 3 implementation to be used by mgh-demo.c.

See [_mgh/README.md_](mgh/README.md) for more information.

## Issues

Check the GitHub issue tracker for TODO items, wish list items, bugs, and other
issues.