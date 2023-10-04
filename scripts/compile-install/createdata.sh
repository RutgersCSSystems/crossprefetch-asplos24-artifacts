#!/bin/bash

#get data
mkdir $APPBENCH/shared_data
cd $APPBENCH/shared_data


if [ ! -f com-orkut.ungraph.txt ]; then
        wget https://snap.stanford.edu/data/bigdata/communities/com-orkut.ungraph.txt
fi

if [ ! -f crime.data ]; then
	wget -O crime.data https://norvig.com/big.txt --no-check-certificate
	for i in {1..8}; do cat crime.data crime.data > crime4GB.data && mv crime4GB.data crime.data ; done && rm crime4GB.data
fi

cp * $SHARED_DATA
