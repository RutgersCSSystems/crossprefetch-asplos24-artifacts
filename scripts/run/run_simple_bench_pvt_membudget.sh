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

declare -a nproc=("16")
declare -a filesize=("40") ##GB
declare -a read_size=("20") ## in pages
declare -a workload_arr=("read_pvt_seq") ##read binaries
#read_pvt_rand, read_pvt_strided, read_pvt_seq

declare -a memory_budget_percent=("0.2" "0.5" "0.7" "1" "2")

NR_STRIDE=64

#updated by lib_memusage
total_anon_MB=0
total_cache_MB=0

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

        echo "Checking Memory Usage"
        pushd $base
	SETPRELOAD "MEMUSAGE"
        $base/bin/read_pvt_seq &> ~/out_memusage
	UNSETPRELOAD
        popd
        FlushDisk

	##update the total anon and cache usage for this app
	total_anon_MB=`cat ~/out_memusage | grep "total_anon_used" | awk '{print $2}'`
	total_cache_MB=`cat ~/out_memusage | grep "total_anon_used" | awk '{print $5}'`


	printf "in ${FUNCNAME[0]}: Membudget Anon:$total_anon_MB MB, Cache:$total_cache_MB MB\n"
}

STABALIZE() {

        #Stabalizing Results
        pushd $base
	SETPRELOAD "VANILLA"
        $base/bin/read_pvt_seq
	UNSETPRELOAD
        FlushDisk

	SETPRELOAD "VANILLA"
        $base/bin/read_pvt_seq
	UNSETPRELOAD
        FlushDisk
        popd

}

#Checks if the OUTFILE exists, 
TOUCH_OUTFILE(){
        if [[ ! -e $1 ]]; then
                touch $1
                echo "MemoryBudget,${experiment}-min,${experiment}-avg,${experiment}-max" > $1
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
                REFRESH
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
                this_bw=`cat ~/tmp | grep "Bandwidth" | head -1 | awk '{print $4}'`
                echo "This bandwidth =" $this_bw
		is_number $this_bw
		if [[ $? -eq 0 ]]; then
			##If this_bw is not a number try again
			continue
		fi
                ##########################
                min_bw=$(min_number $this_bw $min_bw)
                max_bw=$(max_number $this_bw $max_bw)
                avg_bw=`echo "scale=2; $avg_bw + $this_bw" | bc -l`
                ##########################
                REFRESH
        done
        avg_bw=`echo "scale=2; $avg_bw/$NR_REPEATS" | bc -l`
        printf "$MEM_BUDGET_PER,$min_bw,$avg_bw,$max_bw\n" >> ${OUTFILE}
}


for READ_SIZE in "${read_size[@]}"
do
        for FILESIZE in "${filesize[@]}"
        do
                for NPROC in "${nproc[@]}"
                do
                        COMPILE_APP $FILESIZE $READ_SIZE $NPROC
                        CLEAN_AND_WRITE

			echo "total_anon_mb = $total_anon_MB"
			echo "total_cache_mb = $total_cache_MB"

                        for WORKLOAD in "${workload_arr[@]}"
                        do
                                echo "######################################################"
                                echo "Filesize=$FILESIZE, load=$WORKLOAD, Experiment=$experiment NPROC=$NPROC Readsz=$READ_SIZE"
                                echo "######################################################"

                                OUTFOLDER=$out_base/$WORKLOAD
                                CREATE_OUTFOLDER $OUTFOLDER
                                OUTFILENAME="filesz-${FILESIZE}_Readsz-${READ_SIZE}_nproc-${NPROC}"
                                OUTFILE=$OUTFOLDER/$OUTFILENAME
                                TOUCH_OUTFILE $OUTFILE

				for MEM_BUDGET_PER in "${memory_budget_percent[@]}"
				do
					umount_ext4ramdisk
					SETUPEXTRAM_1 `echo "scale=0; ($total_anon_MB + ($total_cache_MB*$MEM_BUDGET_PER))/1" | bc --mathlib`
                                        STABALIZE

					REFRESH
					RUNAPP

                                done
                        done
                done
        done
done
