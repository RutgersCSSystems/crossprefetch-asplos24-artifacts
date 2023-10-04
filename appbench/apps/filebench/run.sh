#!/bin/bash
DBHOME=$PWD
PREDICT=0
THREAD=4
VALUE_SIZE=512
SYNC=0
WRITE_BUFF_SIZE=67108864
NUM=10000000
DBDIR=$DBHOME/DATA

#WORKLOAD="mongo.f"
WORKLOAD="randomread.f"
#WORKLOAD="randomread.f"
DATAPATH="workloads/$WORKLOAD"
APPPREFIX="/usr/bin/time -v"

APPNAME="filebench-"$WORKLOAD


FlushDisk()
{
	sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
	sudo sh -c "sync"
	sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
	sudo sh -c "sync"
}

SETPRELOAD()
{
        if [[ "$PREDICT" == "LIBONLY" ]]; then
                #uses read_ra but disables OS prediction
                echo "setting LIBONLY pred"
                export LD_PRELOAD=/usr/lib/libonlylibpred.so
        elif [[ "$PREDICT" == "CROSSLAYER" ]]; then
                #uses read_ra
                echo "setting CROSSLAYER pred"
                export LD_PRELOAD=/usr/lib/libcrosslayer.so
        elif [[ "$PREDICT" == "OSONLY" ]]; then
                #does not use read_ra and disables all application read-ahead
                echo "setting OS pred"
                export LD_PRELOAD=/usr/lib/libonlyospred.so
        else [[ "$PREDICT" == "VANILLA" ]]; #does not use read_ra
                echo "setting VANILLA"
                export LD_PRELOAD=""
        fi
}


BUILD_LIB()
{
	cd $SHARED_LIBS/pred
	./compile.sh
	cd $DBHOME
}

CLEAR_PWD()
{
	rm -rf $DBDIR/*
}

CLEANUP()
{
        rm -rf $DBDIR/*
        sudo killall cachestat
        sudo killall cachestat
}


RUNCACHESTAT()
{
        sudo $HOME/ssd/perf-tools/bin/cachestat &> "CACHESTAT-"$APPNAME"-"$PREDICT".out" &
}

RUN()
{
	#RUNCACHESTAT
	#SETPRELOAD
	./filebench -f $DATAPATH #&> $APPNAME"-"$PREDICT".out"

	FlushDisk
	export LD_PRELOAD=""
	CLEANUP
}

#Run write workload twice
#CLEAR_PWD
FlushDisk
#PREDICT="CROSSLAYER"
echo "RUNNING $PREDICT.................."
RUN
exit



PREDICT="VANILLA"
echo "RUNNING $PREDICT.................."
FlushDisk
RUN
exit






FlushDisk
PREDICT="OSONLY"
echo "RUNNING $PREDICT.................."
RUN






