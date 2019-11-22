#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

input="0"

while true; do
    sudo ../uio-userspace/mgh-demo.py -i $input
    input="${input}+"
done
