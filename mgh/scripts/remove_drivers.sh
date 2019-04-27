#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
./remove_jailhouse_driver.sh
./remove_uio_driver.sh