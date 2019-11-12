#!/bin/bash
source ./common.sh
################################################################################
# Set inputs here
################################################################################
################################################################################
INMATE_CELL=../../configs/x86/bazooka-inmate.cell
INMATE_NAME=bazooka-inmate
INMATE_PROGRAM=../../inmates/demos/x86/mgh-demo.bin
################################################################################
# To use defaults, comment out and leave unset.
# See common.sh --> set_cmdline
################################################################################
# DEBUG_MODE="true"
# LOCAL_BUFFER="true"
# THROTTLE_MODE=$TMODE_DEADLINE
# THROTTLE_MECHANISM=$TMECH_CLOCK
WORKLOAD_MODE=$WM_COUNT_SET_BITS
# WORKLOAD_MODE=$WM_SHA3
# COUNT_SET_BITS_MODE=$CSBM_SLOW
COUNT_SET_BITS_MODE=$CSBM_FASTER
# POLLUTE_CACHE="true"
# Generate command line arguments based on input
INMATE_CMDLINE=$(set_cmdline)
################################################################################
start_inmate $INMATE_CELL $INMATE_NAME $INMATE_PROGRAM "$INMATE_CMDLINE"
