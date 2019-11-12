#!/bin/bash
source ./common.sh
input_file="__tmp.txt"
while true; do
    create_random_file_max $input_file
    send_inmate_input $input_file
done

