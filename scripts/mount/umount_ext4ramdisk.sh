#!/bin/bash -x
#script to create and mount a pmemdir
#requires size as input
#xfs
NODE=$1
sudo umount /mnt/ext4ramdisk$NODE
sudo rm -rf /mnt/ramdisk/ext4$NODE.image
sudo umount /mnt/ramdisk$NODE
rm -rf $SHARED_DATA
mkdir $SHARED_DATA
