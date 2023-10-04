#!/bin/bash
TARGET=$OUTPUTDIR
APP="redis"
TYPE="SSD"
SEARCH="requests per second"

STATTYPE="APP"
STATTYPE="KERNEL"
ZPLOT="$NVMBASE/graphs/zplot"
INSTANCES=4

## declare an array variable
declare -a arr=("cache-hits" "cache-miss" "buff-hits" "buff-miss" "migrated")
declare -a pattern=("SET" "GET")

EXTRACT_KERNINFO() {

        #application
	APP=$1
	#current directory
	dir=$2
	outfile=$(basename $dir)
        j=$3      
	APPFILE=$4
	access=$5
	resultdir=$ZPLOT/data/patern
	let instances=$INSTANCES
	mkdir -p $resultdir

	outputfile=$APP-$outfile
	rm -rf $resultdir/$outputfile
	rm -rf "num.data"
	resultfile=$APP"-"$access"-kerninfo.data"
	OUTPUT=$resultdir/$outputfile"-"$access"-kerninfo.data"
	rm -f tmp.txt

        if [ -f $dir/$APP".out" ]; then
		file=$dir/$APP.out
		search="redis-server"
		awkidx=10
		echo "*****"$instances

		for i in $(seq 1 $instances);
		do
			cat $dir/$APP | grep $search$i | awk '{sum += $10 } END {print "page_cache_hits: " sum}'
		done
                #((j++))
                #echo $j &> "num.data"
                #paste "num.data" $resultfile &> $OUTPUT
		#echo $OUTPUT
		#cat $OUTPUT
                #rm -rf "num.data" $resultfile
        fi

	#dir=$1
	#APP=$2
	#awkidx=10
	#if [ -f $dir/$APP ]; then
	#for term in "${arr[@]}"
		#do
			#echo "----------------------------"$APP"----------------"
			#search="$"$awkidx
			#echo $search
			#cat $dir/$APP | grep $term | awk -v myvar="$search" '{sum += myvar } END {print "page_cache_hits: " sum}'
			#cat $dir/$APP | grep Currname | awk -v myvar="$search" '{sum += myvar } END {print "page_cache_hits: " sum}'
			#cat $dir/$APP | grep "page_cache_hits" | awk '{sum += $9} END {print "page_cache_hits: " sum}'
			#cat $dir/$APP | grep "page_cache_miss" | awk '{sum += $11} END {print "page_cache_miss: " sum}'
			#cat $dir/$APP | grep "buff_page_hits" | awk '{sum += $13} END {print "buff_page_hits: " sum}'
			#cat $dir/$APP | grep "buff_buffer_miss" | awk '{sum += $15} END {print "buff_buffer_miss: " sum}'
			#((awkidx++))
			#((awkidx++))
		#done
	#fi
}


PULL_RESULT_PATTERN() {

	APP=$1
	dir=$2
        j=$3      
	APPFILE=$4
	access=$5
	resultdir=$ZPLOT/data/patern
	mkdir -p $resultdir

	outfile=$(basename $dir)
	outputfile=$APP-$outfile
	rm -rf $resultdir/$outputfile
	rm -rf "num.data"
	resultfile="$APP"-"$access.data"
	rm -f tmp.txt

        if [ -f $dir/$APPFILE ]; then
		file=$dir/$APPFILE
		#echo $file
		cat $file | grep -a "$SEARCH" &> tmp.txt
                cat tmp.txt | grep $access":" | awk 'BEGIN {SUM=0}; {SUM+=$2}; END {printf "%5.3f\n", SUM}' &> $resultfile
                ((j++))
                echo $j &> "num.data"
                paste "num.data" $resultfile &> $resultdir/$outputfile"-"$access".data"
		echo $resultdir/$outputfile"-"$access".data"
		cat $resultdir/$outputfile"-"$access".data"
                rm -rf "num.data" $resultfile
        fi
}

CONSOLIDATE_RESULT() {

	dir=$1
	APP=$2

	rm -rf $dir/$APP-"all.out"
	for file in $dir/$APP*.txt
	do
		search=$APP
		if [[ $file == *"$search"*".txt" ]];
		then
			cat $file | grep "ET:" &> tmp.txt
			sed -i 's/\r/\n/g' tmp.txt
			cat tmp.txt | grep "SET:" | tail -1 &>> $dir/$APP-"all.out"
			cat tmp.txt | grep "GET:" | tail -1 &>> $dir/$APP-"all.out"
		fi
	done
	rm -rf tmp.txt
}


EXTRACT_BREAKDOWN_RESULT() {
	i=0
	j=0
	files=""
	rm $APP".data"
	APPFILE=""


	for accesstype in "${pattern[@]}"
	do
		APPFILE=""
		TYPE="NVM"
		for dir in $TARGET/*
		do
		 if [[ $dir = *"NVM"* ]]; 
		 then
			APPFILE=redis.out-NVM
			CONSOLIDATE_RESULT $dir $APP
		fi
		done

		APPFILE=""
		TYPE="SSD"
		for dir in $TARGET/*
		do
		if [[ $dir == *"SSD"* ]];
		 then
			APPFILE=redis.out-SSD
			CONSOLIDATE_RESULT $dir $APP
		fi
		done
	done


	APPFILE=""
	TYPE="SSD"
	for accesstype in "${pattern[@]}"
	do

		for dir in $TARGET/*SSD*
		do
			APPFILE=redis.out-SSD
			PULL_RESULT_PATTERN $APP $dir $j $APP-"all.out" $accesstype
		done
		((j++))
	done

	APPFILE=""
	TYPE="NVM"
	for accesstype in "${pattern[@]}"
	do
		for dir in $TARGET/*NVM*
		do
			APPFILE=redis.out-NVM
			PULL_RESULT_PATTERN $APP $dir $j $APP-"all.out" $accesstype
		done
		((j++))
	done

}


EXTRACT_BREAKDOWN_RESULT
cd $ZPLOT
python $NVMBASE/graphs/zplot/scripts/e-redis-breakdown.py




PULL_RESULT() {

	APP=$1
	dir=$2
        j=$3      
	APPFILE=$4

	outputfile=$APP-$outfile".data"
	outfile=$(basename $dir)
	outputfile=$APP-$outfile".data"
	rm -rf $ZPLOT/data/$outputfile
	rm -rf "num.data"

	if [ -f $dir/$APPFILE ]; then
		#echo $dir/$APPFILE
		cat $dir/$APPFILE | grep "micros" | awk 'BEGIN {SUM=0}; {SUM=SUM+$7}; END {print SUM}' &> $APP".data"
		((j++))
		echo $j &> "num.data"
		paste "num.data" $APP".data" &> $ZPLOT/data/$outputfile
		#echo $ZPLOT/data/$outputfile
	fi
}




