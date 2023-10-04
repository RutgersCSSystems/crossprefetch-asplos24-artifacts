#!/bin/bash
set -x

if [ -z "$APPS" ]; then
    echo "APPS environment variable is undefined."
    echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
    exit 1
fi

source $RUN_SCRIPTS/generic_funcs.sh

NPROC=$1
EXPERIMENT=$2
OUTPUT=$3


APPHOME=$APPS/libgrape-lite
DATA=datagen-8_5-fb
#DATA=datagen-7_9-fb
DATAFOLDER=$APPHOME/dataset/$DATA


PRELOAD="/usr/bin/time -v"
#PRELOAD="/usr/lib/libcrosslayer.so"

APP=pagerank


CACHESTATFN()
{
  sudo killall cachestat
  sudo killall cachestat
  sudo /usr/bin/cachestat &> $OUTPUT/"CACHESTAT-"$DATA &
}

BUILD_LIB()
{
        cd $SHARED_LIBS/pred
        ./compile.sh
        cd $APPHOME/build
}



FlushDisk()
{
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
}

BUILD_LIB
FlushDisk
FlushDisk

CACHESTATFN


#LD_PRELOAD=$PRELOAD mpirun -n 8 ./run_app --vfile ../dataset/$DATA/$DATA".v" --efile  ../dataset/$DATA/$DATA".e" --application $APP --sssp_source 6 --out_prefix ./output_sssp --directed
$PRELOAD mpirun -n $NPROC ./run_app --vfile $DATAFOLDER/$DATA".v" --efile $DATAFOLDER/$DATA".e" --application $APP --sssp_source 6 --out_prefix ./output_sssp --directed

sudo killall cachestat
sudo killall cachestat
