[Back to README-MGH.md](../README-MGH.md)

# Docs

* [setup-build-linux.md](docs/setup-build-linux.md).
* [setup-generate-image-files.md](docs/setup-generate-image-files.md).
* [setup-host.md](docs/setup-host.md).
* [setup-inside-qemu-image.md](docs/setup-inside-qemu-image.md).

# QEMU Quickstart

To get Jailhouse running on x86 in QEMU, you need 4 things:

* QEMU > 2.8 - specifically the qemu-system-x86_64 binary
* A Jailhouse-enabled Linux kernel (vmlinuz) image file (ideally created via Jailhouse
images)
* The corresponding initrd image file
* A QEMU img file (ideally created via Jailhouse images)

The script _start-qemu-x86.sh_ expects to find these in the following four
places, respectively:

* _link/qemu_
* _link/kernel_
* _link/initrd_
* _link/img_

Create these using symbolic links.

To boot up the QEMU img, simply do:

    ./start-qemu-x86.sh

This requires sudo access.

Note that in order to build Jailhouse, you will also need to install the proper
Linux headers. See [setup-qemu-image.md].