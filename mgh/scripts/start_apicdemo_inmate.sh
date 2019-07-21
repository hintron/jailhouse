#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
echo "MGH: Starting apic-demo inmate"
sudo ../../tools/jailhouse cell create ../../configs/x86/apic-demo.cell
sudo ../../tools/jailhouse cell load apic-demo ../../inmates/demos/x86/apic-demo.bin
sudo ../../tools/jailhouse cell start apic-demo