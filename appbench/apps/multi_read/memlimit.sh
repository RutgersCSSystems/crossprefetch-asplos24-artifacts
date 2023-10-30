#!/bin/bash

if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi

##This script would run strided MADBench and collect its results
source $RUN_SCRIPTS/generic_funcs.sh

declare -a experiment=("VANILLA" "CBNMB" "CBNBB" "CBPBB" "CBPMB" "CFPMB")
declare -a mem_budget=("0.2" "0.5" "0.7" "1" "2")

#WORKLOAD="read_seq"
#WORKLOAD="read_shared_strided"
#WRITE_LOAD="write_shared"

WORKLOAD="read_pvt_strided"
WRITE_LOAD="write_pvt"

FILESIZE=40 ##in GB
READ_SIZE=40 ## In pages
THREAD=16
NR_STRIDE=64
#MEM_BUD=0.5

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

#Checks if the OUTFILE exists, 
TOUCH_OUTFILE(){
        if [[ ! -e $1 ]]; then
                touch $1
                echo -n "MemoryBudget" > $1
                for EXPERIMENT in "${experiment[@]}"
                do
                        echo -n ",$EXPERIMENT" >> $1
                done
                echo >> $1
        else
                echo "$1 Exists!"
        fi
}

umount_ext4ramdisk

COMPILE_APP $FILESIZE $READ_SIZE $THREAD $NR_STRIDE
#CLEAN_AND_WRITE
FlushDisk

COMMAND="./bin/$WORKLOAD"

anon=100
cache=40960


OUTFILENAME="filesz-${FILESIZE}_Readsz-${READ_SIZE}_nproc-${THREAD}_Stride-${NR_STRIDE}"
OUTFILE=./$OUTFILENAME
TOUCH_OUTFILE $OUTFILE

for MEM_BUD in "${mem_budget[@]}"
do
        echo -n "$MEM_BUD" >> $OUTFILE
        SETUPEXTRAM_1 `echo "scale=0; ($anon + ($cache * $MEM_BUD))/1" | bc --mathlib`

        for EXPERIMENT in "${experiment[@]}"
        do
                SETPRELOAD $EXPERIMENT
                $COMMAND > tmp
                export LD_PRELOAD=""
                this_bw=`cat tmp | grep "Bandwidth" | head -1 | awk '{print $4}'`
                FlushDisk
                cat tmp
                echo "$this_bw"
                echo -n ",$this_bw" >> $OUTFILE
        done
        umount_ext4ramdisk
        echo >> $OUTFILE
done
exit
