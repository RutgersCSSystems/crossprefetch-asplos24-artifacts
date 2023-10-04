#!/bin/bash -x
#script to create and mount a pmemdir
#requires size as input
#xfs
#PREFIX="numactl --membind=0"
DISKSZ=$1

sudo umount /mnt/ext4ramdisk
sudo mkdir /mnt/ramdisk
sudo mount -t ramfs ramfs /mnt/ramdisk
sudo $PREFIX dd if=/dev/zero of=/mnt/ramdisk/ext4.image bs=1M count=$DISKSZ
sudo $PREFIX mkfs.ext4 -F /mnt/ramdisk/ext4.image
sudo mkdir /mnt/ext4ramdisk
sudo mount -o loop /mnt/ramdisk/ext4.image /mnt/ext4ramdisk
sudo chown -R $USER /mnt/ext4ramdisk
