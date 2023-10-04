#!/bin/bash
set -x

cd $NVMBASE
APP=""
#TYPE="SSD"
TYPE="NVM"
#APP="spark-bench.out"
#APP="fio.out"
#APP="filebench.out"
#APP="redis.out"
#APP=fxmark
#APP="flash.out"
#APP="cassandra.out"
#APP="rocksdb.out"
APP="spark-bench.out"

let CAPACITY=5192
#TYPE="SSD"
#declare -a bwarr=("4000" "1000" "2000" "500")
declare -a bwarr=("1000")
#declare -a caparr=("2048" "4096" "8192" "10240")
#EXPTYPE="CAP"
EXPTYPE="BW"
declare -a caparr=("5192")
#declare -a apparr=("rocksdb.out")
declare -a apparr=("spark-bench.out")

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
	sleep 2
	sudo killall java
	sudo killall java
	sleep 2
	sudo kill -9 `pidof neo4j`
	sudo kill -9 `pidof postgres`
	sudo killall postgres

	rm -rf  /mnt/ext4ramdisk/*
	$SCRIPTS/umount_ext4ramdisk.sh
	if mount | grep /mnt/ext4ramdisk > /dev/null; then
  		echo "Umounting failed"
		exit
	fi

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

RUNAPP() {
	#Run application
	cd $NVMBASE

	#/bin/ls &> $OUTPUT
	#$APPBENCH/apps/fio/run.sh &> $OUTPUT

	if [ "$APP" = "rocksdb.out" ]
	then
		$APPBENCH/apps/rocksdb/run.sh &> $OUTPUT
	fi
        #$APPBENCH/apps/rocksdb/run_new.sh &> $OUTPUT

	if [ "$APP" = "cassandra.out" ]
	then
		$APPBENCH/apps/butterflyeffect/code/run.sh &> $OUTPUT
	fi

	#$APPBENCH/apps/filebench/run.sh &> $OUTPUT
	#$APPBENCH/apps/FlashX/run.sh &> $OUTPUT
	#$APPBENCH/apps/filebench/run.sh &> $OUTPUTDIR/$OUTPUT
	#$APPBENCH/apps/pigz/run.sh &> $OUTPUT

	if [ "$APP" = "redis.out" ]
	then
		$APPBENCH/redis-5.0.5/src/run.sh &> $OUTPUT
	fi

	if [ "$APP" = "spark-bench.out" ]
	then
		cd $APPBENCH/apps/spark/spark-bench
		$APPBENCH/apps/spark/spark-bench/run.sh &> $OUTPUT
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

        $NVMBASE/scripts/clear_cache.sh
        cd $SHARED_LIBS/construct
        make clean
	make CFLAGS="$3"
	sudo make install
	
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

	if [ -z "$1" ]
	  then
	    THROTTLE
	  else
	    echo "Don't throttle"
	fi

	for APP in "${apparr[@]}"
	do

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


		sed -i "/read =/c\read = 30000" $SCRIPTS/nvmemul-throttle-bw.ini
		sed -i "/write =/c\write = 30000" $SCRIPTS/nvmemul-throttle-bw.ini
		export APPPREFIX="numactl --membind=0"
		DISABLE_THROTTLE
		SET_RUN_APP $OUTPUTDIR "APPFAST-OSFAST-$TYPE" "-D_DISABLE_HETERO  -D_DISABLE_MIGRATE"
		exit


		export APPPREFIX="numactl --preferred=0"
		$NVMBASE/scripts/clear_cache.sh
		SET_RUN_APP $OUTPUTDIR "slowmem-obj-affinity-prefetch-$TYPE" "-D_MIGRATE -D_PREFETCH -D_OBJAFF"
		sleep 2

		#$SCRIPTS/umount_ext4ramdisk.sh
		#sleep 5
		#$SCRIPTS/mount_ext4ramdisk.sh 24000
		#DISABLE_THROTTLE
		#export APPPREFIX="numactl --membind=0"
		#SET_RUN_APP $OUTPUTDIR "APPFAST-OSFAST-$TYPE" "-D_DISABLE_HETERO  -D_DISABLE_MIGRATE"



		#export APPPREFIX="numactl --preferred=1"
		#$NVMBASE/scripts/clear_cache.sh
		#SET_RUN_APP $OUTPUTDIR "slowmem-only-$TYPE" "-D_SLOWONLY -D_DISABLE_MIGRATE -D_NET"

		#export APPPREFIX="numactl --preferred=0"
		#$NVMBASE/scripts/clear_cache.sh
		#SET_RUN_APP $OUTPUTDIR "naive-os-fastmem-$TYPE" "-D_DISABLE_MIGRATE"
		#sleep 2

		#### OBJAFF NO PREFETCH #############
		#export APPPREFIX="numactl  --preferred=0"
		#$NVMBASE/scripts/clear_cache.sh
		#SET_RUN_APP $OUTPUTDIR "slowmem-obj-affinity-nomig-$TYPE" "-D_DISABLE_MIGRATE -D_OBJAFF"

		#export APPPREFIX="numactl --preferred=0"
		#$NVMBASE/scripts/clear_cache.sh
		#SET_RUN_APP $OUTPUTDIR "slowmem-obj-affinity-prefetch-$TYPE" "-D_MIGRATE -D_PREFETCH -D_OBJAFF"
		#sleep 2

		#export APPPREFIX="numactl  --preferred=0"
		#$NVMBASE/scripts/clear_cache.sh
		#SET_RUN_APP $OUTPUTDIR "slowmem-migration-only-$TYPE" "-D_MIGRATE -D_NET"
		#sleep 2


		#SET_RUN_APP $OUTPUTDIR  "APPFAST-OSSLOW-$TYPE" "-D_SLOWONLY  -D_DISABLE_MIGRATE"
		#export APPPREFIX="numactl --membind=1"
		#SET_RUN_APP $OUTPUTDIR  "APPSLOW-OSSLOW-$TYPE" "-D_SLOWONLY -D_DISABLE_MIGRATE"
		#export APPPREFIX="numactl --preferred=0"
		#SET_RUN_APP $OUTPUTDIR  "APPFAST-OSSLOW-$TYPE" "-D_SLOWONLY  -D_DISABLE_MIGRATE"
		done
	done
done
	exit

	$SCRIPTS/umount_ext4ramdisk.sh
	sleep 5
	$SCRIPTS/mount_ext4ramdisk.sh 24000
	DISABLE_THROTTLE
	export APPPREFIX="numactl --membind=0"
	SET_RUN_APP "optimal-os-fastmem-$TYPE" "-D_DISABLE_HETERO  -D_DISABLE_MIGRATE"
	exit


