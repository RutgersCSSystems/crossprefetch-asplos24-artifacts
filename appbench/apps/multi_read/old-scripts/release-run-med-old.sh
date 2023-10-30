#!/bin/bash
#set -x

if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi

WORKLOAD=shared

##This script would run strided MADBench and collect its results
source $RUN_SCRIPTS/generic_funcs.sh

base=$APPS/simple_bench/multi_thread_read

APPOUTPUTNAME="SIMPLEBENCH"

RESULTS="RESULTS"/$WORKLOAD
RESULTFILE=""

declare -a nproc=("1" "2" "4" "8" "16")
declare -a nproc=("16")
declare -a readsize_arr=("128")
#declare -a workload_arr=("read_pvt_rand" "read_shared_rand" "read_shared_seq" "read_pvt_seq") ##read binaries
declare -a workload_arr=("read_pvt_seq" "read_pvt_rand") 

#declare -a config_arr=("CPBI_sync" "CII_sync" "CIP_sync" "CIPI_sync" "Vanilla" "OSonly")
declare -a config_arr=("Vanilla"  "OSonly" "CII" "CIPI_PERF")

STATS=0 #0 for perf runs and 1 for stats
NR_STRIDE=4 ##In pages, only relevant for strided
FILESIZE=20 ##GB

echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

G_TRIAL="TRIAL1"

#Require for large database
ulimit -n 1000000
#declare -a trials=("TRIAL1" "TRIAL2" "TRIAL3")
declare -a trials=("TRIAL1")
declare -a membudget=("4")

USEDB=0
MEM_REDUCE_FRAC=0
ENABLE_MEM_SENSITIVE=0

#Compiles the application
COMPILE_APP() {
        pushd $base
        CREATE_OUTFOLDER $base/bin
        make -j SIZE=$1 NR_READ_PAGES=$2 NR_THREADS=$3 NR_STRIDE=$NR_STRIDE &>> compile.out
        popd
}

#deletes all the Read files
CLEAR_FILES() {
        pushd $base
        rm -rf ./threads_*/
        popd
}

#takes Workload and filesize
CLEAN_AND_WRITE() {
    printf "in ${FUNCNAME[0]}\n"

    UNSETPRELOAD
    pushd $base

    #echo "IN CLEAN_AND_WRITE $1 $2"

    if [[ "$1" == *"shared"* ]]; then
        echo "Shared File"
        FILENAME="./threads_1/bigfakefile0.txt"
        FILESZ=$(stat -c %s $FILENAME)
        FILESIZE_WANTED=`echo "$2*$GB" | bc`

        #echo "FILESIZE: $FILESZ FILESIZE_WANTED: $FILESIZE_WANTED"

        if [[ -z ${FILESZ} ]];
        then
            FILESZ=0
        fi

        if [ "$FILESZ" -ne "$FILESIZE_WANTED" ]; then
            CLEAR_FILES
            #echo "FILESIZE: $FILESZ FILESIZE_WANTED: $FILESIZE_WANTED"
            $base/bin/write_shared
        fi
    else
        #echo "Pvt Files"
        CLEAR_FILES
        $base/bin/write_pvt
    fi

    popd

    FlushDisk
}

GEN_RESULT_PATH() {
        WORKLOAD=$1
        CONFIG=$2
        THREAD=$3
	READSIZE=$4
        if [ "$STATS" -eq "1" ]; then
                RESULTS=$OUTPUTDIR"-"$G_TRIAL/${APPOUTPUTNAME}_STATS/$WORKLOAD"-READSIZE-"$READSIZE/$THREAD/
        else
                RESULTS=$OUTPUTDIR"-"$G_TRIAL/${APPOUTPUTNAME}/$WORKLOAD"-READSIZE-"$READSIZE/$THREAD/
        fi
        mkdir -p $RESULTS
        RESULTFILE=$RESULTS/$CONFIG.out
}

RUN() {
        #echo "STARTING to RUN"
	cd $PREDICT_LIB_DIR
	$PREDICT_LIB_DIR/compile.sh &> compile.out
	cd $base

        for READSIZE in "${readsize_arr[@]}"
        do
		sed -i "/NR_READ_PAGES_VAR=/c\NR_READ_PAGES_VAR=$READSIZE" compile.sh

		for NPROC in "${nproc[@]}"
		do
			sed -i "/NR_THREADS_VAR=/c\NR_THREADS_VAR=$NPROC" compile.sh

				for WORKLOAD in "${workload_arr[@]}"
				do

					COMPILE_APP $FILESIZE $READSIZE $NPROC
					CLEAN_AND_WRITE $WORKLOAD $FILESIZE


					for CONFIG in "${config_arr[@]}"
					do
						#echo "######################################################,"
						#echo "Filesize=$FILESIZE, load=$WORKLOAD, Experiment=$experiment NPROC=$NPROC Readsz=$READSIZE"
						GEN_RESULT_PATH $WORKLOAD $CONFIG $NPROC $READSIZE

						#if [ "$STATS" -eq "1" ]; then
						 #       ENABLE_LOCK_STATS
						#fi

						`./clearcache.sh`

						#echo $RESULTFILE
						export LD_PRELOAD=/usr/lib/lib_$CONFIG.so
						$base/bin/$WORKLOAD &> $RESULTFILE
						export LD_PRELOAD=""

						#if [ "$STATS" -eq "1" ]; then
						#        DISABLE_LOCK_STATS
						#fi

						#sudo dmesg -c &>> $RESULTFILE
						#sudo cat /proc/lock_stat &>> $RESULTFILE
						REFRESH
					done
				done
			done
		done
}


for G_TRIAL in "${trials[@]}"
do
	RUN
done

rm -rf compile.out
