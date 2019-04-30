#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
./sign_drivers.sh
printf "\nLoaded Drivers:\n"
./load_jailhouse_driver.sh
./load_uio_driver.sh