#!/bin/bash
set -x
BASE=$APPBENCH


#create empty file
touch $BASE/dummy.txt

INSTALL_SHAREDLIB() {
  cd $SHARED_LIBS/hoardlib
  ./compile_install_hoard.sh
  cd $SHARED_LIBS/mmap_lib
  make clean
}

CLEAN(){
  make clean
}


INSTALL_SHAREDLIB

cd $BASE
cd phoenix-2.0/
CLEAN
cd tests/word_count/
rm -rf results/*experiments*out tmp*.txt && rm -rf result
CLEAN

cd $BASE
cd graphchi/graphchi-cpp
CLEAN

cd $BASE
cd redis-3.0.0/src 
CLEAN

cd $BASE
cd Metis
CLEAN

cd $BASE
cd leveldb
CLEAN

cd $BASE
cd $BASE/apps
cd fio
CLEAN

exit


