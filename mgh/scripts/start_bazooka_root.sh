#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
VERSION=$(../../tools/jailhouse --version)
echo "MGH: Starting Bazooka root cell in $VERSION"
sudo ../../tools/jailhouse enable ../../configs/x86/bazooka-root.cell