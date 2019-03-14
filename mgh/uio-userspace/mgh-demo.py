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
# Byte 1: a u8 of how many bytes of data to hash (for a max of 256 bytes)
#         TODO: support k, m, g so I can have the inmate sha3 large files?
# Byte 2-257: the input data (checking for maximum shmem limit).
# Byte 258-321: the output data (512-bit, 64-byte binary hash)

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

device_file = '/dev/uio0'

def main(argv):
    if len(sys.argv) != 2:
        print("Usage: mgh-demo.py <string>")
        sys.exit(0)
    elif argv[1] == "test":
        file = open(device_file, 'r+b')
        output = file.read()
        print("interrupt #%s" % output)
        sys.exit(0)
    else:
        data_to_calculate = argv[1]

    f = open(device_file, 'r+b')
    shmem = mmap.mmap(f.fileno(), 4096, offset=4096)
    # shmem = bytearray.fromhex('deadbeef')

    # Test read
    print("Shmem content: '%s'" % shmem.read(30))


    # Check to make sure inmate is ready
    while not is_inmate_ready(shmem):
        time.sleep(1)

    while True:
        # # Place input in shared memory
        write_input(shmem, data_to_calculate)

        # Tell inmate to calculate it
        signal_inmate(shmem)

        # TODO: This isn't working quite yet... is it needed?
        # # Block on inmate until it is done
        # pend_inmate(f)

        # Read the sha3 output
        read_output(shmem)

        # Wait for a second, for good measure
        time.sleep(1)

    close(f)
    close(shmem)

# # Waits on an interrupt from the inmate to know the sha3 is complete
def is_inmate_ready(shmem):
    if shmem[0] == 1:
        print("Inmate is ready!")
        return True
    else:
        print("Inmate is not yet ready...")
        return False

# Takes a string and puts it into shmem
def write_input(shmem, string):
    print("Sending inmate string '%s'" % string)
    if len(string) > 256:
        print("error: string too long")
        sys.exit(1)

    shmem[1] = len(string) + 1
    # need to specify 1 past end to get 256 bytes
    shmem[2:len(string)+2] = bytearray(string, 'utf-8')

# The inmate will wait until we write 2 to byte 0 of shmem
def signal_inmate(shmem):
    print("Signaling inmate...")
    # Reads must be 4 bytes?
    shmem[0] = 2

# Waits on an interrupt from the inmate to know the sha3 is complete
def pend_inmate(file):
    interrupt_count = file.read(4)
    print("interrupt #%d" % interrupt_count)

# Waits on an interrupt from the inmate to know the sha3 is complete
def read_output(shmem):
    output = shmem[258:322] # need to specify 1 past end to get 64 bytes
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
#