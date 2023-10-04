#!/bin/bash
set -x
DBHOME=$PWD
THREAD=4
WORKLOAD="snappy-threads"
APPPREFIX="/usr/bin/time -v"

APP="snappy"
APPOUTPUTNAME="snappy"

RESULTS="RESULTS"/$WORKLOAD
RESULTFILE=""

DBDIR=$SHARED_DATA/snappy
RESULTDIR=$SHARED_DATA/$APP/
FILECOUNT=100

let gen_data=$1
mkdir -p $RESULTS

FILESIZE=1000
#declare -a thread_arr=("4" "8" "16" "32")
declare -a thread_arr=("32")
#Number of files to compress
declare -a workload_arr=("100")
# Size of each file in KB
declare -a filesize_arr=("60000" "80000"  "100000"  "120000"  "140000")
declare -a filesize_arr=("60000")

declare -a prefech_sz_arr=("1024" "512" "2048" "4096")
declare -a prefech_thrd_arr=("1" "4" "8" "16")

#Pass these arguments as a global variable
workload_arr_in=$2
config_arr_in=$3
thread_arr_in=$4

glob_prefetchsz=1024
glob_prefechthrd=1
#enable sensitivity study?
let glob_enable_sensitive=0

MEM_REDUCE_FRAC=1
ENABLE_MEM_SENSITIVE=1
declare -a membudget=("6" "4" "2" "1")
declare -a config_arr=("OSonly" "CIPI_PERF" "CPBI_PERF" "Vanilla")
declare -a config_arr=("CIPI_PERF" "CPBI_PERF")
declare -a thread_arr=("32")

enable_prefetch_sensitivity() {
	prefech_sz_arr=("2048")
	prefech_thrd_arr=("4")
}

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
        sleep 2
}

CLEAR_DATA()
{
        sudo killall $APP
        sudo killall $APP
        sleep 3
        sudo killall $APP
        rm -rf $DBDIR/OUT*
}


GENDATA() {

        filesize=$1
	numfiles=$2
        threads=$3


        let file_perthread=$numfiles/$threads
        echo $file_perthread

        for (( t=1; t<=$threads; t++ ))
        do
                DIR=$DBDIR/$t

                mkdir -p $DIR
		cd $DIR
                echo $numfiles
                rm *
		cd $DBHOME
                $DBHOME/gen_file_posix $numfiles $filesize $DIR
        done
}


COMPILE_SHAREDLIB() {
        cd $PREDICT_LIB_DIR
        $PREDICT_LIB_DIR/compile.sh &> compile.out
        cd $DBHOME 
}

COMPILE_AND_WRITE()
{

        echo "..........BEGIN DATA GENERATION..............."
        export LD_PRELOAD=""
	mkdir -p $RESULTS

        filesize=$1
	numfiles=$2
        threads=$3

	COMPILE_SHAREDLIB

	#Generate data
	GENDATA $filesize $numfiles $threads
	sudo dmesg -c &> del.txt
	rm del.txt

        echo "..........END DATA GENERATION..............."
}

GEN_RESULT_PATH() {
	WORKPATH=$1
	CONFIG=$2
	THREAD=$3
        RESULTS=$OUTPUTDIR/$APPOUTPUTNAME/$WORKPATH/$THREAD
	mkdir -p $RESULTS

        if [ "$ENABLE_MEM_SENSITIVE" -eq "1" ]
        then
                RESULTS=$OUTPUTDIR/$APPOUTPUTNAME/"MEMFRAC"$MEM_REDUCE_FRAC/$WORKLOAD/$THREAD/
		mkdir -p $RESULTS
		RESULTFILE=$RESULTS/$CONFIG".out"

	elif [ $glob_enable_sensitive -gt 0 ]; then
		RESULTFILE=$RESULTS/$CONFIG"-PREFETCHSZ-$prefetchsz-PREFETTHRD-$prefechthrd".out
	else
		RESULTFILE=$RESULTS/$CONFIG".out"
	fi
}



RUN() {
        #COMPILE_SHAREDLIB
        cd $PREDICT_LIB_DIR

	if [ $glob_enable_sensitive -gt 0 ]; then
		sed -i "/NR_WORKERS_VAR=/c\NR_WORKERS_VAR=$prefechthrd" compile.sh
		sed -i "/PREFETCH_SIZE_VAR=/c\PREFETCH_SIZE_VAR=$prefetchsz" compile.sh
	fi

	./compile.sh &> out.txt
	cd $DBHOME
	
	#NUMFILES
	for WORKLOAD in "${workload_arr[@]}"
	do
		#FILESIZE represents file size in bytes
		for FILESIZE in "${filesize_arr[@]}"
		do
			for THREAD in "${thread_arr[@]}"
			do
				PARAMS="$DBDIR $THREAD"

				if [ $gen_data -gt 0 ]
				then
				    echo "GENERATING NEW DATA"
				    COMPILE_AND_WRITE $FILESIZE $WORKLOAD $THREAD
				fi

				for CONFIG in "${config_arr[@]}"
				do
					FlushDisk

					RESULTS=""
					GEN_RESULT_PATH "fsize-"$FILESIZE $CONFIG $THREAD

					mkdir -p $RESULTS

					echo "RUNNING $CONFIG and writing results to #$RESULTS/$CONFIG.out"
					echo "..................................................."
					echo "$APPPREFIX $DBHOME/$APP $PARAMS"
	
						
					if [ "$CONFIG" == "Vanilla" ]
					then
						$DBHOME/$APP $PARAMS  &> $RESULTFILE
					else
						LD_PRELOAD=/usr/lib/lib_$CONFIG.so $DBHOME/$APP $PARAMS  &> $RESULTFILE
					fi

					export LD_PRELOAD=""
					sudo dmesg -c &>> $RESULTFILE
					echo ".......FINISHING $CONFIG......................"
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
exit


enable_prefetch_sensitivity()
if [ $glob_enable_sensitive -gt 0 ]; then 
	for glob_prefetchsz in "${prefech_sz_arr[@]}"
	do
		for glob_prefechthrd in "${prefech_thrd_arr[@]}"
		do
			get_global_arr	
			RUN
		done
	done
else
	RUN
fi

#CLEAR_DATA
exit

