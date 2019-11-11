#!/bin/bash
source ./common.sh
################################################################################
# Set inputs here
################################################################################
################################################################################
INMATE_CELL=../../configs/x86/apic-demo.cell
INMATE_NAME=apic-demo
INMATE_PROGRAM=../../inmates/demos/x86/apic-demo.bin
################################################################################
start_inmate $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE"
