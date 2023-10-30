#!/bin/bash

if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi

##This script would run strided MADBench and collect its results
source $RUN_SCRIPTS/generic_funcs.sh

APPOUTPUTNAME="simplebench"
RESULTFILE=""

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
FILESIZE=200 ##GB
NR_RA_PAGES=2560L #nr_pages
NR_READ_PAGES=512
##These need to be equivalent of the above
RA_SIZE=10M ##MB
READ_SIZE=2M ##MB

APP="./bin/read_pvt_rand"

#declare -a nproc=("16" "4" "8" "1" "32")
declare -a nproc=("16")


#deletes all the Read files
CLEAR_FILES() {
        rm -rf ./threads_*/
}

#Compiles the application
COMPILE_APP() {
        CREATE_OUTFOLDER ./bin
        make -j SIZE=$FILESIZE NR_READ_PAGES=$NR_READ_PAGES NR_THREADS=$1 NR_STRIDE=$NR_STRIDE NR_RA_PAGES=$NR_RA_PAGES
}


#takes Workload and filesize
CLEAN_AND_WRITE() {
        printf "in ${FUNCNAME[0]}\n"

        UNSETPRELOAD

        CLEAR_FILES
        ./bin/write_pvt

        FlushDisk
}


VanillaRA() {
        echo "Read Shared Seq Vanilla RA"
        FlushDisk
        export LD_PRELOAD="/usr/lib/lib_Vanilla.so"
        ./bin/read_shared_seq_vanilla
	${APP}_vanilla
        export LD_PRELOAD=""
        sudo dmesg -c
}

Vanilla() {
        echo "Vanilla"
        FlushDisk
        export LD_PRELOAD="/usr/lib/lib_Vanilla.so"
	${APP}  &> $RESULTFILE
        export LD_PRELOAD=""
        sudo dmesg -c
}

OSonly() {
        echo "OS Only"
        FlushDisk
        export LD_PRELOAD="/usr/lib/lib_OSonly.so"
	${APP} &> $RESULTFILE
        export LD_PRELOAD=""
        sudo dmesg -c
}

CIPI_PERF() {
        echo "Cross Info"
        FlushDisk
        export LD_PRELOAD="/usr/lib/lib_CIPI_PERF.so"
	${APP} &> $RESULTFILE
        export LD_PRELOAD=""
        sudo dmesg -c
}

CII() {
        echo "Cross Info Fetch All"
        FlushDisk
        export LD_PRELOAD="/usr/lib/lib_CII.so"
	${APP} &> $RESULTFILE
        export LD_PRELOAD=""
        sudo dmesg -c
}


CIPI_PERF_NOOPT() {
        echo "CIPI NOOPT"
        FlushDisk

        export LD_PRELOAD="/usr/lib/lib_CIPI_PERF_NOOPT.so"
        ${APP} &> $RESULTFILE
        export LD_PRELOAD=""
        sudo dmesg -c

}

CIP() {
        echo "Cross Info Mo OPT"
        FlushDisk
        export LD_PRELOAD="/usr/lib/lib_CIP.so"
	${APP} &> $RESULTFILE
        export LD_PRELOAD=""
        sudo dmesg -c
}

MINCORE() {
        echo "Mincore"
        FlushDisk
        export LD_PRELOAD=""
        ${APP}_mincore
        export LD_PRELOAD=""
        sudo dmesg -c
}

GEN_RESULT_PATH() {
        WORKLOAD=$1
        CONFIG=$2
        THREAD=$3
        RESULTS=$OUTPUTDIR/$APPOUTPUTNAME/$WORKLOAD/$THREAD
        mkdir -p $RESULTS
        RESULTFILE=$RESULTS/$CONFIG.out
}


for NPROC in "${nproc[@]}"
do
        COMPILE_APP $NPROC
        CLEAN_AND_WRITE

        #FILENAMEBASE="stats_pvt_rand_${READ_SIZE}r_${RA_SIZE}pgra_$NPROC"
        #VanillaRA &> VanillaRA_${FILENAMEBASE}
        #VanillaOPT &> VanillaOPT_${FILENAMEBASE}

	RESULTFILE=""
	GEN_RESULT_PATH "pvt_rand" "CIPI_PERF_NOOPT" $NPROC
        CIPI_PERF_NOOPT

	RESULTFILE=""
	GEN_RESULT_PATH "pvt_rand" "CII" $NPROC
        CII


	RESULTFILE=""
	GEN_RESULT_PATH "pvt_rand" "Vanilla" $NPROC
        Vanilla

	RESULTFILE=""
	GEN_RESULT_PATH "pvt_rand" "OSonly" $NPROC
        OSonly 


	RESULTFILE=""
        GEN_RESULT_PATH "pvt_rand" "CIPI_PERF" $NPROC
	CIPI_PERF 

        #MINCORE &> MINCORE_${FILENAMEBASE}
done

