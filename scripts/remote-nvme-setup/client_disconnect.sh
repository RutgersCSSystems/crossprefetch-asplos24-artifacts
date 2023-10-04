#!/usr/bin/env bash

# Client should be the one who visits nvme device on other nodes(targets) 

USER=ingerido
IP_ADDR=10.10.1.2
LOCAL_DISK=/dev/nvme0n1p4
LOCAL_STORAGE=/users/kannan11/ssd
REMOTE_TARGET=nvme-target1
REMOTE_DISK=/dev/nvme1n1p4
REMOTE_STORAGE=/mnt/remote

sudo nvme connect -d $REMOTE_DISK
sudo nvme list

