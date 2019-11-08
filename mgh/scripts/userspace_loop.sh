#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# Create the maximum-sized input possible
# Current max size is (1 MB - 8)
size=$((2**20 - 8))


while true; do
    # See https://unix.stackexchange.com/questions/33629/how-can-i-populate-a-file-with-random-data
    head -c $size < /dev/urandom > __tmp.txt

    # Send input to inmate
    sudo ../uio-userspace/mgh-demo.py -f __tmp.txt
done

