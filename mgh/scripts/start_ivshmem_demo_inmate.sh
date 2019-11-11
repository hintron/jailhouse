#!/bin/bash
source ./common.sh
################################################################################
# Set inputs here
################################################################################
################################################################################
INMATE_CELL=../../configs/x86/ivshmem-demo.cell
INMATE_NAME=ivshmem-demo
INMATE_PROGRAM=../../inmates/demos/x86/ivshmem-demo.bin
################################################################################
start_inmate $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE"
