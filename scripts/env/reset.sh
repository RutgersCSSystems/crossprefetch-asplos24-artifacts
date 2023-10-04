#!/bin/bash
set -x

reset_flag(){
	FLAGPATH=$NVMBASE"/flags/"$APP
	echo 0 > $FLAGPATH
}

APP=db_bench
reset_flag

APP=filebench
reset_flag

APP=memcached
reset_flag

APP=fio
reset_flag

APP=graphchi
reset_flag

APP=redis
reset_flag

APP=leveldb
reset_flag

set +x
