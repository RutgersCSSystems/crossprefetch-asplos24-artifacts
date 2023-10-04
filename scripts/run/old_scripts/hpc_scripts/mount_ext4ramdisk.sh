#!/bin/bash -x
set -x
#script to create and mount a pmemdir
#requires size as input
#xfs

##Run ./mount_ext4ramdisk #SIZE_MB #NUMANODE_NUM



scount="$1"
NUMANODE=$2
echo $scount

PREFIX="numactl --membind=$NUMANODE"

#rm -rf $APPBENCH/shared_data
sudo umount /mnt/ext4ramdisk$NUMANODE
sudo umount /mnt/ramdisk$NUMANODE
sudo rm -rf /mnt/ramdisk$NUMANODE/ext4.image
sudo mkdir /mnt/ramdisk$NUMANODE
sudo mount -t ramfs ramfs /mnt/ramdisk$NUMANODE

sleep 3

sudo $PREFIX dd if=/dev/zero of=/mnt/ramdisk$NUMANODE/ext4.image bs=1M count="$scount"
sudo $PREFIX mkfs.ext4 -F /mnt/ramdisk$NUMANODE/ext4.image
sudo mkdir /mnt/ext4ramdisk$NUMANODE
sudo mount -o loop /mnt/ramdisk$NUMANODE/ext4.image /mnt/ext4ramdisk$NUMANODE
sudo chown -R $USER /mnt/ext4ramdisk$NUMANODE
sleep 4
let imagesz=$scount-512
echo "imagesz: "$imagesz
fallocate -l $imagesz"M" /mnt/ext4ramdisk$NUMANODE/test.img
