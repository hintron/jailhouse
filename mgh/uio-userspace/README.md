# UIO Userspace program

Run this program inside the root Linux cell in order to communicate with the
real-time inmate.

It assumes that these devices exist:

    /dev/uio0
    /sys/class/uio/uio0/device/resource0

To build:

    mkdir build
    cd build
    cmake ..

To run:

    ./uio-userspace

You will see that this program will modify shared memory, and that the inmate
will print this to the console.

To clean:

    cd ..
    rm -rf ./build


To see the shared memory string, you can also run this Python program:

    ./orig/shmem_test.py