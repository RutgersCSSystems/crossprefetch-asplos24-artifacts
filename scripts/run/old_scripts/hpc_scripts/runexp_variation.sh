#!/bin/bash
#set -x

APPDIR=$PWD
cd $APPDIR
#declare -a apparr=("MADbench")



#Enable whichever applicaiton you are running

#Graph500
declare -a caparr=("60000" "20000" "15000")
declare -a apparr=("graph500")
declare -a workarr=("25")
declare -a thrdarr=("32")

#MADbench
#declare -a apparr=("MADbench")
#declare -a workarr=("60000" "20000")
#declare -a caparr=("60000")
#declare -a thrdarr=("16")

#GTC
#declare -a caparr=("60000" "22000" "20000")
#declare -a thrdarr=("32")
#declare -a workarr=("100")
#declare -a apparr=("GTC")

#declare -a caparr=("20000" "5000" "4000")
#declare -a thrdarr=("32")
#declare -a workarr=("WORK-C")
#declare -a apparr=("BTIO")

#APPPREFIX="numactl --membind=0"
APPPREFIX=""

#Make sure to compile and install perf
USEPERF=0
MEMBW=4GB
PERFTOOL="$HOME/ssd/NVM/linux-stable/tools/perf/perf"


#HETERO SPLIT
USE_HETEROMEM=1

OUTPUTBASE=$OUTPUTDIR/results-sensitivity


if [[ $USE_HETEROMEM == "0" ]]; then
	OUTPUTBASE=$OUTPUTDIR/results-sensitivity/$APP
else
	#scripts/install_quartz.sh
	OUTPUTBASE=$OUTPUTDIR/results-sensitivity-BW/$APP
fi



SLEEPNOW() {
	sleep 2
}


SETPERF() {

	sudo sh -c "echo 0 > /proc/sys/kernel/perf_event_paranoid"
	sudo sh -c "echo 0 > /proc/sys/kernel/kptr_restrict"
	SLEEPNOW
}


#Mount ramdisk to reserve memory and reduce overall memory availability
SETUPEXTRAM() {

	let CAPACITY=$1

	if [[ $USE_HETEROMEM == "1" ]]; then

		let SPLIT1=$CAPACITY/4
		let SPLIT2=($CAPACITY*3)/4
	else
		let SPLIT1=$CAPACITY/2
		let SPLIT2=$CAPACITY/2
	fi

	echo "SPLIT" $SPLIT1 $SPLIT2

        sudo rm -rf  /mnt/ext4ramdisk0/*
        sudo rm -rf  /mnt/ext4ramdisk1/*

	$SCRIPTS/umount_ext4ramdisk.sh 0
	$SCRIPTS/umount_ext4ramdisk.sh 1

        SLEEPNOW

        NUMAFREE0=`numactl --hardware | grep "node 0 free:" | awk '{print $4}'`
        NUMAFREE1=`numactl --hardware | grep "node 1 free:" | awk '{print $4}'`

        let DISKSZ=$NUMAFREE0-$SPLIT1
        let ALLOCSZ=$NUMAFREE1-$SPLIT2

        echo "NODE 0 $DISKSZ NODE 1 $ALLOCSZ"

        $SCRIPTS/mount_ext4ramdisk.sh $DISKSZ 0
        $SCRIPTS/mount_ext4ramdisk.sh $ALLOCSZ 1

	SLEEPNOW
}


#Here is where we run the application
RUNAPP() 
{
	#Run application
	cd $APPDIR

	local CAPACITY=$1
	local NPROC=$2
	local WORKLOAD=$3
	local APPNAME=$4
	local MEMBW=$5

	mkdir -p $OUTPUTBASE/$APP

	if [[ $USE_HETEROMEM == "0" ]]; then
		OUTPUT=$OUTPUTBASE/$APP/"MEMSIZE-$WORKLOAD-"$NPROC"threads-"$CAPACITY"M.out"
	else
		OUTPUT=$OUTPUTBASE/$APP/"BW$MEMBW-MEMSIZE-$WORKLOAD-"$NPROC"threads-"$CAPACITY"M.out"
	fi

	$SHARED_LIBS/construct/reset

	if [[ $USEPERF == "1" ]]; then
		SETPERF
		APPPREFIX="sudo $PERFTOOL record -e cpu-cycles,instructions --vmlinux=/lib/modules/4.17.0/build/vmlinux "
	else
		APPPREFIX="/usr/bin/time -v"
	fi

	sudo dmesg -c &> del.txt

	if [ "$APP" = "MADbench" ]; then
		 cd $APPBENCH/apps/MADbench
		export LD_PRELOAD=/usr/lib/libmigration.so 
		$APPPREFIX mpiexec -n $NPROC ./MADbench2_io $WORKLOAD 140 1 8 8 4 4 &> $OUTPUT
		export LD_PRELOAD=" "

	fi

	if [ "$APP" = "GTC" ]; then
		cd $APPBENCH/apps/gtc-benchmark
		export LD_PRELOAD=/usr/lib/libmigration.so 
		$APPPREFIX mpiexec -n $NPROC ./gtc &> $OUTPUT
		export LD_PRELOAD=" "
	fi

	if [ "$APP" = "BTIO" ]; then
		export LD_PRELOAD=/usr/lib/libmigration.so
		$APPPREFIX /usr/bin/time -v mpirun -NP $NPROC $APPBENCH/apps/NPB3.4/NPB3.4-MPI/bin/bt.C.x.ep_io  &> $OUTPUT
		export LD_PRELOAD=""
	fi

	if [ "$APP" = "graph500" ]; then
		cd $APPBENCH/apps/graph500-3.0.0/src
		export TMPFILE="graph.out"
		export REUSEFILE=1
		echo $OUTPUT
		rm -rf $TMPFILE
		echo "$APPPREFIX mpiexec -n $NPROC ./graph500_reference_bfs $WORKLOAD 20"
		numactl --hardware  &> $OUTPUT
		export LD_PRELOAD=/usr/lib/libmigration.so
		$APPPREFIX mpiexec -n $NPROC ./graph500_reference_bfs $WORKLOAD 20 &>> $OUTPUT
		export LD_PRELOAD=" "
	fi

	 sudo dmesg -c &>> $OUTPUT
}


#Do all things during termination
TERMINATE() 
{
	CAPACITY=$1
	NPROC=$2
	WORKLOAD=$3
	APP=$4
	MEMBW=$5

	if [[ $USE_HETEROMEM == "0" ]]; then
		OUTPUT=$OUTPUTBASE/$APP/"MEMSIZE-$WORKLOAD-"$NPROC"threads-"$CAPACITY"M.out"
	else
		OUTPUT=$OUTPUTBASE/$APP/"BW$MEMBW-MEMSIZE-$WORKLOAD-"$NPROC"threads-"$CAPACITY"M.out"
	fi

	if [[ $USEPERF == "1" ]]; then
		SLEEPNOW
		sudo $PERFTOOL report &>> $OUTPUT
		sudo $PERFTOOL report --sort=dso &>> $OUTPUT
	fi

	$SCRIPTS/clear_cache.sh
}


for APP in "${apparr[@]}"
do
	for CAPACITY  in "${caparr[@]}"
	do 
		SETUPEXTRAM $CAPACITY

		for NPROC in "${thrdarr[@]}"
		do	
			for WORKLOAD in "${workarr[@]}"
			do
				RUNAPP $CAPACITY $NPROC $WORKLOAD $APP $MEMBW
				SLEEPNOW
				$SCRIPTS/clear_cache.sh
				TERMINATE $CAPACITY $NPROC $WORKLOAD $APP $MEMBW
			done 
		done	
	done
done
