#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

cd ../..
make
sudo make install
cd mgh/uio-kernel-module
make
sudo make install
