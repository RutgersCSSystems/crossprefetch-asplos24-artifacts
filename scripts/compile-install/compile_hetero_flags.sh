#!/bin/bash
#set -x
cd $NVMBASE
APP=""
TYPE="NVM"
#TYPE="NVM"
DEPFLAGS="-D_MIGRATE -D_OBJAFF"
#DEPFLAGS="-D_DISABLE_MIGRATE"
#DEPFLAGS="-D_SLOWONLY -D_DISABLE_MIGRATE"

SETUP(){
	$NVMBASE/scripts/clear_cache.sh
	cd $SHARED_LIBS/construct
	make clean
}

THROTTLE() {
	source scripts/setvars.sh
	cp $SCRIPTS/nvmemul-throttle.ini $QUARTZ/nvmemul.ini
	$SCRIPTS/install_quartz.sh
	#$SCRIPTS/throttle.sh
	#$SCRIPTS/throttle.sh
}

DISABLE_THROTTLE() {
	source scripts/setvars.sh
	cp $SCRIPTS/nvmemul-nothrottle.ini $QUARTZ/nvmemul.ini
	$SCRIPTS/throttle.sh
	#$SCRIPTS/throttle.sh
}

echo $DEPFLAGS

COMPILE_SHAREDLIB() {
	#Compile shared libs
	#DEPFLAGS=$1
	echo $DEPFLAGS
	cd $SHARED_LIBS/construct
	make clean
	make CFLAGS="$DEPFLAGS"
	sudo make install
}

#DEPFLAGS="-D_MIGRATE"
#DEPFLAGS="-D_DISABLE_MIGRATE"
#DEPFLAGS="-D_SLOWONLY -D_DISABLE_MIGRATE"
#DEPFLAGS="-D_DISABLE_MIGRATE -D_OBJAFF"
COMPILE_SHAREDLIB
