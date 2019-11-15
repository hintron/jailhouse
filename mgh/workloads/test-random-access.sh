#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

bin="./build/random-access"
TMP=random-access-tmp.txt
RET_CODE=0

echo "test" > $TMP
result=$($bin $TMP)
if [ "$result" != "231" ]; then
    echo "FAILURE: $result != 231"
    RET_CODE=1
fi

echo "laksjdflkajsd;" > $TMP
result=$($bin $TMP)
if [ "$result" != "1070" ]; then
    echo "FAILURE: $result != 1070"
    RET_CODE=1
fi

echo "   " > $TMP
result=$($bin $TMP)
if [ "$result" != "0" ]; then
    echo "FAILURE: $result != 0"
    RET_CODE=1
fi

echo "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nam erat orci, ultricies dapibus blandit nec, viverra id felis. Morbi semper elementum ornare. Mauris sit amet eros nulla. Praesent tortor leo, efficitur quis nisi vitae, tincidunt fringilla nisl. In et tincidunt nisl, in pellentesque justo. Morbi vitae bibendum tortor. Mauris feugiat vulputate risus sit amet bibendum. Cras sodales, orci vel hendrerit dapibus, massa risus placerat nulla, vitae suscipit purus lacus convallis ex. Maecenas tempor mollis nisi et tincidunt. Suspendisse justo massa, pretium ac nibh a, sollicitudin eleifend elit. Fusce ullamcorper non augue sed condimentum." > $TMP
result=$($bin $TMP)
if [ "$result" != "62411" ]; then
    echo "FAILURE: $result != 62411"
    RET_CODE=1
fi

# Give it a good 100 million random bytes to process
head -c 100000000 < /dev/urandom > $TMP
result=$($bin $TMP)

rm $TMP
exit $RET_CODE
