#!/bin/bash
#set -x
# Need to pass the number of producer as argument
default=4
producer=${1:-$default}

# Specify the base directories for code and result
CODE=$PWD
DBDIR=$CODE/DATA
DBHOME=$PWD

RESULT_BASE=$PWD/results/
result_dir=$RESULT_BASE/concurrency

# Setup Parameters
let IOSIZE=4096

let READERS=-1
let WRITERS=-1
let SCHED=0
let DEVCORECOUNT=1
let QUEUEDEPTH=1

let MAX_READER=16
let MAX_WRITER=4
ERR=100

declare -a config_arr=("Vanilla" "OSonly" "CIPI_PERF" "CIPI_interval")

#
FILESIZE="12G"
FILENAME="testfile"
FSPATH=$DBDIR


FlushDisk()
{
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        #sudo dmesg --clear
        sleep 5
}

if [ ! -d "$FSPATH" ]; then
        mkdir -p $FSPATH
fi

# Create output directories
if [ ! -d "$result_dir" ]; then
        mkdir -p $result_dir
fi

if [ ! -d "$result_dir/$producer" ]; then
	mkdir -p $result_dir/$producer
fi

# Create output directory for different number of consumers(readers)
i=1
while (( $i <= $MAX_READER ))
do
	if [ ! -d "$result_dir/$producer/$i" ]; then
		mkdir -p $result_dir/$producer/$i
	fi

	i=$((i*2))
done

cd $PREDICT_LIB_DIR
$PREDICT_LIB_DIR/compile.sh &> compile.out

#sudo dmesg -c
cd $CODE

#sudo mkdir $FSPATH
#sudo chown -R $USER $FSPATH

# Setup experiment argument list
ARGS="-q $QUEUEDEPTH -s $IOSIZE -t $READERS -u $WRITERS -p $SCHED -v $DEVCORECOUNT -b $FILESIZE"

# First fill up the test file
$CODE/shared_posixio -f "$FSPATH/$FILENAME" $ARGS &> /tmp/log

declare -a readers=("1" "4" "8" "16")
FlushDisk


cp $DBHOME/Makefile.Scalability $PREDICT_LIB_DIR/Makefile
cp $DBHOME/PARAMS.sh $PREDICT_LIB_DIR/compile.sh

cd $PREDICT_LIB_DIR
$PREDICT_LIB_DIR/compile.sh
FlushDisk
FlushDisk
cd $DBHOME

WRITERS=4
# Vary the number of producer(writer)
while (( $WRITERS <= $MAX_WRITER ))
do
	# Vary the number of consumer(reader)
    for reader in "${readers[@]}"
    do
        for CONFIG in "${config_arr[@]}"
        do
            ARGS="-q $QUEUEDEPTH -s $IOSIZE -t $reader -u $WRITERS -p $SCHED -v $DEVCORECOUNT -b $FILESIZE"	

            RESULTFILE=$result_dir/$WRITERS/$reader/$CONFIG.out
            LD_PRELOAD=/usr/lib/lib_$CONFIG.so $CODE/shared_posixio -f "$FSPATH/$FILENAME" $ARGS &> $RESULTFILE
            cat $RESULTFILE | grep "ops/sec"
            VAL=`cat $RESULTFILE | grep "ops/sec;" | awk '{print $5}'`
            if [ -z "$VAL" ]; then
                VAL=0
            fi
            if [ "$ERR" -gt "$VAL" ]; then
		FlushDisk
                LD_PRELOAD=/usr/lib/lib_$CONFIG.so $CODE/shared_posixio -f "$FSPATH/$FILENAME" $ARGS &> $RESULTFILE
            fi
	   FlushDisk
        done 
        echo ".......FINISHING Reader Threads $reader......................"
        echo "-------------------------------------------------------------"
		# echo "-------------------------------------------------------------"
	done
	WRITERS=$((WRITERS*2))
done

cp $PREDICT_LIB_DIR/ORIGMAKEFILE $PREDICT_LIB_DIR/Makefile	
cp $PREDICT_LIB_DIR/COMPILEORIG.sh $PREDICT_LIB_DIR/compile.sh



