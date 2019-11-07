#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# Compare my borrowed sha3 code to a 3rd-party tool (RHash)

# Test the locally-built binary instead of what's on the path
mgh_bin=./build/sha3-512-profile
RET_CODE=0

if hash rhash 2>/dev/null; then
    echo "rhash found"
else
    printf "rhash not found. Install it:\n\n    sudo apt install rhash\n\n"
    exit
fi

if [ -f $mgh_bin ] ; then
    echo "$mgh_bin found"
else
    printf "$mgh_bin not found. Build it with Meson:\n\n    meson build\n    ninja -C build\n\n"
    exit
fi

function rhash_sha3_512_hex {
    # Remove trailing characters from rhash output
    trailing=" (stdin)"
    out="$(printf "$1" | xxd -r -p | rhash --sha3-512 -)"
    out=${out%$trailing}
    echo $out
}


function rhash_sha3_512 {
    # Remove trailing characters from rhash output
    trailing=" (stdin)"
    out="$(printf "$1" | rhash --sha3-512 -)"
    out=${out%$trailing}
    echo $out
}

ITERATIONS=1000
ITERATIONS_REAL=$((($ITERATIONS-2) / 2))

# echo $ITERATIONS_REAL

RHASH_B=$(rhash_sha3_512 "testing")
RHASH_A=""
for ((i = 0; i < $ITERATIONS_REAL; i++)); do
    RHASH_A=$(rhash_sha3_512_hex "$RHASH_B")
    RHASH_B=$(rhash_sha3_512_hex "$RHASH_A")
done
RHASH_A=$(rhash_sha3_512_hex "$RHASH_B")

MGH_OUT=$($mgh_bin)

if [ "$RHASH_A" != "$MGH_OUT" ]; then
    echo "FAILURE: rhash and mgh differ!:"
    echo "    rhash: $RHASH_A"
    echo "    mgh  : $MGH_OUT"
    RET_CODE=1
else
    echo "rhash and mgh match"
fi

exit $RET_CODE
