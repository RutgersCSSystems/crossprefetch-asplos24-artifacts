#!/bin/bash -x
#script to create and mount a pmemdir
#requires size as input
#xfs
sudo umount /mnt/ext4ramdisk
sudo rm -rf /mnt/ramdisk/ext4.image
sudo umount /mnt/ramdisk
