#!/bin/bash

if [ -z "$NVMBASE" ]; then
    echo "PREFIX environment variable not defined. Have you ran setvars?"
    echo "Dont forget to change \$VER in setvars.sh"
    exit 1
fi

#wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-5.14.tar.gz

VERSION=5.14
KERNEL=linux-$VERSION
PROC=`nproc`
export CONCURRENCY_LEVEL=$PROC
export CONCURRENCYLEVEL=$PROC 

cd $NVMBASE/../
wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$VERSION.tar.gz
tar -xf  $KERNEL.tar.gz
cp $NVMBASE/scripts/helperscripts/linuxMakefile-$VERSION $KERNEL/Makefile
cp $NVMBASE/linux-5.14.0/modifiednix.config $KERNEL/.config
if [ $? -ne 0 ]
then
	echo "no custom makefile for $KERNEL"
	exit
fi
cp $NVMBASE/scripts/helperscripts/compile_deb.sh $KERNEL/compile_deb.sh
cd $KERNEL

./compile_deb.sh ##To be called only once, next time, call compile_make.sh
