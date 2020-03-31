#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

function print_hex_file {
    local file="$1"
    hexdump -v -e '/1 "%02x"' $file
    echo ""
}

bin="./build/prng"

rm tmp.txt

result0=$($bin 10 10)
rc0=$?
if [[ $rc0 == 0 ]]; then
    echo "FAILURE: Test 0 returned $rc0"
    exit 1
fi

result1=$($bin 12 12 tmp.txt)
rc1=$?

result1_hex=$(print_hex_file tmp.txt)

if [[ $rc1 != 0 ]]; then
    echo "FAILURE: Test 1 returned $rc1"
    exit 1
fi

result2=$($bin 12 12)
rc2=$?

if [[ $rc2 != 0 ]]; then
    echo "FAILURE: Test 2 returned $rc2"
    exit 1
fi

if [[ $result1_hex != $result2 ]]; then
    echo "FAILURE: Test 1 and test 2 outputs differ"
    echo "FAILURE: result1_hex: $result1_hex"
    echo "FAILURE: result2: $result2"
    exit 1
fi

result3=$($bin 12)
rc3=$?

if [[ $rc3 == 0 ]]; then
    echo "FAILURE: Test 3 returned $rc3"
    exit 1
fi

result4=$($bin 12 12 12 12)
rc4=$?
if [[ $rc4 == 0 ]]; then
    echo "FAILURE: Test 4 returned $rc4"
    exit 1
fi

rm tmp.txt


result5=$($bin 20971520 12 tmp.txt)
rc4=$?
if [[ $rc4 != 0 ]]; then
    echo "FAILURE: Test 4 returned $rc4"
    exit 1
fi

rm tmp.txt

echo "SUCCESS: All tests passed for prng!"
exit 0
