[Back to README-MGH.md](../README-MGH.md)
# UIO Kernel Module

TODO:

To build:

    make

To autoload _uio_ivshmem.ko_ on next boot:

    make install

To install _uio_ivshmem.ko_ ad-hoc, without boot:

    modprobe uio
    insmod uio_kernel_module/uio_ivshmem.ko

