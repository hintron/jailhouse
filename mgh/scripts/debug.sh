#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
# Run all the steps and print out the jailhouse console, so I can see what the problem is

# OUTPUT=startup.out

echo "Starting debug.sh..."
 # > $OUTPUT 2>&1

./load_jailhouse_driver.sh
 # >> $OUTPUT 2>&1
./load_uio_kernel_module.sh
 # >> $OUTPUT 2>&1
# ./check_drivers.sh >> $OUTPUT 2>&1
./start_inspiron_root.sh
 # >> $OUTPUT 2>&1

# ../../tools/jailhouse console >> $OUTPUT 2>&1
# while true; do
#     echo `date '+%Y-%m-%d %H:%M:%S'` >> $OUTPUT 2>&1
#     echo "*************************************************" >> $OUTPUT 2>&1
#     ../../tools/jailhouse console >> $OUTPUT 2>&1
#     sleep 5;
# done
