#!/bin/bash
set -x
#create empty file
touch $BASE/dummy.txt

EXEC=$BASE/scripts/exec
mkdir $EXEC


cd $BASE
cd $PREDICT_LIB_DIR
./compile.sh &> $EXEC/LIB.out

RUN_SIMPLEBENCH() {
	cd $BASE/appbench/apps/simple_bench/scalability
	./release-run-med.sh &>> $EXEC/scalability.out
	python3 release-extract-med.py &>> $EXEC/scalability.out
	cat RESULT.csv  &>  $EXEC/scalability.out
	rm -rf $BASE/appbench/apps/simple_bench/scalability/DATA
}

RUN_MMAPEXP() {
	cd $BASE/appbench/apps/simple_bench/mmap_exp
	./release-run-med.sh &>> $EXEC/mmap_exp.out
	python3 release-extract-med.py &>> $EXEC/mmap_exp.out
	cat RESULT.csv  &> $EXEC/mmap_exp.out
	rm -rf $BASE/appbench/apps/simple_bench/mmap_exp/DATA
}


RUN_SNAPPY() {
	cd $BASE/appbench/apps/snappy-c
	./gendata-run-med.sh 1 &> $EXEC/snappy.out
	./release-run-med.sh &>> $EXEC/snappy.out
	python3 release-extract-med.py &>> $EXEC/snappy.out
	cat RESULT.csv  &> $EXEC/snappy.out
	rm -rf $BASE/appbench/apps/snappy-c/DATA
}

RUN_RocksDB-YCSB() {
	cd $BASE/appbench/apps/RocksDB-YCSB
	./release-run-med.sh &>> $EXEC/rocksdb-ycsb.out
	python3 release-extract-med.py &>> $EXEC/rocksdb-ycsb.out
	cat RESULT.csv &> $EXEC/rocksdb-ycsb.out
	rm -rf $BASE/appbench/apps/RocksDB-YCSB/DATA
}

RUN_RocksDB() {
	cd $BASE/appbench/apps/rocksdb
	./gendata-run-med.sh &> $EXEC/rocksdb.out
	./release-run-med.sh &>> $EXEC/rocksdb.out
	python3 release-extract-med.py &>> $EXEC/rocksdb.out
	cat RESULT.csv &>  $EXEC/rocksdb.out
	#rm -rf $BASE/appbench/apps/rocksdb/DATA
}

cd $BASE
RUN_RocksDB-YCSB
sleep 10
RUN_RocksDB
sleep 10
RUN_MMAPEXP
sleep 10
RUN_SIMPLEBENCH
sleep 10
RUN_SNAPPY
sleep 10
exit


