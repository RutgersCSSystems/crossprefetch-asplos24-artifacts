#!/bin/bash

if [ -z "$NVMBASE" ]; then
    echo "NVMBASE environment variable not defined. Have you ran setvars?"
    exit 1
fi

#sudo apt-get install -y gcc-4.8 g++-4.8
cd $SHARED_LIBS/simple_prefetcher
make clean; make -j; make install
