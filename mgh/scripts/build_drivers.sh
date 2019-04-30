#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

cd ../..
make
cd mgh/uio-kernel-module
make
