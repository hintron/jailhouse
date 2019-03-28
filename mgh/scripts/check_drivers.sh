#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
lsmod | grep -i jail
lsmod | grep -i uio