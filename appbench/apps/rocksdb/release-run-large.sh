#!/bin/bash
#set -x
DBHOME=$PWD
THREAD=16
VALUE_SIZE=4096
SYNC=0
KEYSIZE=1000
WRITE_BUFF_SIZE=67108864
DBDIR=$DBHOME/DATA
#DBDIR=/mnt/remote/DATA


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
APPPREFIX="/usr/bin/time -v"

PARAMS=""
ERR=100

APP=db_bench
APPOUTPUTNAME="ROCKSDB"

RESULTS="RESULTS"/$WORKLOAD
RESULTFILE=""

mkdir -p $RESULTS

#declare -a config_arr=("Vanilla" "Cross_Naive" "CPBI" "CNI" "CPBV" "CPNV" "CPNI")
declare -a num_arr=("40000000")
NUM=40000000

#declare -a thread_arr=("32" "16"  "8"  "4" "1")
#declare -a membudget=("6" "4" "2" "8")
#echo "CAUTION, CAUTION, USE EXITING DB is set to 0 for write workload testing!!!"
#declare -a trials=("TRIAL1" "TRIAL2" "TRIAL3")
USEDB=1
MEM_REDUCE_FRAC=0
ENABLE_MEM_SENSITIVE=0

declare -a membudget=("6")
declare -a trials=("TRIAL1")
declare -a workload_arr=("multireadrandom" "readseq" "readwhilescanning" "readreverse")
declare -a thread_arr=("32")

declare -a config_arr=("Vanilla" "OSonly" "CII" "CIPI_PERF_NOOPT" "CIPI_PERF" "CPBI_PERF")
#declare -a config_arr=("CIPI_PERF")
declare -a workload_arr=("multireadrandom")

G_TRIAL="TRIAL1"
#Require for large database
ulimit -n 1000000 

workload_arr_in=$1
config_arr_in=$2
thread_arr_in=$3


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





GEN_RESULT_PATH() {
	WORKLOAD=$1
	CONFIG=$2
	THREAD=$3
	let KEYCOUNT=$NUM/1000000

	if [ "$ENABLE_MEM_SENSITIVE" -eq "0" ]
	then 
		RESULTS=$OUTPUTDIR"-"$G_TRIAL/$APPOUTPUTNAME/$KEYCOUNT"M-KEYS"/$WORKLOAD/$THREAD
		mkdir -p $RESULTS
		RESULTFILE=$RESULTS/$CONFIG".out"
	else
        	RESULTS=$OUTPUTDIR"-"$G_TRIAL/$APPOUTPUTNAME/$KEYCOUNT"M-KEYS"/"MEMFRAC"$MEM_REDUCE_FRAC/$WORKLOAD/$THREAD/
		mkdir -p $RESULTS
		RESULTFILE=$RESULTS/$CONFIG".out"
	fi

	echo $RESULTFILE
}

EXECUTE() {

    CONFIG=$1
    #echo "RUNNING $CONFIG $PARAMS $READARGS and writing results to  $RESULTFILE"
    export LD_PRELOAD=/usr/lib/lib_$CONFIG.so
    $APPPREFIX "./"$APP $PARAMARG $ARGS &> $RESULTFILE
    export LD_PRELOAD=""

}



RUN() {

        #CLEAR_DATA
	echo "BEGINNING TO WARM UP ......."
	cd $PREDICT_LIB_DIR
	$PREDICT_LIB_DIR/compile.sh &> compile.out
	cd $DBHOME
	echo "FINISHING WARM UP ......."
	echo "..................................................."
	FlushDisk
	sudo dmesg -c

	for NUM in "${num_arr[@]}"
	do
			./compile.sh &>> out.txt

			cd $DBHOME

			for THREAD in "${thread_arr[@]}"
			do
				PARAMS="--db=$DBDIR --value_size=$VALUE_SIZE --wal_dir=$DBDIR/WAL_LOG --sync=$SYNC --key_size=$KEYSIZE --write_buffer_size=$WRITE_BUFF_SIZE --seed=100 --num_levels=6 --target_file_size_base=33554432 -max_background_compactions=8 --num=$NUM --seed=100000000"
				for WORKLOAD in "${workload_arr[@]}"
				do
					if [[ $WORKLOAD == "readseq" ]]; then
						#echo "READSEQ"
						cp PARAMS.sh $PREDICT_LIB_DIR/compile.sh
						cp Makefile.ROCKSDB $PREDICT_LIB_DIR/Makefile
						cd $PREDICT_LIB_DIR
						./compile.sh &>> out.txt
						cd $DBHOME
					else
						cd $PREDICT_LIB_DIR
						cp $PREDICT_LIB_DIR/ORIGMAKEFILE $PREDICT_LIB_DIR/Makefile
						#cp $PREDICT_LIB_DIR/COMPILEORIG.sh $PREDICT_LIB_DIR/compile.sh
						cd $DBHOME
						./compile.sh &>> out.txt	
						cd $DBHOME
					fi

					for CONFIG in "${config_arr[@]}"
					do
						RESULTS=""
						READARGS="--benchmarks=$WORKLOAD --use_existing_db=$USEDB --mmap_read=0 --threads=$THREAD"
						GEN_RESULT_PATH $WORKLOAD $CONFIG $THREAD $NUM

						mkdir -p $RESULTS

						echo "RUNNING $CONFIG and writing results to $RESULTFILE"
						echo "..................................................."

						rm -rf $DBDIR/LOCK

						echo "$APPPREFIX "./"$APP $PARAMS $READARGS"

						export LD_PRELOAD=/usr/lib/lib_$CONFIG.so
						$APPPREFIX "./"$APP $PARAMS $READARGS &> $RESULTFILE
						export LD_PRELOAD=""


						#cat $RESULTFILE | grep "ops/sec"
						VAL=`cat $RESULTFILE | grep "ops/sec" | awk '{print $5}'`
						if [ -z "$VAL" ]; then
							VAL=0
						fi
						if [ "$ERR" -gt "$VAL" ]; then
						  EXECUTE $CONFIG $PARAMS $READARGS $RESULTFILE
						fi

						sudo dmesg -c &>> $RESULTFILE
						echo ".......FINISHING $CONFIG......................"
						#cat $RESULTFILE | grep "MB/s"
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

	echo "***NODE 0: "$DISKSZ0"****NODE 1: "$DISKSZ1
	$SCRIPTS/mount/releasemem.sh "NODE0"
	$SCRIPTS/mount/releasemem.sh "NODE1"

    let NUMAFREE0=`numactl --hardware | grep "node 0 free:" | awk '{print $4}'`
    let NUMAFREE1=`numactl --hardware | grep "node 1 free:" | awk '{print $4}'`

	echo "MEMORY $1"
	let FRACTION=$1
	let NUMANODE0=$(($NUMAFREE0/$FRACTION))
	let NUMANODE1=$(($NUMAFREE1/$FRACTION))

	let DISKSZ0=$(($NUMAFREE0-$NUMANODE0))
	let DISKSZ1=$(($NUMAFREE1-$NUMANODE1))


    numactl --membind=0 $SCRIPTS/mount/reducemem.sh $DISKSZ0 "NODE0"
    numactl --membind=1 $SCRIPTS/mount/reducemem.sh $DISKSZ1 "NODE1"
}



#COMPILE

for G_TRIAL in "${trials[@]}"
do
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
done


