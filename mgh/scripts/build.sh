#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

cd ../..
make > /dev/null
sudo make install > /dev/null
cd mgh/uio-kernel-module
make > /dev/null
sudo make install > /dev/null
