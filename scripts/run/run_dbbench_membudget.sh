#!/bin/bash

##This script runs rocksdb with increasing memory budgets

set +x

if [ -z "$APPS" ]; then
	echo "APPS environment variable is undefined."
	echo "Did you setvars? goto Base directory and $ source ./scripts/setvars.sh"
	exit 1
fi

##This script would run strided MADBench and collect its results
source $RUN_SCRIPTS/generic_funcs.sh

base=$APPS/rocksdb
DBDIR=$base/DATA

experiment=$1 #which library to call
out_base=$2 #base output folder

SYNC=0 ##Call sync when writing
WRITE_BUFF_SIZE=67108864

##Keep everything same other than memory budget
declare -a value_size_arr=("4096")
declare -a key_size_arr=("1000")
declare -a num_arr=("1000000") ## Num of elements in DB
declare -a workload_arr=("readseq" "readrandom") ##kinds of db_bench workloads
declare -a nproc=("16")

declare -a memory_budget_percent=("0.2" "0.5" "0.7" "1" "2")

# Memory Budget = total_anon_MB + (total_cache_MB * memory_budget_percent)
# higher means more memory limit

WRITEARGS="--benchmarks=fillrandom --use_existing_db=0 --threads=1"
ORI_PARAMS="--db=$DBDIR --wal_dir=$DBDIR/WAL_LOG --sync=$SYNC --write_buffer_size=$WRITE_BUFF_SIZE"
ORI_READARGS="--use_existing_db=1 --mmap_read=0"

#updated by lib_memusage
total_anon_MB=0
total_cache_MB=0
slack_MB=1024

#Compiles the application
COMPILE_APP() {
	pushd $base
	./compile.sh
	popd
}

#deletes all the database files
CLEAR_DB()
{
	pushd $DBDIR
	rm -rf *.sst CURRENT IDENTITY LOCK MANIFEST-* OPTIONS-* WAL_LOG/
	popd
}


CLEAN_AND_WRITE()
{
	printf "in ${FUNCNAME[0]}\n"

	UNSETPRELOAD
	CLEAR_DB
	$base/db_bench $PARAMS $WRITEARGS
	FlushDisk

	##Condition the DB to get Stable results
	echo "Reading DB Twice to Stabalize results"
	$base/db_bench $PARAMS $ORI_READARGS --benchmarks=readseq --threads=16
	FlushDisk

	SETPRELOAD "MEMUSAGE"
	$base/db_bench $PARAMS $ORI_READARGS --benchmarks=readseq --threads=16 &> out_memusage
	UNSETPRELOAD
	FlushDisk

        cat out_memusage

	##update the total anon and cache usage for this app
	total_anon_MB=`cat out_memusage | grep "total_anon_used" | awk '{print $2}'`
	total_cache_MB=`cat out_memusage | grep "total_anon_used" | awk '{print $5}'`

	printf "in ${FUNCNAME[0]}: $total_anon_MB, $total_cache_MB\n"

}


#Checks if the OUTFILE exists, 
TOUCH_OUTFILE(){
	if [[ ! -e $1 ]]; then
		touch $1
		echo "MemBudget,${experiment}-min,${experiment}-avg,${experiment}-max" > $1
	else
		echo "$1 Exists!"
	fi

}

#COMPILE_APP

RUNAPP() {
	COMMAND="$APPPREFIX $base/db_bench $PARAMS $READARGS"
	echo "Running: $COMMAND"
	#echo $COMMAND
	min_bw=100000000
	max_bw=0
	avg_bw=0
	this_bw=0

	for a in $(seq 1 $NR_REPEATS)
	do
		SETPRELOAD $experiment ##set preload lib based on experiment
		$COMMAND &> tmp
		UNSETPRELOAD
		#########################
		#update raw data for reference
		echo $COMMAND >> ${OUTFILE}_raw
		cat tmp >> ${OUTFILE}_raw
		#########################
		this_bw=`cat tmp | grep "$WORKLOAD" | head -1| awk '{print $7}'`
		echo "this bandwidth = "$this_bw

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


##Run the Application
for NUM in "${num_arr[@]}"
do
	for VALUESIZE in "${value_size_arr[@]}"
	do
		for KEYSIZE in "${key_size_arr[@]}"
		do
			PARAMS="$ORI_PARAMS --value_size=$VALUESIZE --key_size=$KEYSIZE --num=$NUM"
			CLEAN_AND_WRITE

			echo "total_anon_mb = $total_anon_MB"
			echo "total_cache_mb = $total_cache_MB"

			for WORKLOAD in "${workload_arr[@]}"
			do
				echo "######################################################,"
				OUTFOLDER=$out_base/$WORKLOAD
				CREATE_OUTFOLDER $OUTFOLDER

				for NPROC in "${nproc[@]}"
				do
					echo "Num=$NUM, Valuesz=$VALUESIZE, KeySize=$KEYSIZE, load=$WORKLOAD, Experiment=$experiment, NPROC=$NPROC"
					OUTFILENAME="num-${NUM}_valuesz-${VALUESIZE}_keysz-${KEYSIZE}_nproc-${NPROC}"
					OUTFILE=$OUTFOLDER/$OUTFILENAME
				        TOUCH_OUTFILE $OUTFILE
					READARGS="$ORI_READARGS --benchmarks=$WORKLOAD --threads=$NPROC"

					for MEM_BUDGET_PER in "${memory_budget_percent[@]}"
					do
						umount_ext4ramdisk
                                                SETUPEXTRAM_1 `echo "scale=0; (($total_anon_MB + ($total_cache_MB*$MEM_BUDGET_PER))+$slack_MB)/1" | bc --mathlib`
						REFRESH
						RUNAPP
					done
				done
			done

		done
	done
done

