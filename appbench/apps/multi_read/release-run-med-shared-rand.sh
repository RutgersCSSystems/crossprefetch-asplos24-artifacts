#!/bin/bash

DBHOME=$PWD
let ERR=100

if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi

##This script would run strided MADBench and collect its results
source $RUN_SCRIPTS/generic_funcs.sh

FlushDisk()
{
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sleep 5
        sudo dmesg --clear
}

ENABLE_LOCK_STATS()
{
        sudo sh -c "echo 0 > /proc/lock_stat"
        sudo sh -c "echo 1 > /proc/sys/kernel/lock_stat"
}

DISABLE_LOCK_STATS()
{
        sudo sh -c "echo 0 > /proc/sys/kernel/lock_stat"
}

NR_STRIDE=64 ##In pages, only relevant for strided
FILESIZE=12 ##GB
NR_RA_PAGES=2560L #nr_pages
NR_READ_PAGES=16
#NR_READ_PAGES=512
RESULTFILE=""
APPOUTPUTNAME="simplebench"


declare -a nproc=("16" "32" "8")
declare -a nproc=("16")
declare -a config_arr=("CIPI_PERF" "Vanilla" "OSonly" "CII" "CIPI")
declare -a workload_arr=("read_shared_rand") 

G_TRIAL="TRIAL1"


#deletes all the Read files
CLEAR_FILES() {
        rm -rf ./threads_*/
}

#Compiles the application
COMPILE_APP() {
	cd $PREDICT_LIB_DIR
	make clean &> OUT.txt
	make -j16 &>> OUT.txt
	cd $DBHOME
        CREATE_OUTFOLDER ./bin &> OUT.txt
        make -j SIZE=$FILESIZE NR_READ_PAGES=$NR_READ_PAGES NR_THREADS=$1 NR_STRIDE=$NR_STRIDE NR_RA_PAGES=$NR_RA_PAGES &>>OUT.txt
}


#takes Workload and filesize
CLEAN_AND_WRITE() {
        printf "in ${FUNCNAME[0]}\n"

        UNSETPRELOAD

        CLEAR_FILES
        ./bin/write_shared

        FlushDisk
}

Vanilla() {
        echo "Read Pvt Rand Vanilla RA"
        FlushDisk
        
        #export LD_PRELOAD="/usr/lib/lib_Vanilla.so"
        ./bin/read_shared_rand
        export LD_PRELOAD=""
        
        sudo dmesg -c
        
}

OSonly() {
        echo "OS Only"
        FlushDisk
        
        export LD_PRELOAD="/usr/lib/lib_OSonly.so"
        ./bin/read_shared_rand
        export LD_PRELOAD=""
        
        sudo dmesg -c
        
}

CIPI_PERF() {
        echo "CIPI PERF"
        FlushDisk
        
        export LD_PRELOAD="/usr/lib/lib_CIPI_PERF.so"
        ./bin/read_shared_rand
        export LD_PRELOAD=""
        
        sudo dmesg -c
        
}

CIPI() {
        echo "CIPI PERF NoOPT"
        FlushDisk
        
        export LD_PRELOAD="/usr/lib/lib_CIPI.so"
        ./bin/read_shared_rand
        export LD_PRELOAD=""
        
        sudo dmesg -c
        
}


CrossInfo() {
        echo "Cross Info"
        FlushDisk
        
        export LD_PRELOAD="/usr/lib/lib_Cross_Info.so"
        ./bin/read_shared_rand
        export LD_PRELOAD=""
        
        sudo dmesg -c
        
}

CII() {
        echo "Cross Info IOOPT"
        FlushDisk
        
        export LD_PRELOAD="/usr/lib/lib_CII.so"
        ./bin/read_shared_rand
        export LD_PRELOAD=""
        
        sudo dmesg -c
        
}

CIP() {
        echo "Cross Info Predict"
        FlushDisk
        
        export LD_PRELOAD="/usr/lib/lib_CIP.so"
        ./bin/read_shared_rand
        export LD_PRELOAD=""
        
        sudo dmesg -c
        
}

MINCORE() {
        echo "Mincore"
        FlushDisk
        
        export LD_PRELOAD=""
        ./bin/read_shared_rand_mincore
        export LD_PRELOAD=""
        
        sudo dmesg -c
}

GEN_RESULT_PATH() {
        WORKLOAD=$1
        CONFIG=$2
        THREAD=$3
	READSIZE=$4
        RESULTS=$OUTPUTDIR/${APPOUTPUTNAME}/"shared_rand"/$THREAD/
        mkdir -p $RESULTS
        RESULTFILE=$RESULTS/$CONFIG.out
}


for NPROC in "${nproc[@]}"
do

        cd simple_prefetcher
        ./compile.sh
        cd $DBHOME

        COMPILE_APP $NPROC
        CLEAN_AND_WRITE
	for CONFIG in "${config_arr[@]}"
	do
		for WORKLOAD in "${workload_arr[@]}"
		do
			FlushDisk	
			GEN_RESULT_PATH $WORKLOAD $CONFIG $NPROC $NR_READ_PAGES
			#echo "RUNNING....$WORLOAD.....$CONFIG....$RESULTFILE"
			$CONFIG &> $RESULTFILE
			echo $RESULTFILE
			cat $RESULTFILE | grep "MB/s"
			    VAL=`cat $RESULTFILE | grep "MB/s" | awk '{print $4}'`
			    if [ -z "$VAL" ]; then
				let VAL=0
			    fi
			    if [ "$ERR" -gt "$VAL" ]; then
				    $CONFIG &> $RESULTFILE
			    fi
			#cat $RESULTFILE | grep "MB/s"
			FlushDisk
			#MINCORE &> MINCORE_${FILENAMEBASE}
		done
	done 
done
