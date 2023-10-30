#!/bin/bash

if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi

##This script would run strided MADBench and collect its results
source $RUN_SCRIPTS/generic_funcs.sh

#declare -a membudget=("0.2" "0.5" "0.7" "1" "2")
#declare -a membudget=("0.2" "0.5" "0.7")

#WORKLOAD="read_seq"
#WORKLOAD="read_shared_strided"
#WRITE_LOAD="write_shared"

WORKLOAD="read_pvt_strided"
WRITE_LOAD="write_pvt"

FILESIZE=40 ##in GB
READ_SIZE=40 ## In pages
THREAD=16
NR_STRIDE=64
MEM_BUD=0.5

#declare -a filesize=("40")

#deletes all the Read files
CLEAR_FILES() {
        rm -rf bigfakefile*
}

#Compiles the application
COMPILE_APP() {
        CREATE_OUTFOLDER ./bin
        echo $NR_STRIDE
        make -j SIZE=$1 NR_READ_PAGES=$2 NR_THREADS=$3 NR_STRIDE=$4
}


CLEAN_AND_WRITE() {
        printf "in ${FUNCNAME[0]}\n"

        UNSETPRELOAD
        CLEAR_FILES

        ./bin/${WRITE_LOAD}

        FlushDisk
}


umount_ext4ramdisk

COMPILE_APP $FILESIZE $READ_SIZE $THREAD $NR_STRIDE
CLEAN_AND_WRITE
FlushDisk

COMMAND="./bin/$WORKLOAD"

printf "\nRUNNING Memlimit.................\n"
SETPRELOAD "VANILLA"
#export LD_PRELOAD=/usr/lib/lib_memusage.so
$COMMAND
export LD_PRELOAD=""
FlushDisk

anon=100
cache=40960

free -h
SETUPEXTRAM_1 `echo "scale=0; ($anon + ($cache * $MEM_BUD))/1" | bc --mathlib`

#for MEM_BUD in "${membudget[@]}"
#do

        free -h

        printf "\nRUNNING VANILLA.................\n"
        SETPRELOAD "VANILLA"
        #SETPRELOAD "CBNMB"
        $COMMAND
        export LD_PRELOAD=""
        FlushDisk

        printf "\nRUNNING CROSS_BLOCKRA_NOPRED_MAXMEM_BG................\n"
        SETPRELOAD "CBNMB"
        #SETPRELOAD "VANILLA"
        $COMMAND
        export LD_PRELOAD=""
        FlushDisk

        printf "\nRUNNING CROSS_BLOCKRA_NOPRED_BUDGET_BG................\n"
        SETPRELOAD "CBNBB"
        $COMMAND
        export LD_PRELOAD=""
        FlushDisk

        printf "\nRUNNING CROSS_BLOCKRA_PRED_BUDGET_BG................\n"
        SETPRELOAD "CBPBB"
        $COMMAND
        export LD_PRELOAD=""
        FlushDisk

        printf "\nRUNNING CROSS_BLOCKRA_PRED_MAXMEM_BG................\n"
        SETPRELOAD "CBPMB"
        $COMMAND
        export LD_PRELOAD=""
        FlushDisk

        printf "\nRUNNING CROSS_FILERA_PRED_MAXMEM_BG................\n"
        SETPRELOAD "CFPMB"
        $COMMAND
        export LD_PRELOAD=""
        FlushDisk

        umount_ext4ramdisk
#done
