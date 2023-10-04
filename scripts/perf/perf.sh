#!/bin/bash
set -x

HOMEDIR=$PWD
EXE=$KERN_SRC/tools/perf/perf

#cd $KERN_SRC/tools/perf
#make && sudo make install
cd $HOMEDIR
export LD_PRELOAD=$2
#$EXE record -e instructions,mem-loads,mem-stores --vmlinux=/lib/modules/$VER/build/vmlinux $1
$EXE record --vmlinux=/lib/modules/$VER/build/vmlinux $1
export LD_PRELOAD=""

#perf report --sort=dso --stdio
#perf report 
$EXE report --sort=dso #&> out.txt
