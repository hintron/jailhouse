#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
sudo ../../tools/jailhouse cell create ../../configs/x86/mgh-demo.cell
sudo ../../tools/jailhouse cell load mgh-demo ../../inmates/demos/x86/mgh-demo.bin
sudo ../../tools/jailhouse cell start mgh-demo