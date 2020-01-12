#!/bin/bash
SRC="/home/hintron/code/CoreFreq"
cd $SRC

make clean
make
sudo make install
