#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# Compare my borrowed sha3 code to a 3rd-party tool (RHash)
bin="./build/count-set-bits"

# Give it a good 100 million random bytes to process (to see the time difference
# between the methods!). On Bazooka, this takes about 5 seconds, 4 seconds, and
# 1 second for mode 0, 1, and 2, respectively.
head -c 100000000 < /dev/urandom > tmp.txt

mode0_result=$($bin tmp.txt 0)
mode1_result=$($bin tmp.txt 1)
mode2_result=$($bin tmp.txt 2)
default_mode_result=$($bin tmp.txt)

RET_CODE=1
if [ "$mode0_result" != "$mode0_result" ] ||
   [ "$mode0_result" != "$mode1_result" ] ||
   [ "$mode0_result" != "$mode2_result" ] ||
   [ "$mode0_result" != "$default_mode_result" ]; then
    echo "Different modes gave different results!"
    echo "mode       0: $mode0_result"
    echo "mode       1: $mode1_result"
    echo "mode       2: $mode2_result"
    echo "mode default: $default_mode_result"
else
    # Everything checks out
    RET_CODE=0
fi

rm tmp.txt

exit $RET_CODE
