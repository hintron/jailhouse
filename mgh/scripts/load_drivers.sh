#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
./sign_drivers.sh
./load_jailhouse_driver.sh
./load_uio_kernel_module.sh