#!/bin/bash
#set -x

cd $NVMBASE
APP=""
TYPE="NVM"
EXPTYPE="CAP"
#EXPTYPE="BW"

#TYPE="SSD"
#declare -a bwarr=("4000" "1000" "2000" "500")
#declare -a caparr=("2048" "4096" "8192" "10240")
declare -a caparr=("2048")
declare -a bwarr=("1000")
let CAPACITY=2048


OUTPUTDIR=$APPBENCH/output


SETUP(){
	$NVMBASE/scripts/clear_cache.sh
	cd $SHARED_LIBS/construct
	make clean
}

THROTTLE() {
	#source scripts/setvars.sh
	cp $SCRIPTS/nvmemul-throttle-bw.ini $QUARTZ/nvmemul.ini
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

	sudo kill -9 `pidof neo4j`
	sudo killall java
	sudo kill -9 `pidof neo4j`
	sudo kill -9 `pidof postgres`
	sudo killall postgres

	$SCRIPTS/umount_ext4ramdisk.sh
	rm -rf  /mnt/ext4ramdisk/*
	rm -rf  /mnt/ext4ramdisk/
	sleep 5
	NUMAFREE=`numactl --hardware | grep "node 0 free:" | awk '{print $4}'`
	let DISKSZ=$NUMAFREE-$CAPACITY

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


APP="rocksdb.out"
#APP="fio.out"
#APP="filebench.out"
#APP="redis.out"
#APP=fxmark
#APP="flash.out"
#APP="cassandra.out"



RUNAPP() {
	#Run application
	cd $NVMBASE

	#/bin/ls &> $OUTPUT
	#$APPBENCH/apps/fio/run.sh &> $OUTPUT

	if [ "$APP" = "rocksdb.out" ]
	then
		#$APPBENCH/apps/rocksdb/run.sh &> $OUTPUT
		/bin/ls &> $OUTPUT
	fi
        #$APPBENCH/apps/rocksdb/run_new.sh &> $OUTPUT

	if [ "$APP" = "cassandra.out" ]
	then
		$APPBENCH/butterflyeffect/code/run.sh &> $OUTPUT
	fi

	#$APPBENCH/apps/filebench/run.sh &> $OUTPUT
	#$APPBENCH/apps/FlashX/run.sh &> $OUTPUT
	#$APPBENCH/apps/filebench/run.sh &> $OUTPUTDIR/$OUTPUT
	#$APPBENCH/apps/pigz/run.sh &> $OUTPUT

	if [ "$APP" = "redis.out" ]
	then
		$APPBENCH/redis-5.0.5/src/run.sh &> $OUTPUT
	fi
	#$APPBENCH/apps/fxmark/run.sh &> $OUTPUT
	#$APPBENCH/redis-3.0.0/src/run.sh &> $OUTPUT

	sudo dmesg -c &>> $OUTPUT
}

SET_RUN_APP() {	
	DIR=$1
	OUTPUT=$DIR/$2
	mkdir $OUTPUT

	if [ "NVM" = "$TYPE" ]
	then
		echo "Running for NVM"
		OUTPUT="$OUTPUT/$APP-NVM"
	else
		echo "Running for SSD"
		OUTPUT="$OUTPUT/$APP-SSD"
	fi
	echo $OUTPUT

        $NVMBASE/scripts/clear_cache.sh
        cd $SHARED_LIBS/construct
        make clean
	make CFLAGS="$3"
	
	rm $OUTPUTDIR/redis*.txt

	RUNAPP
	#$SCRIPTS/rocksdb_extract_result.sh
	$SCRIPTS/clear_cache.sh


	cp  $OUTPUTDIR/redis*.txt  $DIR/$2/
}

for bw  in "${bwarr[@]}"
do
	sed -i "/read =/c\read = $bw" $SCRIPTS/nvmemul-throttle-bw.ini
	sed -i "/write =/c\write = $bw" $SCRIPTS/nvmemul-throttle-bw.ini
	THROTTLE

	for CAPACITY  in "${caparr[@]}"
	do
		if [ "$EXPTYPE" == "BW" ];
		then
			OUTPUTDIR=$APPBENCH/output/BW"$bw-"$TYPE
			mkdir $OUTPUTDIR
			export OUTPUTDIR=$APPBENCH/output/BW"$bw-"$TYPE
			SETUPEXTRAM
		else
			OUTPUTDIR=$APPBENCH/output/CAP"$CAPACITY-"$TYPE
			mkdir $OUTPUTDIR
			export OUTPUTDIR=$APPBENCH/output/CAP"$CAPACITY-"$TYPE
			SETUPEXTRAM
		fi
		echo $OUTPUTDIR

		export APPPREFIX="numactl  --preferred=0"
		$NVMBASE/scripts/clear_cache.sh
		SET_RUN_APP "slowmem-obj-affinity-$TYPE" "-D_MIGRATE -D_OBJAFF -D_PREFETCH -D_NET"
		$NVMBASE/scripts/clear_cache.sh
	done
done
	exit

	sed -i "/read =/c\read = 30000" $SCRIPTS/nvmemul-throttle-bw.ini
	sed -i "/write =/c\write = 30000" $SCRIPTS/nvmemul-throttle-bw.ini
	export APPPREFIX="numactl --membind=0"
	DISABLE_THROTTLE
	SET_RUN_APP $OUTPUTDIR "APPFAST-OSFAST-$TYPE" "-D_DISABLE_HETERO  -D_DISABLE_MIGRATE"
	exit
