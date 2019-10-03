#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
sudo ../uio-userspace/mgh-demo.py -l -f ../../hypervisor/arch/x86/lib-intel.a
