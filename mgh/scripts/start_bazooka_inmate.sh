#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
echo "MGH: Starting Bazooka inmate"
sudo ../../tools/jailhouse cell create ../../configs/x86/bazooka-inmate.cell
sudo ../../tools/jailhouse cell load bazooka-inmate ../../inmates/demos/x86/mgh-demo.bin
sudo ../../tools/jailhouse cell start bazooka-inmate