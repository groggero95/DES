#!/usr/bin/env bash

# Set and create folders
src=$HOME/Desktop/DES
tmp=/tmp/$USER/DES
mkdir -p $tmp/syn $tmp/C

# Synthesis
cd $tmp/syn
vivado -mode batch -source $src/Desktop/DES/des_cracker.syn.tcl -notrace
cd $tmp/syn
bootgen -w -image $src/DES/boot.bif -o ../boot.bin
