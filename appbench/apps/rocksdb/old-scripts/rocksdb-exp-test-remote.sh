#!/bin/bash
#set -x
DBHOME=$PWD
THREAD=16
VALUE_SIZE=4096
SYNC=0
KEYSIZE=1000
WRITE_BUFF_SIZE=67108864
#DBDIR=$DBHOME/DATA
DBDIR=/mnt/remote/DATA
sudo chown -R $USER /mnt/remote
sudo mkdir -p $DBDIR
sudo chown -R $USER $DBDIR

if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi


#WORKLOAD="readseq"
#WORKLOAD="readreverse"
WORKLOAD="readrandom"
WRITEARGS="--benchmarks=fillseq --use_existing_db=0 --threads=1"
READARGS="--benchmarks=$WORKLOAD --use_existing_db=1 --mmap_read=0 --threads=$THREAD"
#READARGS="--benchmarks=$WORKLOAD --use_existing_db=1 --mmap_read=0 --threads=$THREAD --advise_random_on_open=false --readahead_size=2097152 --compaction_readahead_size=2097152 --log_readahead_size=2097152"
APPPREFIX="/usr/bin/time -v"

APP=db_bench
APPOUTPUTNAME="ROCKSDB"

RESULTS="RESULTS"/$WORKLOAD
RESULTFILE=""

mkdir -p $RESULTS



declare -a num_arr=("20000000")
NUM=20000000
#declare -a workload_arr=("readrandom" "readseq" "readreverse" "compact" "overwrite" "readwhilewriting" "readwhilescanning")
#declare -a thread_arr=("4" "8" "16" "32")
#declare -a config_arr=("Vanilla" "Cross_Naive" "CPBI" "CNI" "CPBV" "CPNV" "CPNI")

declare -a thread_arr=("1" "4" "8" "16" "32")
#declare -a thread_arr=("32")


declare -a workload_arr=("readseq" "readrandom" "readwhilescanning" "readreverse" "multireadrandom")
declare -a workload_arr=("multireadrandom" "readrandom" "readreverse" "readseq" "readwhilescanning")
#declare -a workload_arr=("multireadrandom")


declare -a membudget=("4" "3" "2")
#declare -a membudget=("8")

USEDB=1
MEM_REDUCE_FRAC=0

ENABLE_MEM_SENSITIVE=0
#echo "CAUTION, CAUTION, USE EXITING DB is set to 0 for write workload testing!!!"

#declare -a config_arr=("Cross_Info" "OSonly" "Vanilla" "Cross_Info_sync" "Cross_Blind" "CII" "CIP" "CIP_sync" "CIPI")
declare -a config_arr=("CPBI_sync" "Vanilla" "OSonly" "Cross_Info_sync" "CIP_sync")

#declare -a config_arr=("Vanilla" "OSonly" "CII_sync" "CIP_sync" "CPBI_sync" "Cross_Info_sync" "CII" "CIP" "CPBI")
#declare -a config_arr=("Vanilla" "OSonly" "Cross_Info" "CII" "CIP" "CPBI" "CIPI")

declare -a config_arr=("Vanilla" "OSonly" "Cross_Info" "CII" "CIP" "CPBI" "CIPI")
#declare -a config_arr=("CPBI")


#declare -a workload_arr=("multireadrandom")
#declare -a membudget=("6")


declare -a trials=("TRIAL2" "TRIAL3")
G_TRIAL="TRIAL1"


#Require for large database
ulimit -n 1000000 



FlushDisk()
{
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        #sudo dmesg --clear
        sleep 5
}

CLEAR_DATA()
{
        sudo killall $APP
        sudo killall $APP
        sleep 3
        sudo killall $APP
        rm -rf $DBDIR/*
        rm -rf *.sst CURRENT IDENTITY LOCK MANIFEST-* OPTIONS-* WAL_LOG/
}



COMPILE_AND_WRITE()
{
        export LD_PRELOAD=""
	PARAMS="--db=$DBDIR --value_size=$VALUE_SIZE --wal_dir=$DBDIR/WAL_LOG --sync=$SYNC --key_size=$KEYSIZE --write_buffer_size=$WRITE_BUFF_SIZE --num=$NUM --target_file_size_base=209715200"
	mkdir -p $RESULTS

	cd $PREDICT_LIB_DIR
	$PREDICT_LIB_DIR/compile.sh &> compile.out
	cd $DBHOME
        $DBHOME/db_bench $PARAMS $WRITEARGS #&> $RESULTS/WARMUP-WRITE.out

        ##Condition the DB to get Stable results
        #$DBHOME/db_bench $PARAMS/users/kannan11/ssd/prefetching/appbench/apps/rocksdb/DATA/LOCK $READARGS  #&> $RESULTS/WARMUP-READ1.out
        #FlushDisk
        #$DBHOME/db_bench $PARAMS $READARGS  &> WARMUP-READ2.out
}


COMPILE()
{
        export LD_PRELOAD=""
	cd $PREDICT_LIB_DIR
	$PREDICT_LIB_DIR/compile.sh &> compile.out
	cd $DBHOME
}





GEN_RESULT_PATH() {
	WORKLOAD=$1
	CONFIG=$2
	THREAD=$3
	let KEYCOUNT=$NUM/1000000
	#WORKLOAD="DUMMY"
	#RESULTFILE=""

	if [ "$ENABLE_MEM_SENSITIVE" -eq "0" ]
	then 
		RESULTS=$OUTPUTDIR"-"$G_TRIAL/$APPOUTPUTNAME/$KEYCOUNT"M-KEYS"/$WORKLOAD/$THREAD
	else
        	RESULTS=$OUTPUTDIR"-"$G_TRIAL/$APPOUTPUTNAME/$KEYCOUNT"M-KEYS"/"MEMFRAC"$MEM_REDUCE_FRAC/$WORKLOAD/$THREAD/
	fi
	mkdir -p $RESULTS
        RESULTFILE=$RESULTS/$CONFIG".out"
}



RUN() {

        #CLEAR_DATA
	echo "BEGINNING TO WARM UP ......."
	cd $PREDICT_LIB_DIR
	$PREDICT_LIB_DIR/compile.sh
	cd $DBHOME
	#COMPILE_AND_WRITE
	COMPILE
	echo "FINISHING WARM UP ......."
	echo "..................................................."
	FlushDisk
	sudo dmesg -c

	for NUM in "${num_arr[@]}"
	do
		for THREAD in "${thread_arr[@]}"
		do
			PARAMS="--db=$DBDIR --value_size=$VALUE_SIZE --wal_dir=$DBDIR/WAL_LOG --sync=$SYNC --key_size=$KEYSIZE --write_buffer_size=$WRITE_BUFF_SIZE --num=$NUM  --seed=1576170874"

			for WORKLOAD in "${workload_arr[@]}"
			do
				for CONFIG in "${config_arr[@]}"
				do
					RESULTS=""
					READARGS="--benchmarks=$WORKLOAD --use_existing_db=$USEDB --mmap_read=0 --threads=$THREAD"
					GEN_RESULT_PATH $WORKLOAD $CONFIG $THREAD $NUM

					mkdir -p $RESULTS

					echo "RUNNING $CONFIG and writing results to #$RESULTS/$CONFIG.out"
					echo "..................................................."

					rm -rf $DBDIR/LOCK

					export LD_PRELOAD=/usr/lib/lib_$CONFIG.so
					$APPPREFIX "./"$APP $PARAMS $READARGS &> $RESULTFILE
					export LD_PRELOAD=""
					sudo dmesg -c &>> $RESULTFILE
					echo ".......FINISHING $CONFIG......................"
					cat $RESULTS/$CONFIG.out | grep "MB/s"
					FlushDisk
				done
			done
		done
	done
}

GETMEMORYBUDGET() {
        sudo rm -rf  /mnt/ext4ramdisk/*
        $SCRIPTS/mount/umount_ext4ramdisk.sh
        sudo rm -rf  /mnt/ext4ramdisk/*
        sudo rm -rf  /mnt/ext4ramdisk/

        let NUMAFREE0=`numactl --hardware | grep "node 0 free:" | awk '{print $4}'`
        let NUMAFREE1=`numactl --hardware | grep "node 1 free:" | awk '{print $4}'`

	echo "MEMORY $1"
	let FRACTION=$1
	let NUMANODE0=$(($NUMAFREE0/$FRACTION))
	let NUMANODE1=$(($NUMAFREE1/$FRACTION))


	let DISKSZ0=$(($NUMAFREE0-$NUMANODE0))
	let DISKSZ1=$(($NUMAFREE1-$NUMANODE1))

	echo "***NODE 0: "$DISKSZ0"****NODE 1: "$DISKSZ1
	$SCRIPTS/mount/releasemem.sh "NODE0"
	$SCRIPTS/mount/releasemem.sh "NODE1"

        numactl --membind=0 $SCRIPTS/mount/reducemem.sh $DISKSZ0 "NODE0"
        numactl --membind=1 $SCRIPTS/mount/reducemem.sh $DISKSZ1 "NODE1"
}

for G_TRIAL in "${trials[@]}"
do
	RUN
done
exit

sleep 200

ENABLE_MEM_SENSITIVE=1
if [ "$ENABLE_MEM_SENSITIVE" -eq "1" ]
then
	for MEM_REDUCE_FRAC in "${membudget[@]}"
	do
		GETMEMORYBUDGET $MEM_REDUCE_FRAC
		RUN
		$SCRIPTS/mount/releasemem.sh "NODE0"
		$SCRIPTS/mount/releasemem.sh "NODE1"
	done
else
	RUN
fi

