#!/bin/bash

HOMEDIR=$HOME
export SSD=$HOME/ssd
CLOUDLAB=$SSD
LEVELDBHOME=$SSD
YCSBHOME=$SSD/leveldb-nvm/mapkeeper/ycsb/YCSB
SSD_DEVICE="/dev/sdc"
SSD_PARTITION="/dev/sdc1"

DIRBASE="/users/$USER"

sudo apt-get update
sudo dpkg --configure -a

FORMAT_SSD() {
    mkdir $SSD
    sudo mount $SSD_PARTITION $SSD
    if [ $? -eq 0 ]; then
        sudo chown -R $USER $SSD
        echo OK
    else
        sudo fdisk $SSD_DEVICE
        sudo mkfs.ext4 $SSD_PARTITION
        sudo mount $SSD_PARTITION $SSD
        sudo chown -R $USER $SSD
    fi
    #unlink $LEVELDBHOME
    #mv $LEVELDBHOME $SSD/
    #ln -s $SSD/leveldb-nvm $LEVELDBHOME
}

INSTALL_FOLLY(){
cd $HOMEDIR/cloudlab/bistro/bistro/build/deps/fbthrift/thrift/build/deps/folly/folly
sudo apt-get install -y \
    g++ \
    automake \
    autoconf \
    autoconf-archive \
    libtool \
    libboost-all-dev \
    libevent-dev \
    libdouble-conversion-dev \
    libgoogle-glog-dev \
    libgflags-dev \
    liblz4-dev \
    liblzma-dev \
    libsnappy-dev \
    make \
    zlib1g-dev \
    binutils-dev \
    libjemalloc-dev \
    libssl-dev

sudo apt-get install -y \
    libiberty-dev

  autoreconf -ivf
  ./configure
  make -j16
  #make check
  sudo make install
}

BUILD_BISTRO(){
    echo "hello"
    export PATH=$PATH:$CLOUDLAB/bistro/bistro/build/deps/fbthrift
    cd $CLOUDLAB/bistro/bistro/build
    sed -i "/googletest.googlecode/c\wget http://downloads.sourceforge.net/project/mxedeps/gtest-1.7.0.zip -O gtest-1.7.0.zip" $CLOUDLAB/bistro/bistro/build/build.sh
    ./build.sh Debug runtests
}

INSTALL_THRIFT(){
    cd $HOMEDIR/cloudlab/bistro/bistro
    ../bistro/build/deps_ubuntu_12.04.sh

    INSTALL_FOLLY   

    cd $HOMEDIR/cloudlab/bistro/bistro/build/deps/fbthrift/thrift
    autoreconf -ivf
    ./configure
    make -j16
    sudo make install
    cd $HOMEDIR/cloudlab/bistro/bistro/build
}

INSTALL_BISTRO(){
	cd $CLOUDLAB
	git clone https://github.com/facebook/bistro.git
	INSTALL_THRIFT
	BUILD_BISTRO
}


INSTALL_YCSB() {
    cd $CLOUDLAB
    if [ ! -d "leveldb-nvm" ]; then
        git clone https://gitlab.com/sudarsunkannan/leveldb-nvm.git
    fi
    cd $CLOUDLAB/leveldb-nvm/mapkeeper/ycsb/YCSB
    mvn clean package
}


INSTALL_CASANDARA_BINARY(){

    mkdir $CLOUDLAB/cassandra	
    echo "deb http://www.apache.org/dist/cassandra/debian 39x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list
    echo "deb-src http://www.apache.org/dist/cassandra/debian 39x main" | sudo tee -a /etc/apt/sources.list.d/cassandra.sources.list

    gpg --keyserver pgp.mit.edu --recv-keys F758CE318D77295D
    gpg --export --armor F758CE318D77295D | sudo apt-key add -

    gpg --keyserver pgp.mit.edu --recv-keys 2B5C1B00
    gpg --export --armor 2B5C1B00 | sudo apt-key add -

    gpg --keyserver pgp.mit.edu --recv-keys 0353B12C
    gpg --export --armor 0353B12C | sudo apt-key add -

    sudo apt-get update
    sudo apt-get install -y --force-yes cassandra
    #RUN_YCSB_CASSANDARA
}

DOWNLOAD_CASANDARA_SOURCE(){
    mkdir $CLOUDLAB/cassandra	
    cd $CLOUDLAB/cassandra
    wget http://archive.apache.org/dist/cassandra/3.9/apache-cassandra-3.9-src.tar.gz
    tar -xvzf apache-cassandra-3.9-src.tar.gz
}

INSTALL_CASANDARA_SOURCE(){

    mkdir $CLOUDLAB/cassandra
    cd $CLOUDLAB/cassandra

    if [ ! -d "/usr/share/cassandra" ]; then
        INSTALL_CASANDARA_BINARY
    fi

    if [ ! -d "apache-cassandra-3.9-src" ]; then
        DOWNLOAD_CASANDARA_SOURCE
    fi	

    cd apache-cassandra-3.9*
    ant
    #keep a backup if installed version exists and no backup exists
    if [ ! -d "/usr/share/cassandra-orig" ]; then
        sudo cp -rf  /usr/share/cassandra  /usr/share/cassandra-orig
    fi
    sudo cp ./build/apache-cassandra-3.9-SNAPSHOT.jar /usr/share/cassandra/apache-cassandra-3.9.jar
    sudo cp ./build/apache-cassandra-thrift-3.9-SNAPSHOT.jar /usr/share/cassandra/apache-cassandra-thrift-3.9.jar
}

RUN_YCSB_CASSANDARA() {

    INSTALL_CASANDARA_SOURCE

    cd $YCSBHOME/cassandra
    ./start_sevice.sh 
}

INSTALL_JAVA() {
    sudo add-apt-repository ppa:webupd8team/java
    sudo apt-get update
    sudo apt-get install -y oracle-java8-set-default
    java -version
}

INSTALL_CMAKE(){
    cd $SSD
    wget https://cmake.org/files/v3.7/cmake-3.7.0-rc3.tar.gz
    tar zxvf cmake-3.7.0-rc3.tar.gz
    cd cmake-3.7.0*
    ./configure
    ./bootstrap
    make -j16
    make install
}

SETGITHUB() {
    cd $SSD
    sudo -u $USER ssh -T git@github.com
    git clone git@github.com:sudarsunkannan/NVM.git
}

INSTALL_SYSTEM_LIBS(){
	sudo apt-get install -y git
	git config --global user.name "sudarsunkannan"
	git config --global user.email "sudarsun.kannan@gmail.com"
	#git commit --amend --reset-author
	sudo apt-get install kernel-package
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
	#INSTALL_JAVA
}

INSTALL_SCHEDSP() {
	 cd ~/ssd
	 git clone https://gitlab.com/sudarsunkannan/schedsp.git
	 cd schedsp
}


INSTALL_KERNEL() {
	 cd $SSD/NVM
	 #scripts/compile_deb.sh
	 source scripts/setvars.sh "trusty"
         $SSD/NVM/scripts/compile_nokvm.sh
}


INSTALL_HETERO() {
	 cd ~/ssd
	 INSTALL_CMAKE
	 git clone https://github.com/SudarsunKannan/NVM
	 cd $SSD/NVM
	 git checkout cleaned
	 source scripts/setvars.sh "trusty"   
	 scripts/set_appbench.sh
}

INSTALL_SYSTEM_LIBS
FORMAT_SSD
#INSTALL_SCHEDSP
SETGITHUB
INSTALL_HETERO
INSTALL_KERNEL


#Install ycsb and casandara
#INSTALL_YCSB
#RUN_YCSB_CASSANDARA
#INSTALL_YCSB

