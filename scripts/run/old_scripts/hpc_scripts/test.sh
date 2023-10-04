NPROC=36
#APPPREFIX="numactl --membind=0"

export LD_PRELOAD=/usr/lib/libmigration.so 

export IOMODE=ASYNC
export FILETYPE=UNIQUE

/usr/bin/time -v mpiexec -n $NPROC ./MADbench2_io 2400 140 1 8 8 4 4
#$APPPREFIX /usr/bin/time -v mpiexec -n $NPROC ./MADbench2.x 2400 140 1 8 8 4 4

