#!/bin/bash

##This script will call variation scripts from different apps


declare -a apparr=("strided_madbench" "rocksdb" "graphchi" "ior")

SLEEPNOW() {
	sleep 2
}

REFRESH() {
    export LD_PRELOAD=""
    $NVMBASE/scripts/compile-install/clear_cache.sh
    sudo sh -c "dmesg --clear" ##clear dmesg
    SLEEPNOW
}


SETUPEXTRAM() {

    let CAPACITY=$1

    let SPLIT=$CAPACITY/2
    echo "SPLIT" $SPLIT

    sudo rm -rf  /mnt/ext4ramdisk0/*
    sudo rm -rf  /mnt/ext4ramdisk1/*

    ./umount_ext4ramdisk.sh 0
    ./umount_ext4ramdisk.sh 1

    SLEEPNOW

    NUMAFREE0=`numactl --hardware | grep "node 0 free:" | awk '{print $4}'`
    NUMAFREE1=`numactl --hardware | grep "node 1 free:" | awk '{print $4}'`

    let DISKSZ=$NUMAFREE0-$SPLIT-712
    let ALLOCSZ=$NUMAFREE1-$SPLIT-712

    echo "NODE 0 $DISKSZ NODE 1 $ALLOCSZ"

    ./mount_ext4ramdisk.sh $DISKSZ 0
    ./mount_ext4ramdisk.sh $ALLOCSZ 1

    SLEEPNOW
}


#Here is where we run the application
RUNAPP() 
{
    #Run application
    cd $APPDIR
    mkdir results-sensitivity

    APP=$1

    if [ "$APP" = "strided_madbench" ]; then
        ##Call runexp_in the madbench folder
    fi

    if [ "$APP" = "gtc" ]; then
        ##call the GTC run command in GTC folder
    fi

    if [ "$APP" = "bt" ]; then
        #call bt command in BT folder
    fi
}


for APP in "${apparr[@]}"
do
	for CAPACITY  in "${caparr[@]}"
	do 
		SETUPEXTRAM $CAPACITY

		for NPROC in "${thrdarr[@]}"
		do	
			for WORKLOAD in "${workarr[@]}"
			do
				$SHARED_LIBS/construct/reset
				RUNAPP $CAPACITY $NPROC $WORKLOAD $APP
				RUNAPP $CAPACITY $NPROC $WORKLOAD $APP
				RUNAPP $CAPACITY $NPROC $WORKLOAD $APP
				$SHARED_LIBS/construct/reset
				SLEEPNOW
				./clear_cache.sh
				TERMINATE $CAPACITY $NPROC $WORKLOAD
			done 
		done	
	done
done
