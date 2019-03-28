#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
sudo ../../tools/jailhouse cell create ../../configs/x86/inspiron-inmate.cell
sudo ../../tools/jailhouse cell load inspiron-inmate ../../inmates/demos/x86/mgh-demo.bin
sudo ../../tools/jailhouse cell start inspiron-inmate