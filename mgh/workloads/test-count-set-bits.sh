#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# Compare my borrowed sha3 code to a 3rd-party tool (RHash)
bin="./build/count-set-bits"

# Give it a good 100 million random bytes to process (to see the time difference
# between the methods!). On Bazooka, this takes about 5 seconds, 4 seconds, and
# 1 second for mode 0, 1, and 2, respectively.
head -c 100000000 < /dev/urandom > tmp.txt

$bin tmp.txt
RET_CODE=$?

rm tmp.txt

exit $RET_CODE
