#!/bin/bash
#set -x

DBHOME=$PWD
THREAD=4
VALUE_SIZE=4096
SYNC=0
KEYSIZE=1000
WRITE_BUFF_SIZE=67108864
NUM=1000000
DBDIR=$DBHOME/DATA
#APPPREFIX="sudo /usr/bin/time -v"
APP="./filebench"
APPOUTPUTNAME="filebench"

#Enable sensitivity to vary prefetch size and prefetch thread count
ENABLE_SENSITIVITY=0

#WORKLOAD="readseq"
#WORKLOAD="workloads/fileserver.f"
#WORKLOAD="workloads/filemicro_seqread.f"
WORKLOAD="workloads/filemicro_rread.f"
WRITEARGS="-f $WORKLOAD"
READARGS="-f $WORKLOAD"
RESULTS=$OUTPUTDIR/$APP/$WORKLOAD


mkdir -p $RESULTS
#declare -a workload_arr=("filemicro_seqread.f" "videoserver.f" "fileserver.f" "randomrw.f" "randomread.f" "filemicro_rread.f" "mongo.f" "fivestreamread.f")
declare -a workload_arr=("filemicro_seqread.f" "videoserver.f" "fileserver.f" "randomrw.f" "randomread.f" "filemicro_rread.f" "mongo.f" "fivestreamread.f")
declare -a config_arr=("Vanilla" "CIPI" "OSonly")
declare -a workload_arr=("mongo.f")
declare -a workload_arr=("randomrw.f")
declare -a config_arr=("Vanilla" "CIPI" "CIPI_PERF")

declare -a thread_arr=("16")

workload_arr_in=$1
config_arr_in=$2
thread_arr_in=$3

glob_prefetchsz=1024
glob_prefechthrd=8

declare -a prefech_sz_arr=("4096" "2048" "1024" "512")
declare -a prefech_thrd_arr=("1" "8")

declare -a prefech_sz_arr=("1024")
declare -a prefech_thrd_arr=("8")


MEM_REDUCE_FRAC=1
ENABLE_MEM_SENSITIVE=0
declare -a membudget=("6")
#declare -a config_arr=( "CIPI")

#declare -a trials=("TRIAL1" "TRIAL2" "TRIAL3")
declare -a trials=("TRIAL1")
G_TRIAL="TRIAL1"

mkdir DATA


get_global_arr() {

	if [ ! -z "$workload_arr_in" ] 
	then
		if [ ${#workload_arr_in=[@]} -eq 0 ]; then
		    echo "input array in NULL"
		else
		    workload_arr=("${workload_arr_in[@]}")
		fi
	fi

	if [ ! -z "$config_arr_in" ]
	then
		if [ ${#config_arr_in=[@]} -eq 0 ]; then
		    echo "input array in NULL"
		else
		   config_arr=("${config_arr_in[@]}")
		fi
	fi

	if [ ! -z "$thread_arr_in" ]
	then
		if [ ${#thread_arr_in=[@]} -eq 0 ]; then
		    echo "input array in NULL"
		else
		   thread_arr=("${thread_arr_in[@]}")
		fi
	fi

	if [ ! -z "$4" ]
	then
		prefetchsz=$4
	else
		prefetchsz=$glob_prefetchsz
	fi

	if [ ! -z "$5" ]
	then
		prefechthrd=$5
	else
		prefechthrd=$glob_prefechthrd
	fi
}

get_global_arr


echo 0 | sudo tee /proc/sys/kernel/randomize_va_space


FlushDisk()
{
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sudo dmesg --clear
        sleep 5
}

CLEAR_DATA()
{
	sudo killall $APP
	sudo killall $APP
	sleep 3
	sudo killall $APP
        rm -rf $DBDIR/*
}


CLEAN_AND_WRITE()
{
        export LD_PRELOAD=""
        CLEAR_DATA
        FlushDisk
}

GEN_RESULT_PATH() {
	TYPE=$1
	CONFIG=$2
	THREAD=$3
        RESULTS=$OUTPUTDIR"-"$G_TRIAL/$APPOUTPUTNAME/$TYPE/$THREAD

	echo "ENABLE_MEM_SENSITIVE******"$ENABLE_MEM_SENSITIVE

	if [ "$ENABLE_SENSITIVITY" -eq "1" ]
	then

	RESULTFILE=$RESULTS/$CONFIG"-PREFETCHSZ-$prefetchsz-PREFETTHRD-$prefechthrd".out

	elif [ "$ENABLE_MEM_SENSITIVE" -eq "1" ]
	then
		RESULTS=$OUTPUTDIR"-"$G_TRIAL/$APPOUTPUTNAME/"MEMFRAC"$MEM_REDUCE_FRAC/$WORKLOAD/$THREAD/
		echo "*******$RESULTS********"
		RESULTFILE=$RESULTS/$CONFIG".out"
		mkdir -p $RESULTS
	else 
		RESULTFILE=$RESULTS/$CONFIG".out"
	fi
}


RUN() {

	for WORKLOAD in "${workload_arr[@]}"
	do
		for CONFIG in "${config_arr[@]}"
		do
			for THREAD in "${thread_arr[@]}"
			do
				for prefechthrd in "${prefech_thrd_arr[@]}"
				do
					cd $PREDICT_LIB_DIR
				        if [ "$ENABLE_SENSITIVITY" -eq "1" ]
				        then
						sed -i "/NR_WORKERS_VAR=/c\NR_WORKERS_VAR=$prefechthrd" compile.sh
						sed -i "/PREFETCH_SIZE_VAR=/c\PREFETCH_SIZE_VAR=$prefetchsz" compile.sh
					fi
					./compile.sh &> out.txt
					cd $DBHOME

					for THREAD in "${thread_arr[@]}"
					do
						RESULTS=""
						WORKPATH="workloads/$WORKLOAD"
						WRITEARGS="-f $WORKPATH"
						READARGS="-f $WORKPATH"
						GEN_RESULT_PATH $WORKPATH $CONFIG $THREAD $prefetchsz $prefechthrd

						echo $RESULTS/$CONFIG.out

						mkdir -p $RESULTS

						echo "For Workload $WORKPATH, generating $RESULTFILE"

						#echo "BEGINNING TO WARM UP ......."
						CLEAN_AND_WRITE
						CLEAR_DATA

						#echo "FINISHING WARM UP ......."
						echo "..................................................."
						echo "RUNNING $CONFIG...................................."
						echo "..................................................."
						export LD_PRELOAD=/usr/lib/lib_$CONFIG.so
						$APPPREFIX $APP $PARAMS $READARGS &> $RESULTFILE
						export LD_PRELOAD=""
						sudo dmesg -c &>> $RESULTFILE
						echo ".......FINISHING $CONFIG......................"
					done
				done
			done
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
        #$SCRIPTS/mount/releasemem.sh "NODE0"
        #$SCRIPTS/mount/releasemem.sh "NODE1"

        numactl --membind=0 $SCRIPTS/mount/reducemem.sh $DISKSZ0 "NODE0"
        #numactl --membind=1 $SCRIPTS/mount/reducemem.sh $DISKSZ1 "NODE1"
}



for G_TRIAL in "${trials[@]}"
do
	if [ "$ENABLE_MEM_SENSITIVE" -eq "1" ]
	then
		for MEM_REDUCE_FRAC in "${membudget[@]}"
		do
			#GETMEMORYBUDGET $MEM_REDUCE_FRAC
			RUN
			#$SCRIPTS/mount/releasemem.sh "NODE0"
			#$SCRIPTS/mount/releasemem.sh "NODE1"
		done
	else
		RUN
	fi
done 

exit


if [ "$ENABLE_SENSITIVITY" -eq "0" ]
then
	RUN
else
	for glob_prefetchsz in "${prefech_sz_arr[@]}"
	do
		for glob_prefechthrd in "${prefech_thrd_arr[@]}"
		do
			get_global_arr	
			RUN
		done
	done

fi


exit
