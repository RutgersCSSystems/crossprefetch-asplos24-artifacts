#!/usr/bin/env bash

# target server setup to enable NVMe over RoCE

#echo y | sudo mkfs.ext4 /dev/nvme0n1p4 # This is the part name for m510
#sudo mkdir /mnt/nvme0n1p4
#sudo mount /dev/nvme0n1p4 /mnt/nvme0n1p4


#set this to the ip addr of the target machine
IP_ADDR=10.10.1.2
TARGET_SUBSYS=nvme-target1
NAMESPACE=10
PORT=1
TARGET_DEVICE=/dev/nvme0n1

echo "executing: modprobe nvmet"
modprobe nvmet

echo "executing: modprobe nvmet-rdma"
modprobe nvmet-rdma

echo "executing: configure nvmet subsystems"
# create a nvme subsystem called "nvme-target1"
mkdir /sys/kernel/config/nvmet/subsystems/$TARGET_SUBSYS
cd /sys/kernel/config/nvmet/subsystems/$TARGET_SUBSYS

#allow any host to connect to the target
echo "allow any host to connect to the target"
echo 1 > attr_allow_any_host

echo "make new namespace $NAMESPACE"
mkdir namespaces/$NAMESPACE
cd namespaces/$NAMESPACE

echo "setup remote nvme device"
echo -n $TARGET_DEVICE > device_path
echo 1 > enable

#setting nvme port
echo "setting remote nvme port"
mkdir /sys/kernel/config/nvmet/ports/$PORT
cd  /sys/kernel/config/nvmet/ports/$PORT

echo "setting other remote nvme configurations"
echo ${IP_ADDR} > addr_traddr
echo rdma > addr_trtype
echo 4420 > addr_trsvcid
echo ipv4 > addr_adrfam

ln -s /sys/kernel/config/nvmet/subsystems/$TARGET_SUBSYS /sys/kernel/config/nvmet/ports/$PORT/subsystems/$TARGET_SUBSYS

echo "Done!"
