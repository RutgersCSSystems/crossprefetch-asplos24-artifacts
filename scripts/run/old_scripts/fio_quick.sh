#!/bin/bash
cd $NVMBASE


SETUP(){
	$NVMBASE/scripts/clear_cache.sh
	cd $SHARED_LIBS/construct
	make clean
}

SETENV() {
	source scripts/setvars.sh
	$SCRIPTS/install_quartz.sh
	$SCRIPTS/throttle.sh
	$SCRIPTS/throttle.sh
}


COMPILE_SHAREDLIB() {
	#Compile shared libs
	cd $SHARED_LIBS/construct
	make clean
	make CFLAGS=$DEPFLAGS
	sudo make install
}

RUNAPP() {
	#Run application
	cd $NVMBASE
	$APPBENCH/apps/fio/run.sh &> $OUTPUTDIR/$OUTPUT
	sudo dmesg -c &>> $OUTPUTDIR/$OUTPUT
}	


OUTPUTDIR=$APPBENCH/output-fio-trail2
mkdir $OUTPUTDIR
#SETENV
#Don't do any migration
export APPPREFIX="numactl  --preferred=0"
mkdir $OUTPUTDIR/slowmem-migration-only
OUTPUT="slowmem-migration-only/fio.out"
#SETUP
make CFLAGS="-D_MIGRATE"
RUNAPP
exit


mkdir $OUTPUTDIR/slowmem-only
OUTPUT="slowmem-only/fio.out"
SETUP
make CFLAGS="-D_SLOWONLY"
export APPPREFIX="numactl --membind=1"
RUNAPP 
exit


mkdir $OUTPUTDIR/naive-os-fastmem
OUTPUT="naive-os-fastmem/fio.out"
SETUP
make CFLAGS=""
RUNAPP


mkdir $OUTPUTDIR/slowmem-obj-affinity
OUTPUT="slowmem-obj-affinity/fio.out"
SETUP
make CFLAGS="-D_MIGRATE -D_OBJAFF"
RUNAPP
exit


mkdir $OUTPUTDIR/fastmem-only
OUTPUT="fastmem-only/fio.out"
SETUP
make CFLAGS="-D_SLOWONLY"
export APPPREFIX="numactl --membind=1"
RUNAPP 
exit



#exit


#mkdir $OUTPUTDIR/fastmem-only
exit
#Disable hetero for fastmem only mode
#make CFLAGS="-D_DISABLE_HETERO"
