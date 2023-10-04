#!/bin/bash
set -x

sudo umount $MOUNT_DIR

#Compile the kernel
cd $KERN_SRC

sudo make clean
sudo make distclean
rm -rf $KERN_SRC/.config
#generate non-kvm config
sudo make menuconfig
