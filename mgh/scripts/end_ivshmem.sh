#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
sudo ../../tools/jailhouse cell destroy ivshmem-demo
