#!/bin/bash
#set -x
DBHOME=$PWD
THREAD=16
VALUE_SIZE=4096
SYNC=0
KEYSIZE=1000
WRITE_BUFF_SIZE=67108864
DBDIR=$DBHOME/DATA
ERR=100
#DBDIR=/mnt/remote/DATA


if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi


WORKLOAD="readrandom"
WRITEARGS="--benchmarks=fillseq --use_existing_db=0 --threads=1"
READARGS="--benchmarks=$WORKLOAD --use_existing_db=1 --mmap_read=0 --threads=$THREAD"
APPPREFIX="/usr/bin/time -v"

APP=db_bench
APPOUTPUTNAME="YCSB-ROCKSDB"
RESULTS="RESULTS"/$WORKLOAD
RESULTFILE=""
PARAMS=""

mkdir -p $RESULTS

declare -a num_arr=("10000000")
NUM=10000000

#declare -a thread_arr=("1" "4" "8" "16")
declare -a thread_arr=("16")
declare -a workload_arr=("ycsbwklda" "ycsbwkldb" "ycsbwkldc" "ycsbwkldd" "ycsbwklde")
declare -a config_arr=("CIPI_PERF" "CII" "CIPI" "CIPI_PERF_NOOPT" "Vanilla" "OSonly")
#declare -a config_arr=("CIPI_PERF" "CIPI_PERF_NOOPT")

USEDB=1
#echo "CAUTION, CAUTION, USE EXITING DB is set to 0 for write workload testing!!!"
#echo "CAUTION, CAUTION, USE EXITING DB is set to 0 for write workload testing!!!"

#declare -a config_arr=("Cross_Info" "OSonly" "Vanilla" "Cross_Info_sync" "Cross_Blind" "CII" "CIP" "CIP_sync" "CIPI")
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
	#PARAMS="--db=$DBDIR --value_size=$VALUE_SIZE --wal_dir=$DBDIR/WAL_LOG --sync=$SYNC --key_size=$KEYSIZE --write_buffer_size=$WRITE_BUFF_SIZE --num=$NUM --target_file_size_base=209715200"
       PARAMS="--db=$DBDIR --num_levels=6 --key_size=20 --prefix_size=20 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --benchmarks=fillycsb --use_existing_db=0 --num=$NUM --duration=10 --compression_type=none --value_size=$VALUE_SIZE --threads=1"

	mkdir -p $RESULTS

	cd $PREDICT_LIB_DIR
	$PREDICT_LIB_DIR/compile.sh &> compile.out
	cd $DBHOME
        $DBHOME/db_bench $PARAMS $WRITEARGS #&> $RESULTS/WARMUP-WRITE.out
}



GEN_RESULT_PATH() {
	WORKLOAD=$1
	CONFIG=$2
	THREAD=$3
	let KEYCOUNT=$NUM/1000000
	#WORKLOAD="DUMMY"
	#RESULTFILE=""
        RESULTS=$OUTPUTDIR/$APPOUTPUTNAME/$KEYCOUNT"M-KEYS"/$WORKLOAD/$THREAD
	mkdir -p $RESULTS
	RESULTFILE=$RESULTS/$CONFIG.out
}

WARMPUP() {

	echo "BEGINNING TO WARM UP ......."
	COMPILE_AND_WRITE
	echo "FINISHING WARM UP ......."
	echo "..................................................."
	FlushDisk
	sudo dmesg -c
}


EXECUTE() {

    CONFIG=$1
    #echo "RUNNING $CONFIG $PARAMS $READARGS and writing results to  $RESULTFILE"
    export LD_PRELOAD=/usr/lib/lib_$CONFIG.so
    $APPPREFIX "./"$APP $PARAMARG $ARGS &> $RESULTFILE
    export LD_PRELOAD=""

}

RUN() {
	for NUM in "${num_arr[@]}"
	do
		for THREAD in "${thread_arr[@]}"
		do
			#PARAMS="--db=$DBDIR --value_size=$VALUE_SIZE --wal_dir=$DBDIR/WAL_LOG --sync=$SYNC --key_size=$KEYSIZE --write_buffer_size=$WRITE_BUFF_SIZE --num=$NUM  --seed=1576170874"
			PARAMS="--db=$DBDIR --num_levels=6 --key_size=20 --prefix_size=20 --memtablerep=prefix_hash --bloom_bits=10 --bloom_locality=1 --use_existing_db=1 --num=$NUM --duration=30 --compression_type=none --value_size=$VALUE_SIZE --threads=$THREAD"

			for WORKLOAD in "${workload_arr[@]}"
			do
				#WARMPUP

				for CONFIG in "${config_arr[@]}"
				do
					RESULTS=""
					READARGS="--benchmarks=$WORKLOAD --use_existing_db=$USEDB --mmap_read=0 --threads=$THREAD"
					GEN_RESULT_PATH $WORKLOAD $CONFIG $THREAD $NUM

					mkdir -p $RESULTS

					echo "RUNNING $CONFIG $PARAMS $READARGS and writing results to $RESULTFILE"
					echo "..................................................."

					export LD_PRELOAD=/usr/lib/lib_$CONFIG.so
					$APPPREFIX "./"$APP $PARAMS $READARGS &> $RESULTFILE
					export LD_PRELOAD=""

					cat $RESULTFILE | grep "ops/sec"
					VAL=`cat $RESULTFILE | grep "ops/sec;" | awk '{print $5}'`
					if [ -z "$VAL" ]; then
  						VAL=0
					fi
					if [ "$ERR" -gt "$VAL" ]; then
  					  EXECUTE $CONFIG $PARAMS $READARGS $RESULTFILE
					fi

					sudo dmesg -c &>> $RESULTFILE
					echo ".......FINISHING $CONFIG......................"

					FlushDisk
				done
			done
		done
	done
}

WARMPUP

FlushDisk
FlushDisk
cp PARAMS.sh $PREDICT_LIB_DIR/compile.sh
#cp $PREDICT_LIB_DIR/Makefile $PREDICT_LIB_DIR/Makefile.orig
cp $DBHOME/Makefile.YCSB $PREDICT_LIB_DIR/Makefile
cd $PREDICT_LIB_DIR
$PREDICT_LIB_DIR/compile.sh
FlushDisk
FlushDisk
cd $DBHOME

RUN
cp $PREDICT_LIB_DIR/ORIGMAKEFILE $PREDICT_LIB_DIR/Makefile
cp $PREDICT_LIB_DIR/COMPILEORIG.sh $PREDICT_LIB_DIR/compile.sh
exit

