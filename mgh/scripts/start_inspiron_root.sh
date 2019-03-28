#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
VERSION=$(../../tools/jailhouse --version)
echo "MGH: Starting $VERSION in QEMU"
sudo ../../tools/jailhouse enable ../../configs/x86/inspiron-root.cell