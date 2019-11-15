#!/bin/bash
source ./common.sh

# https://stackoverflow.com/a/19954510
TIMESTAMP=$(timestamp)

INPUT="/home/hintron/Videos/sources/i_am_legend.m2ts"
OUTPUT="/home/hintron/Videos/jailhouse_outputs/run_$TIMESTAMP"

start_handbrake $INPUT $OUTPUT

# Delete output?

# Pass video file to sha function?

# Specify chapters with -c? Doesn't seem to work...