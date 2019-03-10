#!/bin/bash

# Compare my borrowed sha3 code to a 3rd-party tool (RHash)

# To install rhash,
# sudo apt install rhash

function rhash_sha3_512 {
    # Remove trailing characters from rhash output
    trailing=" (stdin)"
    out="$(printf "$1" | rhash --sha3-512 -)"
    out=${out%$trailing}
    echo $out
}
# See https://stackoverflow.com/questions/9018723/what-is-the-simplest-way-to-remove-a-trailing-slash-from-each-parameter

######################################################
# Test rhash and mgh against some known test vectors
#
# See https://www.di-mgt.com.au/sha_testvectors.html
######################################################
# gold test vectors
# "" - empty string
A_IN=""
A_GOLD="a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26"
# "abc"
B_IN="abc"
B_GOLD="b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0"

RHASH_FAILED=""
MGH_FAILED=""

A_RHASH_OUT=$(rhash_sha3_512 "$A_IN")
if [ "$A_RHASH_OUT" != "$A_GOLD" ]; then
    echo "rhash failed test \"$A_IN\"!"
    printf "    rhash:$A_RHASH_OUT \n    gold :$A_GOLD\n"
    RHASH_FAILED="FAILED"
else
    echo "rhash: Test A Passed"
fi
B_RHASH_OUT=$(rhash_sha3_512 "$B_IN")
if [ "$B_RHASH_OUT" != "$B_GOLD" ]; then
    echo "rhash failed test \"$B_IN\"!"
    printf "    rhash:$B_RHASH_OUT \n    gold :$B_GOLD\n"
    RHASH_FAILED="FAILED"
else
    echo "rhash: Test B Passed"
fi

A_MGH_OUT=$(mgh-sha3-512 "$A_IN")
if [ "$A_MGH_OUT" != "$A_GOLD" ]; then
    echo "mgh failed test \"\"!"
    printf "    rhash:$A_MGH_OUT \n    gold :$A_GOLD\n"
    MGH_FAILED="FAILED"
else
    echo "mgh: Test A Passed"
fi
B_MGH_OUT=$(mgh-sha3-512 "$B_IN")
if [ "$B_MGH_OUT" != "$B_GOLD" ]; then
    echo "mgh failed test \"\"!"
    printf "    rhash:$B_MGH_OUT \n    gold :$B_GOLD\n"
    MGH_FAILED="FAILED"
else
    echo "mgh: Test B Passed"
fi

# Test MGH against rhash output
test_strings=(
    # Some more test vectors
    "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"
    "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu"
    "1"
    "ldskjfsakjdflksadflkasdflksadfljsadlkfjaslkdjflaksdjflkasfl;kjasdlfkjasld;kfjal;ksdflkwoioi23jur08923tfr9uj09fuwaopkwakf3[2eo\]2p]3[r4pq2-tr0ew98ufoisjfasl;kdf"
    "password"
    "1234567890120394801293498127319082350981273"
)

for i in ${test_strings[@]}; do
    RHASH_OUT=$(rhash_sha3_512 "${i}")
    MGH_OUT=$(mgh-sha3-512 "${i}")

    if [ "$RHASH_OUT" != "$MGH_OUT" ]; then
        echo "Failure: rhash and mgh differ on string \"${i}\"!:"
        echo "rhash: $RHASH_OUT"
        echo "mgh  : $MGH_OUT"
        # Assume we are the ones to blame
        $MGH_FAILED="FAILED"
    else
        echo "rhash and mgh match for string \"${i}\""
    fi

done


if [ ! -z $RHASH_FAILED ]; then
    echo "rhash FAILED!"
else
    echo "rhash passed"
fi

if [ ! -z $MGH_FAILED ]; then
    echo "mgh FAILED!"
else
    echo "mgh passed"
fi



