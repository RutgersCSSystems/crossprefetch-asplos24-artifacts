#!/bin/bash
cd $NVMBASE

SETUP(){
        scripts/clear_cache.sh
        cd $SHARED_LIBS/construct
        make clean
}

SETENV() {
        source scripts/setvars.sh
        #$SCRIPTS/install_quartz.sh
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
        $APPBENCH/apps/socket/run.sh &> $OUTPUTDIR/$OUTPUT
        sudo dmesg -c &>> $OUTPUTDIR/$OUTPUT
}

#SETENV
OUTPUT="socket_output.out"
SETUP
make CFLAGS=""
export APPPREFIX_CLIENT="numactl --membind=0"
export APPPREFIX_SERVER="numactl --membind=1"
RUNAPP
exit


#mkdir $OUTPUTDIR/fastmem-only
exit


#Disable hetero for fastmem only mode
#make CFLAGS="-D_DISABLE_HETERO"
~                                    
