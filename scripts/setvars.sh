export NVMBASE=$PWD
export BASE=$PWD
######## DO NOT CHANGE BEYOUND THIS ###########
#Pass the release name
export OS_RELEASE_NAME="bionic"
#export KERN_SRC=$NVMBASE/linux-stable
#CPU parallelism
export PARA="-j`nproc`"
export VER="5.14.0"
export KERN_SRC=$NVMBASE/linux-$VER
export SHELL=/bin/bash

#QEMU
export QEMU_IMG=$NVMBASE
#export QEMU_IMG_FILE=$QEMU_IMG/qemu-image.img
export QEMU_IMG_FILE=$QEMU_IMG/qemu-image-fresh.img
export MOUNT_DIR=$QEMU_IMG/mountdir
export QEMUMEM="40" #In GB
export KERNEL=$NVMBASE/KERNEL

#PAPER FOLDER
export PAPER=$NVMBASE/Prop3/crossprefetch/graphs/
export PAPERGRAPHS=$PAPER/SC

#export MACHINE_NAME="CLEMSON-APR8-MEMBUDGET"
export MACHINE_NAME="ASPLOS"
export OUTPUT_FOLDER=$NVMBASE/results/$MACHINE_NAME/CAMERA-OPT-FINAL-TEST
export OUTPUT_GRAPH_FOLDER=$NVMBASE/results/$MACHINE_NAME/CAMERA-OPT-FINAL-TEST

#export MACHINE_NAME="CLEMSON-PREFETCH-4THREADS"
#export OUTPUT_FOLDER=$NVMBASE/results/$MACHINE_NAME/SC-RESULTS
#export OUTPUT_GRAPH_FOLDER=$NVMBASE/results/$MACHINE_NAME/SC-RESULTS

export OUTPUTDIR=$OUTPUT_FOLDER
export LINUX_SCALE_BENCH=$NVMBASE/linux-scalability-benchmark
export APPBENCH=$NVMBASE/appbench
export APPS=$NVMBASE/appbench/apps
export SHARED_LIBS=$NVMBASE/shared_libs
export PREDICT_LIB_DIR=$SHARED_LIBS/simple_prefetcher
export QUARTZ=$SHARED_LIBS/quartz

#SCRIPTS
export SCRIPTS=$NVMBASE/scripts
export UTILS=$NVMBASE/utils
export RUN_SCRIPTS=$SCRIPTS/run
#export INPUTXML=$SCRIPTS/input.xml
export QUARTZSCRIPTS=$SHARED_LIBS/quartz/scripts

#APP SPECIFIC and APPBENCH
#export GRAPHCHI_ROOT=$APPBENCH/graphchi/graphchi-cpp
export SHARED_DATA=$NVMBASE/dataset
#export SHARED_DATA=/mnt/pmemdir

export APPPREFIX="/usr/bin/time -v"

#export APPPREFIX="perf record -e instructions,mem-loads,mem-stores --vmlinux=/lib/modules/4.17.0/build/vmlinux -I 1000"
#export APPPREFIX="perf stat -e dTLB-load-misses,iTLB-load-misses,instructions,L1-dcache-loads,L1-dcache-stores"
#export APPPREFIX="numactl --membind=1"
#export APP_PREFIX="numactl --membind=1"

export TEST_TMPDIR=/mnt/pmemdir


#export CODE="/users/$USER/ssd/NVM/appbench/apps/butterflyeffect/code"
#export CSRC=$CODE/cassandra
#export SERVERS=`ifconfig | grep "inet addr" | head -1 | awk '{print $2}' | cut -d ":" -f2`
#export YCSBHOME=$CODE/mapkeeper/ycsb/YCSB
#export DATASRC=""

#export ENVPATH=$NVMBASE/scripts/env



#Commands
mkdir $KERNEL

#echo "backend: Agg" > ~/.config/matplotlib/matplotlibrc

