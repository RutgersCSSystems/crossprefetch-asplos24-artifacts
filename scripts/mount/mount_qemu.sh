#!/bin/bash
set -x
#Next, mount your image to the directory
mkdir $MOUNT_DIR
sudo mount -o loop $QEMU_IMG_FILE $MOUNT_DIR
cd $MOUNT_DIR
sudo chroot .
