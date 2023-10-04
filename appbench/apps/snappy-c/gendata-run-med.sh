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

DBDIR=$DBHOME/DATA
RESULTDIR=$DBHOME/OUTPUT
FILECOUNT=100

let gen_data=$1

mkdir -p $DBDIR
mkdir -p $RESULTDIR
mkdir -p $RESULTS

FILESIZE=1000
#declare -a thread_arr=("4" "8" "16" "32")
declare -a thread_arr=("32")
#Number of files to compress
declare -a workload_arr=("100")
# Size of each file in KB
#declare -a filesize_arr=("60000" "80000"  "100000"  "120000"  "140000")
declare -a filesize_arr=("140000")

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


RUN() {
	cd $DBHOME
	
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
				    exit
				fi
				FlushDisk
				done
			done
		done
}

RUN
exit
