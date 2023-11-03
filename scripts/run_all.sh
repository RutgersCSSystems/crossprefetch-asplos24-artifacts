#!/bin/bash
set -x
#create empty file
touch $BASE/dummy.txt

EXEC=$BASE/AERESULTS
mkdir -p $EXEC


cd $BASE
cd $PREDICT_LIB_DIR
./compile.sh &> $EXEC/LIB.out

RUN_SIMPLEBENCH() {
	cd $BASE/appbench/apps/simple_bench/scalability
	./release-run-med.sh &>> $EXEC/scalability.out
	python3 release-extract-med.py &>> $EXEC/scalability.out
	cat RESULT.csv  &>  $EXEC/Figure6-scalability.out
	rm -rf $BASE/appbench/apps/simple_bench/scalability/DATA
}

RUN_MMAPEXP() {
	cd $BASE/appbench/apps/simple_bench/mmap_exp
	./release-run-med.sh &>> $EXEC/mmap_exp.out
	python3 release-extract-med.py &>> $EXEC/mmap_exp.out
	cat RESULT.csv  &> $EXEC/Table4-mmap_exp.out
	rm -rf $BASE/appbench/apps/simple_bench/mmap_exp/DATA
}


RUN_SNAPPY() {
	cd $BASE/appbench/apps/snappy-c
	./gendata-run-med.sh 1 &> $EXEC/snappy.out
	./release-run-med.sh &>> $EXEC/snappy.out
	python3 release-extract-med.py &>> $EXEC/snappy.out
	cat RESULT.csv  &> $EXEC/Figure9b-snappy.out
	rm -rf $BASE/appbench/apps/snappy-c/DATA
}

RUN_RocksDB-YCSB() {
	cd $BASE/appbench/apps/RocksDB-YCSB
	./release-run-med.sh &>> $EXEC/rocksdb-ycsb.out
	python3 release-extract-med.py &>> $EXEC/rocksdb-ycsb.out
	cat RESULT.csv &> $EXEC/Figure9a-rocksdb-ycsb.out
	rm -rf $BASE/appbench/apps/RocksDB-YCSB/DATA
}

RUN_RocksDB() {
	cd $BASE/appbench/apps/rocksdb
	./gendata-run-med.sh &> $EXEC/rocksdb.out
	./release-run-med.sh &>> $EXEC/rocksdb.out
	python3 release-extract-med.py &>> $EXEC/rocksdb.out
	cat RESULT.csv &>  $EXEC/Figure-7b-rocksdb.out
	#rm -rf $BASE/appbench/apps/rocksdb/DATA
}

RUN_RocksDB_SCALE() {
	cd $BASE/appbench/apps/rocksdb
	./release-scale-run-med.sh &>> $EXEC/rocksdb_scaling.out
	python3 release-scale-extract-med.py &>> $EXEC/rocksdb.out
	cat SCALE-RESULT.csv &>  $EXEC/Figure-7a-rocksdb_scaling.out
	#rm -rf $BASE/appbench/apps/rocksdb/DATA
}

RUN_MULTIREAD() {
	cd $BASE/appbench/apps/multi_read
	./compile.sh &> out.txt
	./release-run-med-pvt-rand.sh &>> $EXEC/multiread.out
	./release-run-med-pvt-seq.sh  &>> $EXEC/multiread.out
	./release-run-med-shared-rand.sh  &>> $EXEC/multiread.out
	./release-run-med-shared-seq.sh  &>> $EXEC/multiread.out
	python3 release-extract-med.py  &>> $EXEC/multiread.out
	cat RESULT.csv &> $EXEC/Figure5-multiread.out
}


cd $BASE
RUN_RocksDB-YCSB
sleep 10
RUN_RocksDB
sleep 10
RUN_RocksDB_SCALE
sleep 10
RUN_MMAPEXP
sleep 10
RUN_SIMPLEBENCH
sleep 10
RUN_MULTIREAD
sleep 10
RUN_SNAPPY
sleep 10
exit


