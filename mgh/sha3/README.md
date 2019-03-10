# Overview

This is a simple SHA3 library, derived from
https://github.com/mjosaarinen/tiny_sha3/.

The aim for this simple SHA3 library is to be used in the mgh-demo inmate. Due
to mgh-demo running on bare metal (no OS), the code needs to be lean and not
rely on external code (or even libc!).

TODO: Add these files in to mgh_demo.c.
For mgh-demo to access `sha3_mgh.c`, the `include/`...

# Build instructions

To build:

    meson build
    ninja -C build

To install:

    sudo ninja install -C build

# Tests

These tests assume `rhash` is installed and on your path.

To install `rhash`, do the following (on Ubuntu):

    sudo apt install rhash

To test, simply run:

    ninja test -C build

or, alternatively:

    ./test.sh

