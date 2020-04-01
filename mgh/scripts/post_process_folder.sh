#!/bin/bash
source ./common.sh > /dev/null

# Run post_process.sh for every folder in parent_dir.
# Post process each folder in place.

parent_dir="$1"

# Allow the input data directory to be a relative path
case $parent_dir in
    /*) ;;
    *) parent_dir="$(pwd)/$parent_dir" ;;
esac


for folder in $parent_dir/*; do
    ./post_process.sh "$folder" same
done
