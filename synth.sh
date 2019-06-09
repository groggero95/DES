#!/usr/bin/env bash

# Set and create folders
src=`pwd`
tmp=/tmp/$USER/DES
mkdir -p $tmp/syn $tmp/C

# Synthesis
cd $tmp/syn
vivado -mode batch -source $src/des_cracker.syn.tcl -notrace
cd $tmp/syn
bootgen -w -image $src/boot.bif -o ../boot.bin
