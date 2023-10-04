#!/bin/bash

HOMEDIR=$HOME

#Set your disk partitions
DISK=$HOME

#Number of processors to use during setup
echo "Using $NPROC cores for setup"

#All downloads and code installation will happen here.
#Feel free to change
CLOUDLABDIR=$DISK/ssd/cloudlab

LEVELDBHOME=$CLOUDLABDIR/leveldb-nvm
YCSBHOME=$CLOUDLABDIR/leveldb-nvm/mapkeeper/ycsb/YCSB

#LIBS Specific to IB
MVAPICHVER="mvapich2-2.3.4"
#Download URL
MVAPICHURL="https://mvapich.cse.ohio-state.edu/download/mvapich/mv2/$MVAPICHVER.tar.gz"
MVAPICHPATH=$CLOUDLABDIR/$MVAPICHVER
MVAPICHBENCH=$MVAPICHPATH/osu_benchmarks
MPIPROCS=4 #Number of process to test


#Create the CLOUDLABDIR directory
mkdir $CLOUDLABDIR

MVAPICHPATH=$CLOUDLABDIR/$MVAPICHVER

#Create the CLOUDLABDIR directory
mkdir $CLOUDLABDIR

COOL_DOWN() {
	sleep 5
}

CONFIGURE_GIT() {
	git config --global user.name shaleengarg
	git config --global user.email "shaleengarg.in@gmail.com"
	#git commit --amend --reset-author
}


INSTALL_SYSTEM_LIBS(){
	sudo apt-get update
	sudo apt-get install -y git
	sudo apt-get install -y kernel-package
	sudo apt-get install -y software-properties-common
	sudo apt-get install -y python3-software-properties
	sudo apt-get install -y python-software-properties
	sudo apt-get install -y unzip
	sudo apt-get install -y python-setuptools python-dev build-essential
	sudo easy_install pip
	sudo apt-get install -y numactl
	sudo apt-get install -y libsqlite3-dev
	sudo apt-get install -y libnuma-dev
	sudo apt-get install -y libkrb5-dev
	sudo apt-get install -y libsasl2-dev
	sudo apt-get install -y cmake
	sudo apt-get install -y build-essential
	sudo apt-get install -y maven
	sudo apt-get install -y mosh
	#sudo pip install thrift_compiler
}

#IB libs
INSTALL_IB_LIBS() {
	#sudo apt-get install -y libibmad-dev libibumad-dev libibumad3
	#sudo apt-get install -y libibverbs-dev
	#sudo apt-get install -y gfortran
	#sudo apt-get install -y infiniband-diags rdma-core
	#INSTALL MVAPICH
	cd $CLOUDLABDIR
	wget $MVAPICHURL
	tar -xvzf $MVAPICHVER.tar.gz

	cd $MVAPICHPATH

	./configure --with-device=ch3:mrail --with-rdma=gen2 -enable-g=all -enable-fast=none
	make clean
	make -j$NPROC
	COOL_DOWN
	sudo make install -j
	COOL_DOWN
	cd $MVAPICHBENCH
	./configure CC=/usr/local/bin/mpicc CXX=/usr/local/bin/mpicxx
}

RUN_IBBENCH() {
	#Run a MVAPICH BENCHMARK
	cd $MVAPICHBENCH
	COOL_DOWN
	sudo mpirun -np $MPIPROCS mpi/one-sided/osu_acc_latency
	COOL_DOWN
	sudo mpirun -np $MPIPROCS mpi/collective/osu_igatherv
	COOL_DOWN
	sudo mpirun -np $MPIPROCS mpi/pt2pt/osu_bw
	#sudo apt-get install -y ibverbs-utils libnes-dev libmlx5-dev libmlx4-dev libmlx5-dev libmthca-dev rdmacm-utils
}

#INSTALL_SYSTEM_LIBS
#CONFIGURE_GIT
#COOL_DOWN
INSTALL_IB_LIBS
RUN_IBBENCH
