#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
sudo ../uio-userspace/mgh-demo.py 0 -d
