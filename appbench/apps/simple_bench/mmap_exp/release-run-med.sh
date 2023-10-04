#!/bin/bash
#set -x

if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi

##This script would run strided MADBench and collect its results
base=$APPS/simple_bench/mmap_exp
APPOUTPUTNAME="SIMPLEBENCH"
OUTPUTDIR="MMAPRESULT"

RESULTS="RESULTS"/$WORKLOAD
RESULTFILE=""

declare -a nprocess=("32")
declare -a workload_arr=("read_shared_mmap_seq" "read_shared_mmap_rand") ##read binariesa
#declare -a workload_arr=("read_shared_mmap_seq") ##read binariesa
declare -a config_arr=("Vanilla" "OSonly" "CIPI_mmap")
#declare -a config_arr=("CII")


STATS=0 #0 for perf runs and 1 for stats
NR_STRIDE=64 ##In pages, only relevant for strided

echo 0 | sudo tee /proc/sys/kernel/randomize_va_space

G_TRIAL="TRIAL1"

#Require for large database
ulimit -n 1000000
declare -a trials=("TRIAL1")
declare -a membudget=("4")

USEDB=0
MEM_REDUCE_FRAC=0
ENABLE_MEM_SENSITIVE=0


FlushDisk()
{
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sleep 5
}

#deletes all the Read files
CLEAR_FILES() {
        pushd $base
        rm -rf ./threads_*/
        popd
}

GEN_RESULT_PATH() {
    WORKLOAD=$1
    CONFIG=$2

    RESULTS="RESULTS"/$WORKLOAD

    mkdir -p $RESULTS
    RESULTFILE=$RESULTS/$CONFIG.out
}

RUN() {
    echo "STARTING to RUN"

    cd $PREDICT_LIB_DIR
    $PREDICT_LIB_DIR/compile.sh &> compile.out
    cd $base

    #./compile.sh

    echo "COMPILE_APP"
    ./compile.sh &>> compile.out


    echo "write big file data"
    if [ -f "$base/threads_1/bigfakefile0.txt"  ]; then
        echo "big test file is there"
    else
        $base/bin/write_shared
    fi

    for WORKLOAD in "${workload_arr[@]}"
    do
        for CONFIG in "${config_arr[@]}"
        do
            echo "######################################################,"
            #echo "Filesize=$FILESIZE, load=$WORKLOAD, Experiment=$experiment NPROC=$NPROC Readsz=$READSIZE"
            echo "load=$WORKLOAD, config=$CONFIG"

            GEN_RESULT_PATH $WORKLOAD $CONFIG 

            FlushDisk

            echo $RESULTFILE
            export LD_PRELOAD=/usr/lib/lib_$CONFIG.so

            if [ "$CONFIG" == "OSonly" ]
            then
                $base/bin/$WORKLOAD"_"osonly &> $RESULTFILE
            else
                $base/bin/$WORKLOAD &> $RESULTFILE
            fi

            export LD_PRELOAD=""
            cat $RESULTFILE | grep "MB/sec"
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
