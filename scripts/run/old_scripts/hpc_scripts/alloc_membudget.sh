#!/bin/bash
#set -x

APPDIR=$HOME/ssd/NVM/hpc_scripts

SLEEPNOW() {
	sleep 2
}

SETUPEXTRAM() {

	let CAPACITY=$1

	let SPLIT=$CAPACITY/2
	echo "SPLIT" $SPLIT

        sudo rm -rf  /mnt/ext4ramdisk0/*
        sudo rm -rf  /mnt/ext4ramdisk1/*

	$APPDIR/umount_ext4ramdisk.sh 0
	$APPDIR/umount_ext4ramdisk.sh 1
	
	$APPDIR/clear_cache.sh

        SLEEPNOW

        NUMAFREE0=`numactl --hardware | grep "node 0 free:" | awk '{print $4}'`
        NUMAFREE1=`numactl --hardware | grep "node 1 free:" | awk '{print $4}'`

        let DISKSZ=$NUMAFREE0-$SPLIT
        let ALLOCSZ=$NUMAFREE1-$SPLIT

        echo "NODE 0 $DISKSZ NODE 1 $ALLOCSZ"

        $APPDIR/mount_ext4ramdisk.sh $DISKSZ 0
        $APPDIR/mount_ext4ramdisk.sh $ALLOCSZ 1

	$APPDIR/clear_cache.sh

	SLEEPNOW
}

SETUPEXTRAM $1
