#!/bin/bash -x
#script to create and mount a pmemdir
#requires size as input
#xfs
#PREFIX="numactl --membind=0"
#DISKSZ=58000
DISKSZ=$1
NODENAME=$2

let scount="$1*1024"
echo $scount

#rm -rf $APPBENCH/shared_data
sudo umount /mnt/ext4ramdisk$NODENAME
sudo umount /mnt/ramdisk$NODENAME

sudo rm -rf /mnt/ramdisk/ext4$NODENAME.image

sudo mkdir /mnt/ramdisk$NODENAME
sudo mount -t ramfs /mnt/ramdisk$NODENAME
sudo $PREFIX dd if=/dev/zero of=/mnt/ramdisk/ext4$NODENAME.image bs=1M count=$scount
sudo $PREFIX mkfs.ext4 -F /mnt/ramdisk/ext4$NODENAME.image
sudo mkdir /mnt/ext4ramdisk$NODENAME
sudo mount -o loop /mnt/ramdisk/ext4$NODENAME.image /mnt/ext4ramdisk$NODENAME
sudo chown -R $USER /mnt/ext4ramdisk$NODENAME
