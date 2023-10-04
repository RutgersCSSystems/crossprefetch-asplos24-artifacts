#!/bin/bash
#set -x
cd $NVMBASE
APP=""
TYPE="NVM"
#TYPE="NVM"
NVMSIZE=8192

SETUP(){
	$NVMBASE/scripts/clear_cache.sh
	cd $SHARED_LIBS/construct
	make clean
}

THROTTLE() {
	source scripts/setvars.sh
	cp $SCRIPTS/nvmemul-throttle.ini $QUARTZ/nvmemul.ini
	$SCRIPTS/install_quartz.sh
	#$SCRIPTS/throttle.sh
	#$SCRIPTS/throttle.sh
}

DISABLE_THROTTLE() {
	source scripts/setvars.sh
	cp $SCRIPTS/nvmemul-nothrottle.ini $QUARTZ/nvmemul.ini
	$SCRIPTS/throttle.sh
	#$SCRIPTS/throttle.sh
}


SETUPEXTRAM() {

	$SCRIPTS/umount_ext4ramdisk.sh
	$SCRIPTS/umount_ext4ramdisk.sh
	rm -rf  /mnt/ext4ramdisk/*
	rm -rf  /mnt/ext4ramdisk/
	sleep 5
	NUMAFREE=`numactl --hardware | grep "node 0 free:" | awk '{print $4}'`
	let DISKSZ=$NUMAFREE-$NVMSIZE
	echo $DISKSZ
	$SCRIPTS/umount_ext4ramdisk.sh
	$SCRIPTS/mount_ext4ramdisk.sh $DISKSZ

	#Enable for Ramdisk
	if [ "NVM" = "$TYPE" ]
	then
		echo "Running for NVM"
		sudo ln -s /mnt/ext4ramdisk $APPBENCH/shared_data
	else
		#Enable for SSD
		echo "Running for SSD"
		mkdir $APPBENCH/shared_data
	fi
}

COMPILE_SHAREDLIB() {
	#Compile shared libs
	cd $SHARED_LIBS/construct
	make clean
	make CFLAGS=$DEPFLAGS
	sudo make install
}


SETUPEXTRAM
