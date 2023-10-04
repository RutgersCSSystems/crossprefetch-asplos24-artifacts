#!/bin/bash
#set -x

TARGET=$OUTPUTDIR
#APP="rocksdb"
APP="redis"
#TYPE="SSD"
TYPE="NVM"

STATTYPE="APP"
STATTYPE="KERNEL"
ZPLOT="$NVMBASE/graphs/zplot"

## Scaling Kernel Stats Graph
let SCALE_KERN_GRAPH=100000
let SCALE_FILEBENCH_GRAPH=1000
let SCALE_REDIS_GRAPH=1000
let SCALE_ROCKSDB_GRAPH=1000
let SCALE_CASSANDRA_GRAPH=100
let SCALE_SPARK_GRAPH=50000



let INCR_KERN_BAR_SPACE=3
let INCR_BREAKDOWN_BAR_SPACE=2
let INCR_FULL_BAR_SPACE=1
let INCR_ONE_SPACE=1


## declare an array variable
declare -a kernstat=("cache-miss" "buff-miss" "migrated")
declare -a excludekernstat=("obj-affinity-NVM1")

##use this for storing some state
let slowmemhists=0

#declare -a placearr=('slowmem-only' 'optimal-os-fastmem'  'naive-os-fastmem' 'slowmem-migration-only' 'slowmem-obj-affinity'  'slowmem-obj-affinity-prefetch')
declare -a placearr=('APPSLOW-OSSLOW' 'APPFAST-OSFAST' 'APPFAST-OSSLOW' 'APPSLOW-OSFAST')


declare -a pattern=("fillrandom" "readrandom" "fillseq" "readseq" "overwrite")

#declare -a configarr=("BW500" "BW1000" "BW2000" "BW4000")
#declare -a configarr=("BW1000")
declare -a configarr=("CAP2048" "CAP4096" "CAP8192" "CAP10240")


declare -a mechnames=('naive-os-fastmem' 'optimal-os-fastmem' 'slowmem-migration-only' 'slowmem-obj-affinity-nomig'  'slowmem-obj-affinity' 'slowmem-obj-affinity-net' 'slowmem-only')


#declare -a devices=("SSD" "NVM")
declare -a devices=("NVM")

declare -a excludefullstat=("NVM1" "prefetch")

declare -a excludebreakdown=("optimal" "NVM1" "nomig" "naive" "affinity-net" "slowmem-only" "optimal")

declare -a redispattern=("SET" "GET")


declare -a mech_redis_prefetch=('slowmem-obj-affinity' 'slowmem-obj-affinity-prefetch')



source scripts/rocksdb_extract_result.sh





#####################REDIS NETWORK##############################
j=0
APP='redis'
OUTPUTDIR="/users/skannan/ssd/NVM/results/redis-results-Aug11"
TARGET=$OUTPUTDIR
EXTRACT_REDIS_BREAKDOWN_RESULT "redis"
cd $ZPLOT
python2.7 $NVMBASE/graphs/zplot/scripts/e-redis-breakdown.py

exit




####################KERNEL STAT ################################
j=0
APP='rocksdb'
#OUTPUTDIR="results/output-Aug8-allapps-sensitivity"
OUTPUTDIR=/users/skannan/ssd/NVM/appbench/output
TARGET=$OUTPUTDIR
EXTRACT_RESULT_SENSITIVE "rocksdb"
cd $ZPLOT
python2.7 $NVMBASE/graphs/zplot/scripts/m-rocksdb-sensitivity.py
exit

####################MOTIVATION ANALYSIS########################

j=0
APP='rocksdb'
OUTPUTDIR="results/output-Aug8-allapps-sensitivity"
TARGET=$OUTPUTDIR
EXTRACT_RESULT_COMPARE "rocksdb"

APP='redis'
TARGET=$OUTPUTDIR
EXTRACT_RESULT_COMPARE "redis"


APP='filebench'
TARGET=$OUTPUTDIR
EXTRACT_RESULT_COMPARE "filebench"

APP='cassandra'
OUTPUTDIR="/users/skannan/ssd/NVM/appbench/output"
TARGET=$OUTPUTDIR
EXTRACT_RESULT_COMPARE "cassandra"


cd $ZPLOT
python2.7 $NVMBASE/graphs/zplot/scripts/m-allapps-total.py
exit

####################ALL APPS##########################
j=0
APP='filebench'
OUTPUTDIR="/users/skannan/ssd/NVM/results/output-Aug11-allapps"
TARGET=$OUTPUTDIR
EXTRACT_RESULT "filebench"

APP='redis'
FORMAT_RESULT_REDIS "redis"
EXTRACT_RESULT "redis"

APP='rocksdb'
TARGET=$OUTPUTDIR
EXTRACT_RESULT "rocksdb"

APP='cassandra'
TARGET=$OUTPUTDIR
EXTRACT_RESULT "cassandra"


APP='spark-bench'
TARGET=$OUTPUTDIR
EXTRACT_RESULT "spark-bench"

cd $ZPLOT
python2.7 $NVMBASE/graphs/zplot/scripts/e-allapps-total.py
exit


j=0
APP='rocksdb'
OUTPUTDIR="results/output-Aug11-allapps"
TARGET=$OUTPUTDIR
EXTRACT_KERNSTAT "rocksdb"
cd $ZPLOT
python2.7 $NVMBASE/graphs/zplot/scripts/e-rocksdb-kernstat.py -o "e-rocksdb-kernstat" -a "rocksdb" -y 400 -r 50 -s "NVM"
exit







#######################ROCKSDB PREFETCH#########################
j=0
APP='rocksdb'
#OUTPUTDIR="results/output-Aug8-allapps"
OUTPUTDIR="/users/skannan/ssd/NVM/results/rocksdb-results-prefetch-Aug13"
TARGET=$OUTPUTDIR
EXTRACT_BREAKDOWN_RESULT "rocksdb"
cd $ZPLOT
python2.7 $NVMBASE/graphs/zplot/scripts/e-rocks-prefetch-breakdown.py
exit



#EXTRACT_KERNSTAT "redis"
#cd $ZPLOT
#python $NVMBASE/graphs/zplot/scripts/e-rocksdb-kernstat.py -i "" -o "e-redis-kernstat" -a "redis" -y 80 -r 10 -s "SSD"



######################################################
j=0
APP='redis'
OUTPUTDIR="/users/skannan/ssd/NVM/appbench/output"
TARGET=$OUTPUTDIR
EXTRACT_REDIS_PREFETCH_BREAKDOWN_RESULT "redis"
cd $ZPLOT
python2.7 $NVMBASE/graphs/zplot/scripts/e-redis-prefetch-breakdown.py
exit


######################################################

j=0
APP='redis'
OUTPUTDIR="/users/skannan/ssd/NVM/results/redis-results-july30th"
TARGET=$OUTPUTDIR
#FORMAT_RESULT_REDIS
EXTRACT_REDIS_BREAKDOWN_RESULT "redis"
cd $ZPLOT
python $NVMBASE/graphs/zplot/scripts/e-redis-breakdown.py
exit



j=0
APP='rocksdb'
OUTPUTDIR="/users/skannan/ssd/NVM/appbench/output"
EXTRACT_RESULT_SENSITIVE "rocksdb"
cd $ZPLOT
python $NVMBASE/graphs/zplot/scripts/e-rocksdb-sensitivity.py
exit




EXTRACT_RESULT
cd $ZPLOT
python $NVMBASE/graphs/zplot/scripts/e-rocksdb-total.py
exit






#EXTRACT_KERNSTAT




			#let val=`cat $target | grep "HeteroProcname" &> orig.txt && sed -i 's/\[ /\[/g' orig.txt && sed 's/\s/,/g' orig.txt > modified.txt && cat modified.txt | awk -F, -v OFS=, "BEGIN {SUM=0}; {SUM=SUM+$search}; END {print SUM}"`

