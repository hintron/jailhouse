#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

cd ../..
make CC=gcc-7 > /dev/null
sudo make install CC=gcc-7 > /dev/null
cd mgh/uio-kernel-module
make > /dev/null
sudo make install > /dev/null
