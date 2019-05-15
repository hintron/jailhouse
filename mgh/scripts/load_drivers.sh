#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
./load_jailhouse_driver.sh
./load_uio_driver.sh