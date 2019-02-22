# TODO:

* Get a userspace program to send interrupts to the inmate
    See https://groups.google.com/forum/#!searchin/jailhouse-dev/ivshmem|sort:date/jailhouse-dev/Lyw3PQlK_wU/N0IhKbNRDgAJ

* Figure out why mmap() of /dev/uio0 doesn't work for the first mem region

* Look into mmap() of

*

*


## docs

A collection of useful documentation.

## ivshmem

This directory contains a uio_ivshmem kernel module that enables the Linux root
cell to talk to a Jailhouse inmate.

Code is forked from https://github.com/henning-schild-work/ivshmem-guest-code,
specifically from the "jailhouse" branch.

## QEMU

This directory contains scripts and files related to starting up jailhouse in
QEMU.


