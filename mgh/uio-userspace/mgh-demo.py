#!/usr/bin/python3

#######################
# Shared memory layout:
#######################
# Byte 0: a u8 with the following values:
#   If 0, the inmate has not yet been initialized.
#   If 1, the inmate is initialized and ready for (more) work.
#   If 2, Tells the inmate to calculate the sha3 of byte 2-(N+1). This will
#         immediately set byte 0 to 3.
#   If 3, the inmate is currently calculating sha3.
# Byte 1: a u8 of how many bytes of data to hash for a max of 256 characters.
#         Make space for an additional a null character in shmem for ease of
#         printing, making a total of 257 bytes.
# Byte 2-258: the input data (checking for maximum shmem limit).
# Byte 259-322: the output data (512-bit, 64-byte binary hash)

#################################
# How this demo will work:
#################################
# The root cell checks byte 0 to see if it's 1, indicating that the inmate is
# up and running.
# The root cell write the input to shmem.
# The root cell sets byte 0 to 2, indicating to inmate that data is ready.
# The inmate is constantly polling byte 0.
# If it's 2, inmate sets the byte to 3 (work in progress)
# Inmate then computes a SHA3 hash of the input from shmem
# Inmate writes the result to shmem
# Inmate sets byte to 1, indicating computation is finished and ready for work.
# Inmate sends interrupt to root cell, indicating that it's done.
# Repeat

import sys
import time
import mmap
import os
import struct

device_file = '/dev/uio0'

PAGE_SIZE = 4096
MAX_INPUT_BYTES = 256
OUTPUT_BYTES = 64

# Map out shared memory (define the sizes)
PING_SIZE = 1
LENGTH_SIZE = 1
IN_SIZE = MAX_INPUT_BYTES
OUT_SIZE = OUTPUT_BYTES
NULL_SIZE = 1

OFFSET_PING = 0
OFFSET_LENGTH = OFFSET_PING + PING_SIZE
OFFSET_IN = OFFSET_LENGTH + LENGTH_SIZE
OFFSET_NULL = OFFSET_IN + IN_SIZE
OFFSET_OUT = OFFSET_NULL + NULL_SIZE


def main(argv):
    if len(sys.argv) != 2:
        print("Usage: mgh-demo.py <string>")
        sys.exit(0)
    elif argv[1] == "test":
        print("Put test code here")
        sys.exit(0)
    else:
        data_to_calculate = argv[1]

    f = open(device_file, 'r+b')
    shmem = mmap.mmap(f.fileno(), PAGE_SIZE, offset=PAGE_SIZE)
    # shmem = bytearray.fromhex('deadbeef')

    # Test read
    print("Shmem content (first 30 bytes): '%s'" % shmem.read(30))


    # Check to make sure inmate is ready
    while not is_inmate_ready(shmem):
        time.sleep(1)

    while True:
        # # Place input in shared memory
        write_input(shmem, data_to_calculate)

        # Tell inmate to calculate it
        signal_inmate(shmem)

        # Block on inmate until it is done
        pend_inmate(device_file)

        # Read the sha3 output
        read_output(shmem)

        # Wait for a second, for good measure
        time.sleep(1)

    close(f)
    close(shmem)

# # Waits on an interrupt from the inmate to know the sha3 is complete
def is_inmate_ready(shmem):
    if shmem[OFFSET_PING] == 1:
        print("Inmate is ready!")
        return True
    else:
        print("Inmate is not yet ready...")
        return False

# Takes a string and puts it into shmem
def write_input(shmem, string):
    print("Sending inmate string '%s' (not including null)" % string)
    str_bytes = bytearray(string, 'utf-8')
    str_bytes_len = len(str_bytes)
    print("Sending byte string of length %d" % str_bytes_len)
    if str_bytes_len > MAX_INPUT_BYTES:
        print("error: string too long; length > %d)" % MAX_INPUT_BYTES)
        sys.exit(1)

    shmem[OFFSET_LENGTH] = str_bytes_len
    # Append an extra +1 to account for python's slice syntax
    shmem[OFFSET_IN:(OFFSET_IN+(str_bytes_len-1))+1] = str_bytes

# The inmate will wait until we write 2 to byte 0 of shmem
def signal_inmate(shmem):
    print("Signaling inmate...")
    shmem[OFFSET_PING] = 2

# Waits on an interrupt from the inmate to know the sha3 is complete
def pend_inmate(device_file):
    fd = os.open(device_file, os.O_RDWR)
    # Read out 4 bytes into an int
    interrupt_count = struct.unpack('i', os.read(fd, 4))
    print("interrupt #%s" % interrupt_count)
    os.close(fd)

# Waits on an interrupt from the inmate to know the sha3 is complete
def read_output(shmem):
    # Append an extra +1 to account for python's slice syntax
    output = shmem[OFFSET_OUT:(OFFSET_OUT+(OUTPUT_BYTES-1))+1]
    print('Shmem content: %s' % output.hex())

if __name__ == "__main__":
    main(sys.argv)

# References:
# https://docs.python.org/3.7/library/mmap.html
# https://stackoverflow.com/questions/1035340/reading-binary-file-and-looping-over-each-byte
# https://stackoverflow.com/questions/4041238/why-use-def-main
# https://stackoverflow.com/questions/6624453/whats-the-correct-way-to-convert-bytes-to-a-hex-string-in-python-3
# https://docs.python.org/3/library/stdtypes.html#bytearray
# https://stackoverflow.com/questions/16006165/why-is-discarding-the-volatile-qualifier-in-a-function-call-a-warning
# https://stackoverflow.com/questions/8201955/python-does-it-have-a-argc-argument
# https://stackoverflow.com/questions/7585435/best-way-to-convert-string-to-bytes-in-python-3
# https://docs.python.org/3/library/os.html
# https://stackoverflow.com/questions/1163459/reading-integers-from-binary-file-in-python
#