#!/bin/bash -x
#script to create and mount a pmemdir
#requires size as input
#xfs
#run ./umount_ext4ramdisk.sh #NUMANODENUM

sudo umount /mnt/ext4ramdisk$1
sudo rm -rf /mnt/ramdisk$1/ext4.image
sudo umount /mnt/ramdisk$1
