#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
sudo ../uio-userspace/mgh-demo.py -i 0 -d
