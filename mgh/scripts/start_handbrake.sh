#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit

# https://stackoverflow.com/a/19954510
TIMESTAMP=$(date +%s)

INPUT="/home/hintron/Videos/sources/i_am_legend.m2ts"
OUTPUT="/home/hintron/Videos/jailhouse_outputs/run_$TIMESTAMP"


HandBrakeCLI -i $INPUT -o $OUTPUT

# Delete output?

# Pass video file to sha function?

# Specify chapters with -c? Doesn't seem to work...