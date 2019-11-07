# Overview

This contains various programs that can be used as workloads for an inmate.

Workloads include:

* SHA-3
* SHA-3 profile workload (for profilers)
* Bit count

# Build instructions

To build:

    meson build
    ninja -C build

To install:

    sudo ninja install -C build

# Tests

To test, simply run:

    ninja test -C build

That will automatically run the test-\*.sh shell scripts and only print output
when a test fails.

SHA3 tests require `rhash`. To install `rhash`, do the following (on Ubuntu):

    sudo apt install rhash

# Background

The SHA3 workloads are based on a simple SHA3 library found at
https://github.com/mjosaarinen/tiny_sha3/.

The aim for this SHA3 workload is to be used in the mgh-demo inmate. Due
to mgh-demo running on bare metal (no OS), the code needs to be lean and not
rely on external code (or even libc!).

sha3-mgh.c needs to be in the hypervisor code in order to be automatically
built and added into the inmate library.