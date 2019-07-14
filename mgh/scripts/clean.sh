#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

cd ../..
make clean
cd mgh/uio-kernel-module
make clean
