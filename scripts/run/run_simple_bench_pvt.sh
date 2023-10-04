#!/bin/bash
set +x

if [ -z "$APPS" ]; then
        echo "APPS environment variable is undefined."
        echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
        exit 1
fi

##This script would run strided MADBench and collect its results
source $RUN_SCRIPTS/generic_funcs.sh

experiment=$1 #which preload library to call
out_base=$2 #base output folder

base=$APPS/simple_bench/multi_thread_read

declare -a nproc=("1" "2" "4" "8" "16")
declare -a filesize=("40") ##GB
declare -a read_size=("20") ## in pages
declare -a workload_arr=("read_pvt_strided") ##read binaries

NR_STRIDE=64 ##In pages, only relevant for strided

#Compiles the application
COMPILE_APP() {
        pushd $base
        CREATE_OUTFOLDER $base/bin
        make -j SIZE=$1 NR_READ_PAGES=$2 NR_THREADS=$3 NR_STRIDE=$NR_STRIDE
        popd
}

#deletes all the Read files
CLEAR_FILES() {
        pushd $base
        rm -rf bigfakefile*
        popd
}


CLEAN_AND_WRITE() {
        printf "in ${FUNCNAME[0]}\n"

        UNSETPRELOAD
        CLEAR_FILES

        pushd $base
        $base/bin/write_pvt
        popd

        FlushDisk
}

#Checks if the OUTFILE exists, 
TOUCH_OUTFILE(){
        if [[ ! -e $1 ]]; then
                touch $1
                echo "AppThreads,${experiment}-min,${experiment}-avg,${experiment}-max" > $1
        else
                echo "$1 Exists!"
        fi

}


RUNAPP() {
        printf "in ${FUNCNAME[0]}\n"
        COMMAND="$base/bin/$WORKLOAD"
        echo $COMMAND
        min_bw=100000000
        max_bw=0
        avg_bw=0
        this_bw=0

        for a in $(seq 1 $NR_REPEATS)
        do
                pushd $base
                SETPRELOAD $experiment ##set preload lib based on experiment
                $COMMAND &> ~/tmp
                UNSETPRELOAD
                popd
                echo "Done running the app"
                #########################
                #update raw data for reference
                echo $COMMAND >> ${OUTFILE}_raw
                cat ~/tmp >> ${OUTFILE}_raw
                #########################
                #cat ~/tmp
                this_bw=`cat ~/tmp | grep "Bandwidth" | head -1 | awk '{print $4}'`
                echo "This bandwidth =" $this_bw
                ##########################
                min_bw=$(min_number $this_bw $min_bw)
                max_bw=$(max_number $this_bw $max_bw)
                avg_bw=`echo "scale=2; $avg_bw + $this_bw" | bc -l`
                ##########################
                REFRESH
        done
        avg_bw=`echo "scale=2; $avg_bw/$NR_REPEATS" | bc -l`
        printf "$NPROC,$min_bw,$avg_bw,$max_bw\n" >> ${OUTFILE}
}


for NPROC in "${nproc[@]}"
do
        echo "NPROC=$NPROC"
        for READ_SIZE in "${read_size[@]}"
        do
                for FILESIZE in "${filesize[@]}"
                do
                        COMPILE_APP $FILESIZE $READ_SIZE $NPROC
                        CLEAN_AND_WRITE
                        for WORKLOAD in "${workload_arr[@]}"
                        do
                                echo "######################################################,"
                                echo "Filesize=$FILESIZE, load=$WORKLOAD, Experiment=$experiment NPROC=$NPROC Readsz=$READ_SIZE"
                                OUTFOLDER=$out_base/$WORKLOAD
                                CREATE_OUTFOLDER $OUTFOLDER
                                OUTFILENAME="filesz-${FILESIZE}_Readsz-${READ_SIZE}"
                                OUTFILE=$OUTFOLDER/$OUTFILENAME
                                TOUCH_OUTFILE $OUTFILE

                                REFRESH
                                RUNAPP 
                        done
                done
        done
done
