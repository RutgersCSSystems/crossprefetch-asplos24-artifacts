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

APP=db_bench
APPOUTPUTNAME="ROCKSDB"

RESULTS="RESULTS"/$WORKLOAD
RESULTFILE=""

mkdir -p $RESULTS


#declare -a config_arr=("Vanilla" "Cross_Naive" "CPBI" "CNI" "CPBV" "CPNV" "CPNI")

declare -a num_arr=("4000000")
NUM=4000000

declare -a thread_arr=("32" "16"  "8"  "4" "1")
declare -a workload_arr=("multireadrandom" "readrandom" "readreverse" "readseq" "readwhilewriting" "readwhilescanning")
declare -a membudget=("6" "4" "2" "8")
declare -a membudget=("6")

#echo "CAUTION, CAUTION, USE EXITING DB is set to 0 for write workload testing!!!"
#declare -a config_arr=("Vanilla" "OSonly" "CII_sync" "CIP_sync" "CPBI_sync" "Cross_Info_sync" "CII" "CIP" "CPBI")
declare -a config_arr=("Vanilla" "OSonly" "Cross_Info" "CII" "CIP" "CPBI" "CIPI")
declare -a config_arr=("Vanilla" "OSonly" "CPBI_PERF" "CIPI_PERF")
declare -a trials=("TRIAL1" "TRIAL2" "TRIAL3")

USEDB=1
MEM_REDUCE_FRAC=0
ENABLE_MEM_SENSITIVE=0
#Enable sensitivity to vary prefetch size and prefetch thread count
ENABLE_SENSITIVITY=0


G_TRIAL="RELEASE-SHORT"
#Require for large database
ulimit -n 1000000 

workload_arr_in=$1
config_arr_in=$2
thread_arr_in=$3

glob_prefetchsz=1024
glob_prefechthrd=8

declare -a prefech_sz_arr=("1024" "2048" "4096") #"512" "256" "128" "64" 
#declare -a prefech_sz_arr=("1024")
declare -a prefech_thrd_arr=("1" "8")

get_global_arr() {

        if [ ! -z "$workload_arr_in" ]
        then
                if [ ${#workload_arr_in=[@]} -eq 0 ]; then
                    echo "input array in NULL"
                else
                    workload_arr=("${workload_arr_in[@]}")
                fi
        fi

        if [ ! -z "$config_arr_in" ]
        then
                if [ ${#config_arr_in=[@]} -eq 0 ]; then
                    echo "input array in NULL"
                else
                   config_arr=("${config_arr_in[@]}")
                fi
        fi

        if [ ! -z "$thread_arr_in" ]
        then
                if [ ${#thread_arr_in=[@]} -eq 0 ]; then
                    echo "input array in NULL"
                else
                   thread_arr=("${thread_arr_in[@]}")
                fi
        fi

        if [ ! -z "$4" ]
        then
                prefetchsz=$4
        else
                prefetchsz=$glob_prefetchsz
        fi

        if [ ! -z "$5" ]
        then
                prefechthrd=$5
        else
                prefechthrd=$glob_prefechthrd
        fi
}

get_global_arr



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
	PARAMS="--db=$DBDIR --value_size=$VALUE_SIZE --wal_dir=$DBDIR/WAL_LOG --sync=$SYNC --key_size=$KEYSIZE --write_buffer_size=$WRITE_BUFF_SIZE --num=$NUM --target_file_size_base=209715200 --seed=100 --num_levels=6 --target_file_size_base=33554432 -max_background_compactions=8 --num=$NUM --seed=100000000"
	mkdir -p $RESULTS

	cd $PREDICT_LIB_DIR
	make clean
	$PREDICT_LIB_DIR/compile.sh &> compile.out
	cd $DBHOME
        $DBHOME/db_bench $PARAMS $WRITEARGS #&> $RESULTS/WARMUP-WRITE.out
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

        if [ "$ENABLE_SENSITIVITY" -eq "1" ]
        then
		RESULTS=$OUTPUTDIR"-"$G_TRIAL/$APPOUTPUTNAME/$KEYCOUNT"M-KEYS"/$WORKLOAD/$THREAD
		mkdir -p $RESULTS
        	RESULTFILE=$RESULTS/$CONFIG"-PREFETCHSZ-$prefetchsz-PREFETTHRD-$prefechthrd".out

        elif [ "$ENABLE_MEM_SENSITIVE" -eq "0" ]
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



RUN() {

        #CLEAR_DATA
	echo "BEGINNING TO WARM UP ......."
	cd $PREDICT_LIB_DIR
	$PREDICT_LIB_DIR/compile.sh
	cd $DBHOME
	echo "FINISHING WARM UP ......."
	echo "..................................................."
	FlushDisk
	sudo dmesg -c

	for NUM in "${num_arr[@]}"
	do
	       for prefechthrd in "${prefech_thrd_arr[@]}"
		do
			cd $PREDICT_LIB_DIR
			if [ "$ENABLE_SENSITIVITY" -eq "1" ]
			then
				sed -i "/NR_WORKERS_VAR=/c\NR_WORKERS_VAR=$prefechthrd" compile.sh
				sed -i "/PREFETCH_SIZE_VAR=/c\PREFETCH_SIZE_VAR=$prefetchsz" compile.sh
			fi

			./compile.sh &> out.txt

			cd $DBHOME

			for THREAD in "${thread_arr[@]}"
			do
				#PARAMS="--db=$DBDIR --value_size=$VALUE_SIZE --wal_dir=$DBDIR/WAL_LOG --sync=$SYNC --key_size=$KEYSIZE --write_buffer_size=$WRITE_BUFF_SIZE --seed=100 --num_levels=6 --target_file_size_base=33554432 -max_background_compactions=8 --num=$NUM --seed=100000000"
				PARAMS="--db=$DBDIR --value_size=$VALUE_SIZE --wal_dir=$DBDIR/WAL_LOG --sync=$SYNC --key_size=$KEYSIZE --write_buffer_size=$WRITE_BUFF_SIZE --num=$NUM"
				for WORKLOAD in "${workload_arr[@]}"
				do
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
						sudo dmesg -c &>> $RESULTFILE
						echo ".......FINISHING $CONFIG......................"
						cat $RESULTFILE | grep "MB/s"
						FlushDisk
					done
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
	#let NUMANODE1=$(($NUMAFREE1/$FRACTION))
	let NUMANODE1=1000

	let DISKSZ0=$(($NUMAFREE0-$NUMANODE0))
	let DISKSZ1=$(($NUMAFREE1-$NUMANODE1))

	echo "***NODE 0: "$DISKSZ0"****NODE 1: "$DISKSZ1
	$SCRIPTS/mount/releasemem.sh "NODE0"
	$SCRIPTS/mount/releasemem.sh "NODE1"

        numactl --membind=0 $SCRIPTS/mount/reducemem.sh $DISKSZ0 "NODE0"
        numactl --membind=1 $SCRIPTS/mount/reducemem.sh $DISKSZ1 "NODE1"
}



#COMPILE_AND_WRITE
COMPILE


for G_TRIAL in "${trials[@]}"
do
	if [ "$ENABLE_MEM_SENSITIVE" -eq "1" ]
	then
		for MEM_REDUCE_FRAC in "${membudget[@]}"
		do
			GETMEMORYBUDGET $MEM_REDUCE_FRAC
			RUN
			#$SCRIPTS/mount/releasemem.sh "NODE0"
			#$SCRIPTS/mount/releasemem.sh "NODE1"
		done
	else
		RUN
	fi
done


