#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
printf "\nLoaded Drivers:\n"
./load_jailhouse_driver.sh
./load_uio_driver.sh