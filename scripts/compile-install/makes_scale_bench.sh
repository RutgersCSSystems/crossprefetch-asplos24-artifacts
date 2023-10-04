#!/bin/bash
set -x

BENCHMARKS="dirmaker gatling httpdbench sembench sockbench libowfat"
LINUX_SCALE_BENCH="/home/joo/NVM/linux-scalability-benchmark"

#Compile the kernel
cd $LINUX_SCALE_BENCH

MAKE(){
  cd $BENCH
  make 
  cd ..
}

for BENCH in $BENCHMARKS
do
  MAKE
done	
