#!/bin/bash
set -x
cd $NVMBASE
APP=""
#TYPE="NVM"
TYPE="SSD"
CAPACITY=32786

#declare -a apparr=("redis.out" "cassandra.out" "filebench.out" "rocksdb.out")
declare -a apparr=("redis.out")

OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/mem-stats"
mkdir -f $OUTPUTDIR


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

	kill -9 `pidof neo4j`
	sudo killall java
	sudo kill -9 `pidof neo4j`
	sudo kill -9 `pidof postgres`
	sudo kilall postgres
	sudo /etc/init.d/mysql stop
	sudo dmesg -c

        sudo rm -rf  /mnt/ext4ramdisk/*
	$SCRIPTS/umount_ext4ramdisk.sh
	sudo rm -rf  /mnt/ext4ramdisk/*
	sudo rm -rf  /mnt/ext4ramdisk/
	
        sleep 5
	NUMAFREE=`numactl --hardware | grep "node 0 free:" | awk '{print $4}'`
	let DISKSZ=$NUMAFREE-$CAPACITY
	echo $DISKSZ"*************"
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


#APP="rocksdb.out"
#APP="HiBench.out"
#APP="spark-bench.out"
#APP="fio.out"
#APP="filebench.out"
#APP="redis.out"
#APP=fxmark
#APP="flash.out"
#APP="cassandra.out"



RUNAPP() {
        #Run application
        cd $NVMBASE
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

	if [ "$APP" = "flash.out" ]
	then
        	$APPBENCH/apps/FlashX/run.sh &> $OUTPUT
	fi

	if [ "$APP" = "filebench.out" ]
	then
        	$SCRIPTS/perf.sh $APPBENCH/apps/filebench/run.sh &> $OUTPUT
	fi
       #$APPBENCH/apps/pigz/run.sh &> $OUTPUT

        if [ "$APP" = "redis.out" ]
        then
                $SCRIPTS/perf.sh $APPBENCH/redis-5.0.5/src/run.sh &> $OUTPUT
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
	BASE=$OUTPUTDIR
	mkdir $OUTPUTDIR/$1
	export OUTPUTDIR=$OUTPUTDIR/$1

	if [ "NVM" = "$TYPE" ]
	then
		echo "Running for NVM"
		OUTPUT="$OUTPUTDIR/$APP-NVM"
	else
		echo "Running for SSD"
		OUTPUT="$OUTPUTDIR/$APP-SSD"
	fi

        $NVMBASE/scripts/clear_cache.sh
        cd $SHARED_LIBS/construct
        make clean
	make CFLAGS="$2"
	sudo make install

	RUNAPP
	$SCRIPTS/rocksdb_extract_result.sh
	$SCRIPTS/clear_cache.sh

	#cp -r $OUTPUTDIR $BASE/"CAP"$CAPACITY-$TYPE/$1
	export OUTPUTDIR=$BASE


	set +x
}

if [ -z "$1" ]
  then
    THROTTLE
  else
    echo "Don't throttle"
fi

#SETUPEXTRAM
for APP in "${apparr[@]}"
do

	#### OBJAFF NO PREFETCH #############
	export APPPREFIX="numactl  --preferred=0"
	#SETUPEXTRAM
	$NVMBASE/scripts/clear_cache.sh
	SET_RUN_APP "slowmem-obj-affinity-nomig-$TYPE" "-D_DISABLE_MIGRATE"
	continue


	#### NAIVE PLACEMENT #############
	export APPPREFIX="numactl  --preferred=0"
	$NVMBASE/scripts/clear_cache.sh
	SET_RUN_APP "naive-os-fastmem-$TYPE" "-D_DISABLE_MIGRATE"
	continue

	export APPPREFIX="numactl --membind=1"
	$SCRIPTS/umount_ext4ramdisk.sh
	sleep 5
	$SCRIPTS/mount_ext4ramdisk.sh 48000
	SET_RUN_APP "slowmem-only-$TYPE" "-D_SLOWONLY -D_DISABLE_MIGRATE -D_NET"
	continue


	#### WITH PREFETCH #############
	export APPPREFIX="numactl  --preferred=0"
	SETUPEXTRAM
	$NVMBASE/scripts/clear_cache.sh
	SET_RUN_APP "slowmem-obj-affinity-prefetch-$TYPE" "-D_MIGRATE -D_PREFETCH -D_OBJAFF"
	$NVMBASE/scripts/clear_cache.sh
	exit


	$SCRIPTS/umount_ext4ramdisk.sh
	sleep 5
	$SCRIPTS/mount_ext4ramdisk.sh 24000
	DISABLE_THROTTLE
	export APPPREFIX="numactl --membind=0"
	SET_RUN_APP "optimal-os-fastmem-$TYPE" "-D_DISABLE_HETERO  -D_DISABLE_MIGRATE"
	exit

	#### MIGRATION ONLY NO PREFETCH #############
	export APPPREFIX="numactl  --preferred=0"
	SETUPEXTRAM
	$NVMBASE/scripts/clear_cache.sh
	SET_RUN_APP "slowmem-migration-only-$TYPE" "-D_MIGRATE -D_NET"
done








	#### OBJ AFFINITY NO MIGRATION NO PREFETCH #############

	$SCRIPTS/umount_ext4ramdisk.sh
	sleep 5
	$SCRIPTS/mount_ext4ramdisk.sh 24000
	DISABLE_THROTTLE
	export APPPREFIX="numactl --membind=0"
	SET_RUN_APP "optimal-os-fastmem-$TYPE" "-D_DISABLE_HETERO  -D_DISABLE_MIGRATE"


	exit



	#### WITHOUT PREFETCH #############
	export APPPREFIX="numactl  --preferred=0"
	SETUPEXTRAM
	$NVMBASE/scripts/clear_cache.sh
	SET_RUN_APP "slowmem-obj-affinity-$TYPE" "-D_MIGRATE -D_OBJAFF -D_NET"
	$NVMBASE/scripts/clear_cache.sh





	mkdir $OUTPUTDIR/slowmem-only
	OUTPUT="slowmem-only/$APP"
	SETUP
	make CFLAGS="-D_SLOWONLY"
	export APPPREFIX="numactl --membind=1"
	$SCRIPTS/umount_ext4ramdisk.sh
	sleep 5
	$SCRIPTS/mount_ext4ramdisk.sh 24000
	RUNAPP 
	$SCRIPTS/rocksdb_extract_result.sh
	$SCRIPTS/clear_cache.sh
	exit

	#Don't do any migration




#mkdir $OUTPUTDIR/fastmem-only
exit
#Disable hetero for fastmem only mode
#make CFLAGS="-D_DISABLE_HETERO"
