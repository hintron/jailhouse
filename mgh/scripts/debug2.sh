#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
# Run all the steps and print out the jailhouse console, so I can see what the problem is

OUTPUT=console.out

echo "Starting debug2.sh..." > $OUTPUT 2>&1

while true; do
    echo `date '+%Y-%m-%d %H:%M:%S'` >> $OUTPUT 2>&1
    echo "*************************************************" >> $OUTPUT 2>&1
    sudo ../../tools/jailhouse console >> $OUTPUT 2>&1
    sleep 1;
done
