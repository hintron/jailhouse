#!/bin/bash
source ./common.sh
input_file="__tmp.txt"

while true; do
    create_random_file_max $input_file
    clear_sync_byte_shmem
    send_inmate_input $input_file
done

