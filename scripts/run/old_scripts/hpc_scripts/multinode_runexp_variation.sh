#!/bin/bash
#set -x

if [ -z "$NVMBASE" ]; then
    kernel_error "PREFIX environment variable not defined. Have you ran setvars?"
    exit 1
fi

APPDIR=$PWD
cd $APPDIR
#declare -a apparr=("MADbench")

#Enable whichever applicaiton you are running

declare -a nodes=("ms0941.utah.cloudlab.us" "ms0942.utah.cloudlab.us" "ms0914.utah.cloudlab.us")

#Graph500
declare -a caparr=("unlimited")
declare -a apparr=("graph500")
declare -a workarr=("25")
declare -a thrdarr=("32")
Timestorun=3

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


RUNONALL() {
Command="$@"
#ssh -t clnode058.clemson.cloudlab.us $1
for NODE in "${nodes[@]}"
do
	ssh -t $NODE $Command &
done
wait
}


SLEEPNOW() {
	sleep 2
}


#Mount ramdisk to reserve memory and reduce overall memory availability
SETUPEXTRAM() {

	RUNONALL $SCRIPTS/alloc_membudget.sh $1
}


#Here is where we run the application
RUNAPP() 
{
	#Run application
	cd $APPDIR

	local CAPACITY=$1
	local NPROC=$2
	local WORKLOAD=$3
	local APP=$4
	local MEMBW=$5
	local NUMRUN=$6

	mkdir -p $OUTPUTBASE/$APP
	sudo dmesg -c &> del.txt
	sudo dmesg --clear

	if [[ $USE_HETEROMEM == "0" ]]; then
		OUTPUT=$OUTPUTBASE/$APP/"MEMSIZE-$WORKLOAD-"$NPROC"threads-"$CAPACITY"M-${NUMRUN}.out"
	else
		OUTPUT=$OUTPUTBASE/$APP/"Multi-BW$MEMBW-MEMSIZE-$WORKLOAD-"$NPROC"threads-"$CAPACITY"M-${NUMRUN}.out"
		$SHARED_LIBS/construct/reset
		LD_PRELOAD=/usr/lib/libmigration.so
	fi


	if [[ $USEPERF == "1" ]]; then
		#SETPERF
		APPPREFIX="sudo $PERFTOOL record -e cpu-cycles,instructions --vmlinux=/lib/modules/4.17.0/build/vmlinux "
	else
		APPPREFIX="/usr/bin/time -v"
	fi


	if [ "$APP" = "MADbench" ]; then
		#cd $APPBENCH/apps/MADbench
		numactl --hardware  &> $OUTPUT
		#export LD_PRELOAD=/usr/lib/libmigration.so 
		$APPPREFIX mpiexec -n $NPROC --hostfile $SCRIPTS/HOSTS $APPBENCH/apps/MADbench/MADbench2_io $WORKLOAD 140 1 8 8 4 4 &>> $OUTPUT
		export LD_PRELOAD=" "
		numactl --hardware  &>> $OUTPUT
	fi

	if [ "$APP" = "GTC" ]; then
		numactl --hardware  &> $OUTPUT
		#export LD_PRELOAD=/usr/lib/libmigration.so 
		$APPPREFIX mpiexec -n $NPROC --hostfile $SCRIPTS/HOSTS $APPBENCH/apps/gtc-benchmark/gtc &>> $OUTPUT
		export LD_PRELOAD=" "
		numactl --hardware  &>> $OUTPUT
		rm -f DATA*
	fi

	if [ "$APP" = "Gromacs" ]; then
		numactl --hardware  &> $OUTPUT
		#export LD_PRELOAD=/usr/lib/libmigration.so 
		mpirun.mpich -np 100 --hostfile ~/iphosts mdrun_mpi -v -s run_water.tpr -o -x -deffnm md_water
		mpirun -np $NPROC --hostfile $SCRIPTS/HOSTS /usr/local/gromacs/bin/mdrun_mpi -v -s $APPBENCH/apps/gromacs/run_water.tpr -o -x -deffnm $APPBENCH/apps/gromacs/md_water.gro
		export LD_PRELOAD=""
	fi

	if [ "$APP" = "BTIO" ]; then
		#cd $APPBENCH/apps/NPB3.4/NPB3.4-MPI/
		numactl --hardware  &> $OUTPUT
		#export LD_PRELOAD=/usr/lib/libmigration.so
		$APPPREFIX /usr/bin/time -v mpirun -NP $NPROC --hostfile $SCRIPTS/HOSTS $APPBENCH/apps/NPB3.4/NPB3.4-MPI/bin/bt.C.x.ep_io  &>> $OUTPUT
		export LD_PRELOAD=""
		numactl --hardware  &>> $OUTPUT
		rm -f btio*
	fi

	if [ "$APP" = "graph500" ]; then
		export TMPFILE="graph.out"
		export REUSEFILE=1
		echo $OUTPUT
		rm -rf $TMPFILE
		echo "$APPPREFIX mpiexec -n $NPROC --hostfile $SCRIPTS/HOSTS $APPBENCH/apps/graph500-3.0.0/src/graph500_reference_bfs $WORKLOAD 20 &>> $OUTPUT"
		numactl --hardware  &> $OUTPUT
		#export LD_PRELOAD=/usr/lib/libmigration.so
		$APPPREFIX mpiexec -n $NPROC --hostfile $SCRIPTS/HOSTS $APPBENCH/apps/graph500-3.0.0/src/graph500_reference_bfs $WORKLOAD 20 &>> $OUTPUT
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
		#OUTPUT=$OUTPUTBASE/$APP/"BW$MEMBW-MEMSIZE-$WORKLOAD-"$NPROC"threads-"$CAPACITY"M.out"
		OUTPUT=$OUTPUTBASE/$APP/"Multi-BW$MEMBW-MEMSIZE-$WORKLOAD-"$NPROC"threads-"$CAPACITY"M-${NUMRUN}.out"
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
#		SETUPEXTRAM $CAPACITY

		for NPROC in "${thrdarr[@]}"
		do	
			for WORKLOAD in "${workarr[@]}"
			do
				for RUNNUM in $(seq 1 $Timestorun)
				do
					RUNAPP $CAPACITY $NPROC $WORKLOAD $APP $MEMBW $RUNNUM
					SLEEPNOW
					RUNONALL $SCRIPTS/clear_cache.sh
					TERMINATE $CAPACITY $NPROC $WORKLOAD $APP $MEMBW $RUNNUM
				done
			done 
		done	
	done
done
