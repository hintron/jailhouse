[Back to README-MGH.md](../README-MGH.md)
# UIO Kernel Module

To build:

    make

To autoload _uio_ivshmem.ko_ on next boot:

    sudo make install

To install _uio_ivshmem.ko_ ad-hoc, without boot:

    sudo modprobe uio
    sudo insmod uio_kernel_module/uio_ivshmem.ko

