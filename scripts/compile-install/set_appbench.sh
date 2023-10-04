#!/bin/bash
set -x

INSTALL_SYSTEM_LIBS(){
	sudo apt-get install -y libncurses-dev
	sudo apt-get install -y git
	sudo apt-get install -y software-properties-common
	sudo apt-get install -y python3-software-properties
	sudo apt-get install -y python-software-properties
	sudo apt-get install -y unzip
	sudo apt-get install -y python-setuptools python-dev build-essential
	sudo easy_install -y pip
        sudo apt install -y  python-pip
	sudo pip install zplot
	sudo apt-get install -y numactl
	sudo apt-get install -y libnuma-dev
	sudo apt-get install -y cmake
	sudo apt-get install -y build-essential
	sudo apt-get install -y libboost-dev
	sudo apt-get install -y libboost-thread-dev
	sudo apt-get install -y libboost-system-dev
	sudo apt-get install -y libboost-program-options-dev
	sudo apt-get install -y libconfig-dev
	sudo apt-get install -y uthash-dev
	sudo apt-get install -y cscope
	sudo apt-get install -y msr-tools
	sudo apt-get install -y msrtool
	sudo pip install -y psutil
	sudo apt-get install -y libmpich-dev
	sudo apt-get install -y libzstd-dev
	sudo apt-get install -y liblz4-dev
	sudo apt-get install -y libsnappy-dev
	sudo apt-get install -y libssl-dev
	sudo apt-get install -y libgflags-dev
	sudo apt-get install -y zlib1g-dev
	sudo apt-get install -y libbz2-dev
	sudo apt-get install -y libevent-dev
	sudo apt-get install -y systemd
	sudo apt-get install -y libaio*
	sudo apt-get install -y software-properties-common
	sudo apt-get install -y libjemalloc-dev
}

INSTALL_SYSTEM_LIBS
source scripts/setvars.sh
exit
