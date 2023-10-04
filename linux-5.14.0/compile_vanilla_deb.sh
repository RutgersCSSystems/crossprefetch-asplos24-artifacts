#!/bin/bash -x
sudo apt update; sudo apt-get install -y libdpkg-dev kernel-package libncurses-dev

PROC=`nproc`
export CONCURRENCY_LEVEL=$PROC
export CONCURRENCYLEVEL=$PROC

touch REPORTING-BUGS
sudo make clean -j
#sudo cp original.config .config
make menuconfig
sudo make prepare
sudo make -j$PROC
sudo fakeroot make-kpkg -j$PROC --initrd kernel-image kernel-headers
sudo dpkg -i ../*image*.deb ../*header*.deb
exit
