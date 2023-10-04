#!/bin/bash
echo "   "
APP=graphchi
grep "Elapsed" $OUTPUTDIR/$APP | awk '{print "graphchi: " $8}'
APP=db_bench
cat $OUTPUTDIR/$APP | grep "MB/s" | awk 'BEGIN {SUM=0}; {SUM=SUM+$7}; END {print "rocksdb: " SUM}'
APP=fio
cat $OUTPUTDIR/$APP | grep "WRITE: bw=" | awk '{print $2}'| grep -o '[0-9]*' | awk '{sum += $1} END {print "fio: " sum}'
#APP=fcreate
#cat $OUTPUTDIR/$APP | grep "bw=" | awk '{print $2}'| grep -o '[0-9]*' | awk '{sum += $1} END {print "fcreate: " sum}'
APP=Metis
grep "Real:" $OUTPUTDIR/$APP | awk '{print "Metis: " $2}'
APP=redis
cat $OUTPUTDIR/$APP | grep -a "ET:" | awk 'BEGIN {SUM=0}; {SUM+=$3}; END {printf "redis: %5.3f\n", SUM}'
APP=memcached
cat $OUTPUTDIR/$APP | grep -a "ETS:" | tail -1 | awk 'BEGIN {SUM=0}; {SUM=$2+$4}; END {print "memcached: " SUM}'
echo "________________________"
#APP=leveldb
#awk 'BEGIN {SUM=0}; {SUM=SUM+$3}; END {printf "%.3f\n", SUM}' $OUTPUTDIR/$APP
