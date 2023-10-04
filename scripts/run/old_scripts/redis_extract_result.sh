#!/bin/bash
TARGET=$OUTPUTDIR
APP="redis"
REDISDATA="graphs/zplot/data/redis"
mkdir -p $REDISDATA

EXTRACT_RESULT() {

	i=0
	j=0
	k=6
	files=""
	file1=""
	rm $APP".data"
	rm "num*.data"

	for dir in $TARGET/*
	do
		#dir=$OUTPUTDIR
		echo $(basename $dir)
		outfile=$(basename $dir)
		APPFILE=redis.out
		if [ -f $dir/$APPFILE ]; then
			cat $dir/$APP* | grep -a "SET:" | awk 'BEGIN {SUM=0}; {SUM+=$2}; END {printf "%5.3f\n", SUM}' &> $APP"-SET.data"
			cat $dir/$APP* | grep -a "SET:" | awk 'BEGIN {SUM=0}; {SUM+=$2}; END {printf "%5.3f\n", SUM}'
			((j++))
			echo $j &> "num.data"

			cat $dir/$APP* | grep -a "GET:" | awk 'BEGIN {SUM=0}; {SUM+=$2}; END {printf "%5.3f\n", SUM}' &> $APP"-GET.data"
			cat $dir/$APP* | grep -a "GET:" | awk 'BEGIN {SUM=0}; {SUM+=$2}; END {printf "%5.3f\n", SUM}'
			((k++))
			echo $k &> "num1.data"
		fi
		((i++))
		rm $REDISDATA/$APP-$outfile"-SET.data"
		rm $REDISDATA/$APP-$outfile"-GET.data"
		paste "num.data" $APP"-SET.data" &> $REDISDATA/$APP-$outfile"-SET.data"
		paste "num1.data" $APP"-GET.data" &> $REDISDATA/$APP-$outfile"-GET.data"
		echo $REDISDATA/$APP-$outfile"-GET.data"
	done
}

EXTRACT_INFO() {
	dir=$1
	APP=$2
	if [ -f $dir/$APP ]; then
		echo "----------------------------"$APP"----------------"
		cat $dir/$APP | grep "page_cache_hits" | awk '{sum += $9} END {print "page_cache_hits: " sum}'
		cat $dir/$APP | grep "page_cache_miss" | awk '{sum += $11} END {print "page_cache_miss: " sum}'
		cat $dir/$APP | grep "buff_page_hits" | awk '{sum += $13} END {print "buff_page_hits: " sum}'
		cat $dir/$APP | grep "buff_buffer_miss" | awk '{sum += $15} END {print "buff_buffer_miss: " sum}'
	fi
}

EXTRACT_INFO_OLD() {
	dir=$1
	APP=$2
	if [ -f $dir/$APP ]; then
		echo "----------------------------"$APP"----------------"
		cat $dir/$APP | grep "cache" | awk '{sum += $13} END {print "page_cache_hits: " sum}'
		cat $dir/$APP | grep "cache miss" | awk '{sum += $16} END {print "page_cache_miss: " sum}'
		cat $dir/$APP | grep "buffer page hits" | awk '{sum += $20} END {print "buff_page_hits: " sum}'
		cat $dir/$APP | grep "miss" | awk '{sum += $24} END {print "buff_buffer_miss: " sum}'
	fi
}

EXTRACT_KERNSTAT(){
	
	for dir in $TARGET/*
	do 
		echo $dir
		APP=db_bench 
		EXTRACT_INFO_OLD $dir $APP

		APP=redis
		EXTRACT_INFO_OLD $dir $APP

		APP=filebench
		EXTRACT_INFO_OLD $dir $APP
	done

}

EXTRACT_RESULT
cd $NVMBASE/graphs/zplot/
python $NVMBASE/graphs/zplot/scripts/e-redis-breakdown.py
#EXTRACT_KERNSTTCT_RESULT

set +x



