#!/bin/bash

INSTALL_LIB() {
	sudo apt-get -y update
	sudo apt-get -y install libgflags-dev libsnappy-dev zlib1g-dev libbz2-dev liblz4-dev libzstd-dev
}

COMPILE_ROCKSDB() {
	#DEBUG_LEVEL=0 make shared_lib db_bench -j32
	DEBUG_LEVEL=0 CFLAGS=-Wno-error make db_bench -j$(nproc)
}

INSTALL_LIB
COMPILE_ROCKSDB



