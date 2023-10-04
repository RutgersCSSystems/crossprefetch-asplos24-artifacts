#!/bin/bash
set -x

DIR=$1
SIZE=$2G

let scount="$2*1024*1024"
echo $scount

DEFAULTSWAP="/dev/sda3"
sudo swapoff $DEFAULTSWAP


sudo swapoff $DIR/swapfile
sudo rm -rf $DIR/swapfile
sudo fallocate -l $SIZE $DIR/swapfile
sudo dd if=/dev/zero of=$DIR/swapfile bs=1024 count=$scount
sudo chmod 600 $DIR/swapfile
sudo mkswap $DIR/swapfile
sudo swapon $DIR/swapfile
swapon -s
