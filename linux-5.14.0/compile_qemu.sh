#!/bin/bash -x
sudo apt update; sudo apt-get install -y libdpkg-dev kernel-package libncurses-dev

PROC=`nproc`
export CONCURRENCY_LEVEL=$PROC
export CONCURRENCYLEVEL=$PROC

touch REPORTING-BUGS
sudo make clean -j
sudo cp modifiednix.config .config
sudo make prepare
sudo make -j$PROC
