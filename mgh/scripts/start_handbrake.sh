#!/bin/bash
source ./common.sh

INPUT="/home/hintron/code/jailhouse/mgh/scripts/sources/i_am_legend.m2ts"
OUTPUT="/home/hintron/code/jailhouse/mgh/scripts/output/handbrake-ad-hoc.out"
HandBrakeCLI -i $INPUT -o $OUTPUT
