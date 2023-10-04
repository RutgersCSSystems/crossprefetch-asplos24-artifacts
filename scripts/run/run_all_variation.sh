#!/bin/bash
set +x

##This script will call variation scripts from different apps
if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi

#sudo apt update; sudo apt install numactl bc 

source $RUN_SCRIPTS/generic_funcs.sh

#declare -a apparr=("strided_madbench" "rocksdb" "graphchi" "ior")
#declare -a apparr=("rocksdb_membudget")
declare -a apparr=("simple_bench_pvt_membudget")

#experiment names should be same as preloadlib names in SETPRELOAD
declare -a experiment=("VANILLA" "OSONLY" "CN" "CNI" "CPNV" "CPNI" "CPBV" "CPBI")

#All available ("VANILLA" "OSONLY" "CN" "CNI" "CPNV" "CPNI" "CPBV" "CPBI")

#Here is where we run the application
RUNAPP()
{
        APP=$1
        EXPERIMENT=$2
        OUTPUT=${OUTPUT_FOLDER}/${APP}/Prefetch_${RIGHTNOW}/${EXPERIMENT}
        #OUTPUT=${OUTPUT_FOLDER}/${APP}/Prefetch_diff_membudget/${EXPERIMENT}
        mkdir -p $OUTPUT

        if [ "$APP" = "strided_madbench" ]; then
                $RUN_SCRIPTS/run_strided_madbench.sh $EXPERIMENT $OUTPUT
        elif [ "$APP" = "graphchi" ]; then
                $RUN_SCRIPTS/run_graphchi.sh $EXPERIMENT $OUTPUT	
        elif [ "$APP" = "fio" ]; then
                $RUN_SCRIPTS/run_fio.sh $EXPERIMENT $OUTPUT
        elif [ "$APP" = "rocksdb" ]; then
                $RUN_SCRIPTS/run_dbbench.sh $EXPERIMENT $OUTPUT
        elif [ "$APP" = "rocksdb_membudget" ]; then
                $RUN_SCRIPTS/run_dbbench_membudget.sh $EXPERIMENT $OUTPUT
        elif [ "$APP" = "simple_bench_pvt" ]; then
                $RUN_SCRIPTS/run_simple_bench_pvt.sh $EXPERIMENT $OUTPUT
        elif [ "$APP" = "simple_bench_pvt_membudget" ]; then
                $RUN_SCRIPTS/run_simple_bench_pvt_membudget.sh $EXPERIMENT $OUTPUT
        elif [ "$APP" = "simple_bench_shared" ]; then
                $RUN_SCRIPTS/run_simple_bench_shared.sh $EXPERIMENT $OUTPUT
        elif [ "$APP" = "libgrape" ]; then
                $RUN_SCRIPTS/run_libgrape.sh $EXPERIMENT $OUTPUT
        fi
}


umount_ext4ramdisk
for APP in "${apparr[@]}"
do
        for EXPERIMENT in "${experiment[@]}"
        do
                REFRESH
                RUNAPP $APP $EXPERIMENT
                REFRESH
        done
done
