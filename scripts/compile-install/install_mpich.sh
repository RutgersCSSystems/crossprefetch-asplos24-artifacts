#!/bin/bash


if [ -z "$NVMBASE" ]; then
    echo "PREFIX environment variable not defined. Have you ran setvars?"
    exit 1
fi

LINK=http://www.mpich.org/static/downloads/3.2.1/mpich-3.2.1.tar.gz
DOWNLOAD_LOC=$NVMBASE/Downloads
INSTALL_LOC=$PREFIX

sudo apt-get install -y gfortran libpthread-stubs0-dev

stat $DOWNLOAD_LOC
if [ $? -ne 0 ]
then
    mkdir $DOWLOAD_LOC
fi

set -x

cd $DOWNLOAD_LOC
wget $LINK
tar -xvf mpich-3.2.1.tar.gz

cd mpich-3.2.1

#./configure --disable-fortran --prefix=$INSTALL_LOC --enable-g=yes --enable-debuginfo
./configure
#./configure --enable-g=yes

make -j`nproc`
sudo make install -j
set +x
