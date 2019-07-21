#!/usr/bin/python3

#######################
# Shared memory layout:
#######################
# Byte        0: Synchronization Byte. A u8 with the following values:
#   If 0, the inmate has not yet been initialized.
#   If 1, the inmate is initialized and ready for (more) work.
#   If 2, Tells the inmate to calculate the sha3 of byte 2-(N+1). This will
#         immediately set byte 0 to 3.
#   If 3, the inmate is currently calculating sha3.
# Byte      1-3: Reserved.
# Byte      4-7: Input Length. A u32 for the length of the input data.
# Byte     8-71: Output Data. 64 bytes (For 512-bit SHA3).
# Byte  72-4103: Reserved.
# Byte 4104-1MB: Input Data.

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
# Repeat

import sys
import time
import mmap
import os
import struct
import subprocess
import argparse

device_file = '/dev/uio0'

PAGE_SIZE = 4096
MB = 1 << 20 # 2^20 = 1048576 = 1 MB

# Map out shared memory (define the sizes)
SYNC_SIZE = 1
RES_1_SIZE = 3
IN_LEN_SIZE = 4
OUT_SIZE = 64
RES_2_SIZE = 4032
# The entire IVSHMEM region is 1 MB. Input Data gets the rest of the space.
IN_SIZE = MB - (SYNC_SIZE + RES_1_SIZE + IN_LEN_SIZE + OUT_SIZE + RES_2_SIZE)

OFFSET_SYNC = 0
OFFSET_RES_1 = OFFSET_SYNC + SYNC_SIZE
OFFSET_IN_LEN = OFFSET_RES_1 + RES_1_SIZE
OFFSET_OUT = OFFSET_IN_LEN + IN_LEN_SIZE
OFFSET_RES_2 = OFFSET_OUT + OUT_SIZE
OFFSET_IN = OFFSET_RES_2 + RES_2_SIZE

def main(args):
    if args.file:
        with open(args.input, 'rb') as f:
            input_data = f.read()
    else:
        input_data = args.input

    f = open(device_file, 'r+b')
    shmem = mmap.mmap(f.fileno(), MB, offset=PAGE_SIZE)
    # shmem = bytearray.fromhex('deadbeef')

    # Test read
    print("Shmem content (first 30 bytes): '%s'" % shmem.read(30))

    # Check to make sure inmate is ready
    while not is_inmate_ready(shmem):
        time.sleep(1)

    count = 0
    while True:
        if not args.file and args.demo:
            print("\nIteration %d" % count)
            print("***************************************************************")

        # Place input in shared memory
        if args.file:
            write_input_binary(shmem, input_data)
        else:
            write_input_str(shmem, input_data)

        # Tell inmate to calculate it
        signal_inmate(shmem)

        # Block on inmate until it is done
        pend_inmate_poll(shmem)

        # Read the sha3 output
        inmate_output = read_output(shmem).hex()
        print('Inmate output: %s' % inmate_output)

        if args.file:
            rhash_output = file_to_sha3(args.input)
        else:
            rhash_output = str_to_sha3(input_data)
        # TODO: Use this when taking in input files instead

        # Check to make sure the hash calculated by the inmate is accurate
        if inmate_output == rhash_output:
            print("\nOutput is correct")
        else:
            print("\nOutput **DOES NOT** match rhash!...\n%s" % rhash_output)

        if not args.file and args.demo:
            count += 1

            # Wait for a second, to slow down demo
            time.sleep(1)
            input_data = "%s%d" % (input_data, count)
        else:
            break

    f.close()
    shmem.close()

# # Waits on an interrupt from the inmate to know the sha3 is complete
def is_inmate_ready(shmem):
    if shmem[OFFSET_SYNC] == 1:
        print("Inmate is ready!")
        return True
    else:
        print("Inmate is not yet ready...")
        return False

# Takes a string and puts it into shmem
def write_input_str(shmem, input_str):
    return write_input_binary(shmem, bytearray(input_str, 'utf-8'))

# Takes a string and puts it into shmem
def write_input_binary(shmem, input_bytes):
    input_len = len(input_bytes)
    print("Input length: %d" % input_len)
    if input_len < 256:
        print("Input:")
        print(input_bytes)

    if input_len > IN_SIZE:
        print("error: Input data too long; length > %d bytes)" % IN_SIZE)
        sys.exit(1)

    shmem.seek(OFFSET_IN_LEN)
    shmem.write(input_len.to_bytes(4, "little"))
    # Append an extra +1 to account for python's slice syntax
    shmem[OFFSET_IN:(OFFSET_IN+(input_len-1))+1] = input_bytes

# The inmate will wait until we write 2 to byte 0 of shmem
def signal_inmate(shmem):
    print("Signaling inmate...")
    shmem[OFFSET_SYNC] = 2

# Polls until the bit becomes 3, indicating that the inmate is done
def pend_inmate_poll(shmem):
    while shmem[OFFSET_SYNC] != 1:
        print("Inmate is calculating...")
        time.sleep(1)

    # print("Inmate is finished, with ping=%d" % shmem[OFFSET_SYNC])
    print("Inmate is finished")

# Waits on an interrupt from the inmate to know the sha3 is complete
# Currently not used
def pend_inmate_intr(device_file):
    fd = os.open(device_file, os.O_RDWR)
    # Read out 4 bytes into an int
    interrupt_count = struct.unpack('i', os.read(fd, 4))
    print("interrupt #%s" % interrupt_count)
    os.close(fd)


# Requires rhash to be installed on the system
# `sudo apt install rhash`
# See mgh/sha3/test.sh


def str_to_sha3(string, str_mode=True):
    cmd = "printf %s | rhash --sha3-512 -" % string
    result = subprocess.run(cmd, shell=True, check=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    # Remove the trailing "  (stdin)"
    output = result.stdout.split()[0]
    if str_mode:
        output = output.decode("utf-8")
    return output

def file_to_sha3(file, str_mode=True):
    cmd = "rhash --sha3-512 %s" % file
    result = subprocess.run(cmd, shell=True, check=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    output = result.stdout.split()[0]
    if str_mode:
        output = output.decode("utf-8")
    return output

# Waits on an interrupt from the inmate to know the sha3 is complete
def read_output(shmem):
    # Append an extra +1 to account for python's slice syntax
    return shmem[OFFSET_OUT:(OFFSET_OUT+(OUT_SIZE-1))+1]

################################################################################
# ARGS
################################################################################

parser = argparse.ArgumentParser(
    description='Userspace tool to send workloads to a Jailhouse inmate over a IVSHMEM PCI device.',
)
parser.add_argument('input', metavar='INPUT', type=str, help='The input data to send to the inmate. If -f/--file is specified, INPUT is a filename with the input taken from the contents of the file. Otherwise, INPUT is interpreted as a string containing the input data.')
parser.add_argument('-f', '--file', dest='file', action='store_true', help='If True, INPUT is interpreted as a filename instead of a string. Defaults to False.')
parser.add_argument('-d', '--demo', dest='demo', action='store_true', help='If True, and if INPUT is a string instead of a file, demo mode is activated. This will continuously send the inmate a slightly changed string every second. Defaults to False.')
args = parser.parse_args()

if __name__ == "__main__":
    main(args)

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
# https://stackoverflow.com/questions/14043886/python-2-3-convert-integer-to-bytes-cleanly/29182294
# https://stackoverflow.com/questions/2294608/how-to-write-integer-number-in-particular-no-of-bytes-in-python-file-writing