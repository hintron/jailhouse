[Back to README-MGH.md](../README-MGH.md)
# UIO Kernel Module

TODO:

To build:

    make

To autoload on next boot:

    make install

To install ad-hoc, without boot:

    modprobe uio
    insmod uio_kernel_module/uio_ivshmem.ko

