#!/bin/bash

PREDICT=0
DBHOME=$PWD
DATAPATH=$DBHOME/dataset
OUTPUTPATH=$DBHOME/output_dir
FSTYPE="ext4"
APP="SNAPPY"
RESULTS=$PWD
RESULTDIR=$RESULTS/$APP/"result-ext4dax"
FILECOUNT=100
echo $RESULTDIR

#declare -a sizearr=("128" "256" "512" "1024" "2048" "4096")
declare -a sizearr=("20000")
#declare -a threadarr=("1" "4" "8" "16")
declare -a threadarr=("32")


# Create output directories
if [ ! -d "$RESULTDIR" ]; then
	mkdir -p $RESULTDIR
fi

SETPRELOAD()
{
	if [[ "$PREDICT" == "1" ]]; then
	    export LD_PRELOAD=/usr/lib/libcrosslayer.so
	else
	    export LD_PRELOAD=/usr/lib/libnopred.so
	fi
}

BUILD_LIB()
{
	cd $SHARED_LIBS/pred
	./compile.sh
	cd $DBHOME
}



CLEAN() {
        set +x
	rm -rf $DATAPATH/*
	rm -rf $OUTPUTPATH/*
        set -x
	echo "remove files"
}

FlushDisk() {
	sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
	sudo sh -c "sync"
	sudo sh -c "sync"
	sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
}

RUN() {

        numfiles=$1
        filesize=$2
        threads=$3

        let file_perthread=$numfiles/$threads
        echo $file_perthread
        #return 

        for (( t=1; t<=$threads; t++ ))
        do
                DIR=$DATAPATH/$t
                OUTPUT=$RESULTDIR/$numfiles"_"$filesize"_"$threads".txt"

                mkdir -p $DIR
                echo $numfiles
                rm -rf $DIR/*

                ./gen_file_posix $numfiles $filesize $DIR
                FlushDisk
        done

	echo "DISABLING PREDICT FLAG and using OS-only prefetching..."
	SETPRELOAD #if PREDICT is set, library's prefetching would be enabled
        $DBHOME/snappy_test_posix $DATAPATH $threads &> $OUTPUT
	rm -rf $OUTPUTPATH/*
	FlushDisk


	PREDICT=1
	echo "ENABLING PREDICT FLAG and using the library's prefetching..."
	SETPRELOAD #if PREDICT is set, library's prefetching would be enabled
        ./snappy_test_posix $DATAPATH $threads &>> $OUTPUT
	PREDICT=0
	SETPRELOAD

        cat $OUTPUT
        sleep 2
        #done
}


BUILD_LIB


let filecount=$FILECOUNT

for thrd in "${threadarr[@]}"
do
	for size in "${sizearr[@]}"
	do
		CLEAN
		FlushDisk
		let numfiles=$filecount
		let filesize=$size
		#echo $numfiles $filesize
		RUN $numfiles $filesize $thrd
		let filecount=$numfiles
	done
done
set +x
