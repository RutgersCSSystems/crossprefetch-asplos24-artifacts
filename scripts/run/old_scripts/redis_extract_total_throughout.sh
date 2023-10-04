#!/bin/bash
#set -x

TARGET=$OUTPUTDIR
APP="redis"
TYPE="SSD"
RESULT=$NVMBASE/graphs/zplot/data/redis
SEARCH="requests per second"
mkdir -p $RESULT


EXTRACT_RESULT() {

	i=0
	j=0
	files=""
	file1=""
	rm $APP".data"
	rm "num.data"

	TYPE="NVM"
	for dir in $TARGET/*
	do
	
		rm  -rf $dir/*cleaned*
		
		for file in $dir/*
		do
			search=$APP".out-$TYPE"
			echo $search $file
			if [[ $file == *"$search"* ]];
			then
				echo $file
				cat $file | grep -a "$SEARCH" &> tmp.txt
				sed -i 's/\r/\n/g' tmp.txt && cat tmp.txt | grep "SET:" | tail -1 &> tmp1.txt && cat tmp.txt | grep "GET:" | tail -1 &>> tmp1.txt
				cat tmp1.txt &> $file"-cleaned"
			fi
		done


		 if [[ $dir == *"NVM"* ]]; 
		 then
			outfile=$(basename $dir)
			outputfile=$APP-$outfile".data"
			rm -rf $RESULT/$outputfile

			APPFILE=redis.out-NVM

			if [ -f $dir/$APPFILE ]; then
				cat $dir/$APP*-cleaned | grep -a "$SEARCH" | awk 'BEGIN {SUM=0}; {SUM+=$2}; END {printf "%5.3f\n", SUM}' &> $APP"-TOTAL.data"
				((j++))
				echo $j &> "num.data"
				paste "num.data" $APP"-TOTAL.data" &> $RESULT/$outputfile
				echo $RESULT/$outputfile
			fi
		fi
		done

	#Some gap
	((j++))

	 TYPE="SSD"
	for dir in $TARGET/*
	do
	if [[ $dir == *"SSD"* ]];
	 then
		outfile=$(basename $dir)
		outputfile=$APP-$outfile".data"
		APPFILE=redis.out-SSD
		rm -rf $RESULT/$outputfile

		if [ -f $dir/$APPFILE ]; then
			cat $dir/$APP*-cleaned | grep -a "$SEARCH" | awk 'BEGIN {SUM=0}; {SUM+=$2}; END {printf "%5.3f\n", SUM}' &> $APP"-TOTAL.data"
			((j++))
			echo $j &> "num.data"
			paste "num.data"  $APP"-TOTAL.data" &> $RESULT/$outputfile
			echo $RESULT/$outputfile
		fi
	fi
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
python $NVMBASE/graphs/zplot/scripts/e-redis.py
#EXTRACT_KERNSTAT





