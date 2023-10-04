#!/bin/bash
#set -x
BASE=$CODEBASE
cd $SHARED_LIBS
#sudo apt-get install -y cmake libconfig-dev uthash-dev libmpich-dev
git clone https://github.com/SudarsunKannan/quartz
cd $SHARED_LIBS/quartz
mkdir build
cd build
rm CMakeCache.txt
cmake ..
make clean all
sudo $SHARED_LIBS/quartz/scripts/setupdev.sh unload
sudo $SHARED_LIBS/quartz/scripts/setupdev.sh load
echo performance | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo 2 | sudo tee /sys/devices/cpu/rdpmc
$SCRIPTS/throttle.sh
$SCRIPTS/throttle.sh
