#!/bin/bash

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
let SCALE_LLC_GRAPH=10000000


let INCR_KERN_BAR_SPACE=3
let INCR_BREAKDOWN_BAR_SPACE=2
let INCR_FULL_BAR_SPACE=1
let INCR_ONE_SPACE=1


## declare an array variable
declare -a kernstat=("cache-miss" "buff-miss" "migrated")

## page use information
declare -a pagestat=("BUFF-PAGES" "CACHE-PAGES" "APP-PAGES")

## page lifetime information
declare -a lifestat=("CACHE-PAGE-LIFE" "BUFF-PAGE-LIFE")

## sysstat use information
declare -a sysstat=("Lib" "Kernel" "App")

##LLC Miss
declare -a llcstat=("APP" "Lib" "Kernel")


##use this for storing some state
let slowmemhists=0

declare -a placearr=('slowmem-only' 'optimal-os-fastmem'  'naive-os-fastmem' 'slowmem-migration-only' 'slowmem-obj-affinity-nomig' 'slowmem-obj-affinity' 'slowmem-obj-affinity-prefetch' 'slowmem-obj-affinity-net')
declare -a placearrcontextsensitivity=('slowmem-only' 'optimal-os-fastmem'  'naive-os-fastmem' 'slowmem-migration-only' 'slowmem-obj-affinity-prefetch')
declare -a placearrprefetch=('slowmem-obj-affinity-noprefetch' 'slowmem-obj-affinity-prefetch')


declare -a sensitive_arr=('APPSLOW-OSSLOW' 'APPFAST-OSFAST' 'APPSLOW-OSFAST' 'APPFAST-OSSLOW')
declare -a placearrcontextsensitivity=('slowmem-only' 'optimal-os-fastmem'  'naive-os-fastmem' 'slowmem-migration-only' 'slowmem-obj-affinity-prefetch')

declare -a pattern=("fillrandom" "readrandom" "fillseq" "readseq" "overwrite")

declare -a configarrbwall=("BW500" "BW1000" "BW2000" "BW4000")
declare -a configarrbw=("BW1000")

declare -a configarrcap=("CAP2048" "CAP4096" "CAP8192" "CAP10240")

declare -a mechnames=('naive-os-fastmem' 'optimal-os-fastmem' 'slowmem-migration-only' 'slowmem-obj-affinity-nomig'  'slowmem-obj-affinity' 'slowmem-obj-affinity-net' 'slowmem-only')
#declare -a devices=("SSD" "NVM")
declare -a devices=("NVM")

declare -a excludekernstat=("obj-affinity-NVM1" 'slowmem-obj-affinity-NVM' 'slowmem-obj-affinity-nomig-NVM')

declare -a excludefullstat=('slowmem-obj-affinity-prefetch' 'slowmem-obj-affinity-net' 'NVM1')
declare -a excludefullstat_noprefetch=('slowmem-obj-affinity-prefetch' 'slowmem-obj-affinity-net' 'NVM1')
declare -a excludefullstat_prefetch=('naive-os-fastmem' 'optimal-os-fastmem' 'slowmem-migration-only' 'slowmem-obj-affinity-nomig' 'slowmem-obj-affinity-net' 'slowmem-only')


declare -a excludesensitivecontext=("NVM1" "obj-affinity-net")
declare -a excludebreakdown=("optimal" "NVM1" "nomig" "naive" "affinity-net" "slowmem-only" "optimal")
declare -a excluderedisbreakdown=("affinity-prefetch")

declare -a redispattern=("SET" "GET")
declare -a mech_redis_prefetch=('slowmem-obj-affinity' 'slowmem-obj-affinity-prefetch')


EXTRACT_KERNINFO() {

        APP=$1
        dir=$2
	j=$3
        APPFILE=$4
	awkidx=$5
	stattype=$6
	localtype=$6
	file=$APPFILE
        resultdir=$ZPLOT/data/kernstat
        mkdir -p $resultdir

        outfile=$(basename $dir)
        outputfile=$APP-$outfile"-"$stattype".data"
        rm -rf $resultdir/$outputfile
        rm -rf "num.data"

        if [ "$APP" == "redis" ]
	then
		target=$dir/$APP"-kernel.out"
	else
		target=$dir/$file
	fi

	if [ -f $target ]; then

		search="$"$awkidx
	        if [ "$APP" == "redis" ]
		then
			let val=`cat $target | grep "HeteroProcname" &> orig.txt && sed 's/\s/,/g' orig.txt > modified.txt && cat modified.txt | awk -F, -v OFS=, "BEGIN {SUM=0}; {SUM=SUM+$search}; END {print SUM}"`  
		else
			if [[ $dir == *"slowmem-only"*  ]]; then
				if [[ $stattype == "cache-miss"  ]]; then
					localtype="cache-hits"
				fi	
			fi

			grep -r "HeteroProcname" $target  &> out.txt
			temp=`grep -Eo "$localtype([[:space:]]+[^[:space:]]+){1}" < out.txt`
			val=`echo $temp | awk '{print $2}'`

			if [[ $dir == *"optimal"*  ]]; then
				if [[ $localtype == *"cache-miss"*  ]]; then
					val=0
				fi	
			fi
		fi

		let scaled_value=$val/$SCALE_KERN_GRAPH
		echo $scaled_value &> $APP"kern.data"
		((j++))
		echo $j &> "num.data"
		paste "num.data" $APP"kern.data" &> $resultdir/$outputfile
		rm -rf "num.data" $APP"kern.data"
	fi
}


PULL_RESULT() {
	APP=$1
	dir=$2
        j=$3      
	APPFILE=$4
	GRAPHDATA=$5
	EXT=$6

	outfile=$(basename $dir)
	outputfile=$APP"-"$outfile$EXT".data"
	resultfile=$ZPLOT/data/$GRAPHDATA/$outputfile
	mkdir -p $ZPLOT/data/$GRAPHDATA
	rm -rf $resultfile
	rm -rf "num.data"

	echo "$dir/$APPFILE"

	if [ -f $dir/$APPFILE ]; then

		if [ "$APP" = 'redis' ]; 
		then
			val=`cat $dir/$APPFILE | grep -a "ET" | grep $access":" | awk 'BEGIN {SUM=0}; {SUM+=$2}; END {printf "%5.3f\n", SUM}'`
			scaled_value=$(echo $val $SCALE_REDIS_GRAPH | awk '{printf "%4.0f\n",$1/$2}')
			echo $scaled_value &> $APP".data"

		elif [  "$APP" = 'cassandra' ];
		then
			val=`cat $dir/$APPFILE | grep "Throughput" |  tail -1 | awk '{printf "%5.0f\n", $3}'`
			scaled_value=$(echo $val $SCALE_CASSANDRA_GRAPH | awk '{printf "%4.0f\n",$1/$2}')
			echo $scaled_value &> $APP".data"
		elif [  "$APP" = 'filebench' ]; 
		then
			val=`cat $dir/$APPFILE | grep "IO Summary:" | awk 'BEGIN {SUM=0}; {SUM=SUM+$6}; END {print SUM}'`
			scaled_value=$(echo $val $SCALE_FILEBENCH_GRAPH | awk '{printf "%4.0f\n",$1/$2}')
			echo $scaled_value &> $APP".data"

	       elif [  "$APP" = 'spark-bench' ];
	       then
                        val=`cat $dir/$APPFILE | grep "Elapsed" | awk '{print $8}' | awk -F: '{ print ($1 * 60) + ($2) + $3 }'`
                        scaled_value=$(echo $val $SCALE_SPARK_GRAPH | awk '{printf "%4.0f\n", $2/$1}')
			echo $dir/$APPFILE" "$val" "$scaled_value
                        echo $scaled_value &> $APP".data"
			#echo $dir/$APPFILE" "$APP".data"
			#cat $APP".data"
		else
			cp $dir/$APPFILE $dir/$APPFILE".txt"
			sed -i "/readseq/c\ " $dir/$APPFILE".txt"
			val=`cat $dir/$APPFILE".txt" | grep "ops/sec" | awk 'BEGIN {SUM=0}; {SUM=SUM+$5}; END {print SUM}'`
			scaled_value=$(echo $val $SCALE_ROCKSDB_GRAPH | awk '{printf "%4.0f\n",$1/$2}')
			echo $scaled_value &> $APP".data"
			echo $scaled_value
		fi
		((j++))
		echo $j &> "num.data"
		paste "num.data" $APP".data" &> $resultfile
	fi
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

	if [ -f $dir/$APPFILE ]; then

		file=$dir/$APPFILE
		
		if [ "$APP" = 'redis' ]; then
			val=`cat $file | grep -a "$SEARCH" | grep $access":" | awk 'BEGIN {SUM=0}; {SUM+=$2}; END {printf "%5.3f\n", SUM}'`
			#if [ "$access" == "ET" ]; 
			#then
				scaled_value=$(echo $val 100 | awk '{printf "%4.0f\n",$1/$2}')
				echo $scaled_value &> $resultfile
			#else
				#echo $val &> $resultfile
			#fi
		else
			if [ "$access" = 'readseq' ]; then
				cat $file | grep $access" " | awk 'BEGIN {SUM=0}; {SUM=SUM+$7}; END {printf "%5.0d\n", SUM/10}' &> $resultfile
			else
				cat $file | grep $access" " | awk 'BEGIN {SUM=0}; {SUM=SUM+$7}; END {printf "%5.0f\n", SUM}' &> $resultfile
			fi
		fi

		((j++))
		echo $j &> "num.data"
		paste "num.data" $resultfile &> $resultdir/$outputfile"-"$access".data"
		rm -rf "num.data" $resultfile
	fi
}

function EXCLUDE_DIR  {

	exlude=$1
	dir=$2
	local -n list=$3

	for check in "${list[@]}"
	do
		if [[ $dir == *"$check"* ]]; then
			((exlude++))	
		fi
	done
}



EXTRACT_BREAKDOWN_RESULT() {
	i=0
	j=0
	files=""
	rm $APP".data"
	let exlude=0

	APPFILE=""
	TYPE="NVM"

	for device in "${devices[@]}"
	do
		TYPE=$device
		APPFILE=$APP".out-"$device

		for accesstype in "${pattern[@]}"
		do
			for dir in $TARGET/*$device*
			do
                                exlude=0
                                EXCLUDE_DIR $exlude $dir excludebreakdown
                                if [ $exlude -ge 1 ]; then
                                        echo "EXCLUDING" $dir
                                        continue;
				else
					echo "NOT EXCLUDING" $dir
                                fi
				PULL_RESULT_PATTERN $APP $dir $j $basename $APPFILE $accesstype
			done
		j=$((j+$INCR_BREAKDOWN_BAR_SPACE))
		done
	done
}




EXTRACT_KERNSTAT() {

	j=0
	exlude=0
	APP=$1
	rm $APP".data"
	rm "num.data"

	for device in "${devices[@]}"
	do
		TYPE=$device
		APPFILE=$APP".out-"$device

		 if [ $TYPE == "SSD" ]; then
			awkidx=10
		 else
			awkidx=11
		 fi

		if [ "$APP" == "redis" ]
		then
			awkidx=8
		fi

		for stattype in "${kernstat[@]}"
		do

                        for placement in "${placearr[@]}"
                        do
                                for dir in $TARGET/$placement-$device
                                do
					exlude=0
					EXCLUDE_DIR $exlude $dir excludekernstat
					if [ $exlude -ge 1 ]; then
						echo "EXCLUDING >>>>>"$dir
						continue;
					fi
					EXTRACT_KERNINFO $APP $dir $j $APPFILE $awkidx $stattype
				done
			
			done
			if [ "$stattype" == "buff-miss" ];
			then
				((awkidx++))
				((awkidx++))
			else
				((awkidx++))
				((awkidx++))
				((awkidx++))
				((awkidx++))
			fi

			j=$((j+$INCR_KERN_BAR_SPACE))

		done
	done
}


let buff_val=0

EXTRACT_PAGESTAT() {

        APP=$1
        dir=$2
	j=$3
	stattype=$4
	let prev_val=$buff_val

        resultdir=$ZPLOT/data/pagestat
	file=$APP".out-NVM"
        mkdir -p $resultdir

        outfile=$(basename $dir)
        outputfile=$APP-$outfile"-"$stattype".data"
        rm -rf $resultdir/$outputfile
        rm -rf "num.data"

	target=$dir/$file
	OUTFILE=$APP"-pagestat.data"

	if [ -f $target ]; then
		search=$stattype
		grep -r $search $target | tail -1 |  tr -d ','  &> out.txt
		temp=`grep -Eo "$search([[:space:]]+[^[:space:]]+){1}" < out.txt`
		val=`echo $temp | awk '{print $2}'`
		let new_val=($buff_val + $val)
		echo $new_val
		let scaled_value=$new_val/$SCALE_KERN_GRAPH
		echo $scaled_value &> $OUTFILE
		echo $j &> "num.data"
		paste "num.data" $OUTFILE &> $resultdir/$outputfile
		rm -rf "num.data" $OUTFILE
		buff_val=$new_val
	fi
}


GETPAGESTAT() {

	exlude=0
	APP=$1
	rm $APP".data"
	rm "num.data"

	TYPE="NVM"
	APPFILE=$APP".out-"$device
	dir=$TARGET
	let prev_val=0
	for stattype in "${pagestat[@]}"
	do
		EXTRACT_PAGESTAT $APP $dir $j $stattype $prev_val
	done

	buff_val=0
	j=$((j+5))
	#j=$((j+$INCR_KERN_BAR_SPACE))
}


EXTRACT_SYSSTAT() {

        APP=$1
        dir=$2
	j=$3
	stattype=$4
	let prev_val=$buff_val

        resultdir=$ZPLOT/data/sysstat
	file=$APP".out-NVM"
        mkdir -p $resultdir

        outfile=$(basename $dir)
        outputfile=$APP-$outfile"-"$stattype".data"
        rm -rf $resultdir/$outputfile
        rm -rf "num.data"

	target=$dir/$file
	OUTFILE=$APP"-sysstat.data"

	if [ -f $target ]; then
		search=$stattype
		grep -r $search $target | tail -1 |  tr -d ','  &> out.txt
		temp=`grep -Eo "$search([[:space:]]+[^[:space:]]+){1}" < out.txt`
		val=`echo $temp | awk '{print $2}'`
		let new_val=($buff_val + $val)
		let scaled_value=$new_val
		echo $scaled_value &> $OUTFILE
		echo $j &> "num.data"
		paste "num.data" $OUTFILE &> $resultdir/$outputfile
		rm -rf "num.data" $OUTFILE
		buff_val=$new_val
	fi
}


GETSYSSTAT() {

	exlude=0
	APP=$1
	rm $APP".data"
	rm "num.data"

	TYPE="NVM"
	APPFILE=$APP".out-"$device
	dir=$TARGET
	let prev_val=0
	for stattype in "${sysstat[@]}"
	do
		EXTRACT_SYSSTAT $APP $dir $j $stattype $prev_val
	done

	buff_val=0
	j=$((j+5))
	#j=$((j+$INCR_KERN_BAR_SPACE))
}

EXTRACT_LLCSTAT() {

        APP=$1
        dir=$2
	j=$3
	stattype=$4
	let prev_val=$buff_val

        resultdir=$ZPLOT/data/llcstat
	file=$APP".out-NVM"
        mkdir -p $resultdir

        outfile=$(basename $dir)
        outputfile=$APP-$outfile"-"$stattype".data"
        rm -rf $resultdir/$outputfile
        rm -rf "num.data"

	target=$dir/$file
	OUTFILE=$APP"-llcstat.data"

	if [ -f $target ]; then
		search=$stattype
		grep -r $search $target | tail -1 |  tr -d ','  &> out.txt
		temp=`grep -Eo "$search([[:space:]]+[^[:space:]]+){1}" < out.txt`
		val=`echo $temp | awk '{print $2}'`
		let new_val=($buff_val + $val)
		let scaled_value=$new_val/$SCALE_LLC_GRAPH
		echo $scaled_value &> $OUTFILE
		echo $j &> "num.data"
		paste "num.data" $OUTFILE &> $resultdir/$outputfile
		rm -rf "num.data" $OUTFILE
		buff_val=$new_val
		echo "******"$new_val"*****"$target"*****"$search"*******"$resultdir/$outputfile
	fi
}


GETLLCSTAT() {

	exlude=0
	APP=$1
	rm $APP".data"
	rm "num.data"

	TYPE="NVM"
	APPFILE=$APP".out-"$device
	dir=$TARGET
	let prev_val=0
	for stattype in "${llcstat[@]}"
	do
		EXTRACT_LLCSTAT $APP $dir $j $stattype $prev_val
	done
	buff_val=0
	j=$((j+5))
	#j=$((j+$INCR_KERN_BAR_SPACE))
}




EXTRACT_LIFESTAT() {

        APP=$1
        dir=$2
	j=$3
	stattype=$4
	let prev_val=$buff_val

        resultdir=$ZPLOT/data/lifestat
	file=$APP".out-NVM"
        mkdir -p $resultdir

        outfile=$(basename $dir)
        outputfile=$APP-$outfile"-"$stattype".data"
        rm -rf $resultdir/$outputfile
        rm -rf "num.data"

	target=$dir/$file
	OUTFILE=$APP"-lifestat.data"

	echo $target

	if [ -f $target ]; then
		search=$stattype
		grep -r $search $target | tail -1 |  tr -d ','  &> out.txt
		temp=`grep -Eo "$search([[:space:]]+[^[:space:]]+){1}" < out.txt`
		val=`echo $temp | awk '{print $2}'`
		let new_val=($buff_val + $val)
		echo $new_val
		let scaled_value=$new_val/$SCALE_KERN_GRAPH
		echo $scaled_value &> $OUTFILE
		echo $j &> "num.data"
		paste "num.data" $OUTFILE &> $resultdir/$outputfile
		rm -rf "num.data" $OUTFILE
		buff_val=$new_val
	fi
}


GETLIFESTAT() {

	exlude=0
	APP=$1
	rm $APP".data"
	rm "num.data"

	TYPE="NVM"
	APPFILE=$APP".out-"$device
	dir=$TARGET
	let prev_val=0
	for stattype in "${lifestat[@]}"
	do
		EXTRACT_LIFESTAT $APP $dir $j $stattype $prev_val
		j=$((j+1))
	done

	buff_val=0
	j=$((j+5))
	#j=$((j+$INCR_KERN_BAR_SPACE))
}




REDIS_CONSOLIDATE_RESULT() {

        dir=$1
        APP=$2
	let instances=4

        rm -rf $dir/$APP-"all.out"

        for file in $dir/$APP*.txt
        do
                search=$APP
                if [[ $file == *"$search"*".txt" ]];
                then
			rm -rf $dir/$APP"-all.out-"$device
                        cat $file | grep "ET:" &> tmp.txt
                        sed -i 's/\r/\n/g' tmp.txt
                        cat tmp.txt | grep "SET:" | tail -1 &>> $dir/$APP"-all.out-"$device
                        cat tmp.txt | grep "GET:" | tail -1 &>> $dir/$APP"-all.out-"$device
			rm -rf tmp.txt
                fi
        done

	for file in $dir/$APP".out-"*
	do
		if [ -f $file ]; then
			text="Currname\sredis-server"
			awkidx=10
			rm -rf $dir/$APP"-kernel.out"
			for i in $(seq 1 $instances);
			do
				 cat $file | sed 's/\[[^]]*\]//g' | sed 's/ Curr /Curr /g' |  grep $text$i | tail -1 &>> $dir/$APP"-kernel.out"
			done
		fi
	done

}

EXTRACT_REDIS_BREAKDOWN_RESULT() {
        j=0
        files=""
	APP=$1
        rm $APP".data"
        APPFILE=""

	for device in "${devices[@]}"
        do
                TYPE=$device
                APPFILE=$APP".out-"$device

		for array in "${placearr[@]}"
		do

			for dir in $TARGET/$array"-"$device
			do
				exlude=0
				EXCLUDE_DIR $exlude $dir excluderedisbreakdown
				if [ $exlude -ge 1 ]; then
					echo "EXCLUDING" $dir
					continue;
				fi
				REDIS_CONSOLIDATE_RESULT $dir $APP
			done
		done
	done

        for device in "${devices[@]}"
        do
                TYPE=$device
                APPFILE=$APP".out-"$device

		for accesstype in "${redispattern[@]}"
		do
			for array in "${placearr[@]}"
			do
				for dir in $TARGET/$array"-"$device
				do
					exlude=0
					EXCLUDE_DIR $exlude $dir excluderedisbreakdown
					if [ $exlude -ge 1 ]; then
						echo "EXCLUDING" $dir
						continue;
					fi
					PULL_RESULT_PATTERN $APP $dir $j $APP"-all.out-"$TYPE $accesstype
				done
			done
			((j++))
		done
	done
}



EXTRACT_REDIS_PREFETCH_BREAKDOWN_RESULT() {
        j=0
        files=""
	APP=$1
        rm $APP".data"
        APPFILE=""

	for device in "${devices[@]}"
        do
                TYPE=$device
                APPFILE=$APP".out-"$device

		for array in "${mech_redis_prefetch[@]}"
		do
			for dir in $TARGET/$array"-"$device
			do
				exlude=0
				EXCLUDE_DIR $exlude $dir excludebreakdown
				if [ $exlude -ge 1 ]; then
					echo "EXCLUDING" $dir
					continue;
				fi

				REDIS_CONSOLIDATE_RESULT $dir $APP
			done
		done
	done

        for device in "${devices[@]}"
        do
                TYPE=$device
                APPFILE=$APP".out-"$device

		for accesstype in "${redispattern[@]}"
		do
			for array in "${mech_redis_prefetch[@]}"
			do
				for dir in $TARGET/$array"-"$device
				do
					exlude=0
					EXCLUDE_DIR $exlude $dir excludebreakdown
					if [ $exlude -ge 1 ]; then
						echo "EXCLUDING" $dir
						continue;
					fi
					echo "NOT EXCLUDING" $dir
					PULL_RESULT_PATTERN $APP $dir $j $APP"-all.out-"$TYPE $accesstype
				done
			done
			((j++))
		done
	done
}


EXTRACT_RESULT() {
	rm $APP".data"
	rm "num.data"
	exclude=0
	ZPLOTDATA=$2

	for device in "${devices[@]}"
	do
		TYPE=$device
		APPFILE=""

		for placement in "${placearr[@]}"
		do
			for dir in $TARGET/$placement-$device
			do
				exlude=0
				EXCLUDE_DIR $exlude $dir excludefullstat
				if [ $exlude -ge 1 ]; then
					echo "EXCLUDE_DIR" $dir
					continue;
				fi
				
				if [ "$APP" = 'redis' ]; then
					APPFILE=$APP"-all.out-"$TYPE
				else
					APPFILE=$APP".out-"$TYPE
				fi
				PULL_RESULT $APP $dir $j $APPFILE $ZPLOTDATA
			done
		done
	done
	j=$((j+$INCR_FULL_BAR_SPACE))
}


EXTRACT_RESULT_SENSITIVE_MOTIVATE() {
        rm $APP".data"
        rm "num.data"
        exclude=0

        for device in "${devices[@]}"
        do
                TYPE=$device
                APPFILE=""

                for BW in "${configarr[@]}"
                do
                        for placement in "${sensitive_arr[@]}"
                        do
                                for dir in $TARGET/$BW*/*$placement*$device
                                do
                                        exlude=0
                                        EXCLUDE_DIR $exlude $dir excludefullstat
                                        if [ $exlude -ge 1 ]; then
                                                echo "EXCLUDING" $dir
                                                continue;
                                        fi

                                        if [ "$APP" = 'redis' ]; then
                                                APPFILE=$APP"-all.out-"$TYPE
                                        else
                                                APPFILE=$APP".out-"$TYPE
                                        fi
                                        PULL_RESULT $APP $dir $j $APPFILE "motivate" "-"$BW
                                done
                        done
                        j=$((j+$INCR_ONE_SPACE))
                done
        done
}

EXTRACT_RESULT_SENSITIVE_CONTEXT() {
        rm $APP".data"
        rm "num.data"
        exclude=0

        for device in "${devices[@]}"
        do
                TYPE=$device
                APPFILE=""

                for BW in "${configarr[@]}"
                do
                        for placement in "${placearrcontextsensitivity[@]}"
                        do
                                for dir in $TARGET/$BW*/*$placement*$device
                                do
                                        exlude=0
                                        EXCLUDE_DIR $exlude $dir excludesensitivecontext
                                        if [ $exlude -ge 1 ]; then
                                                echo "EXCLUDING" $dir
                                                continue;
                                        fi

                                       if [ "$APP" = 'redis' ]; then
                                                APPFILE=$APP"-all.out-"$TYPE
                                        else
                                                APPFILE=$APP".out-"$TYPE
                                        fi
                                        PULL_RESULT $APP $dir $j $APPFILE "result-sensitivity" "-"$BW
                                done
                        done
                        j=$((j+$INCR_ONE_SPACE))
                done
        done
}

EXTRACT_RESULT_COMPARE() {
        rm $APP".data"
        rm "num.data"
        exclude=0

        for device in "${devices[@]}"
        do
                TYPE=$device
                APPFILE=""

                for BW in "${configarr[@]}"
                do
                        for placement in "${sensitive_arr[@]}"
                        do
                                for dir in $TARGET/$BW*/*$placement*$device
                                do
                                        exlude=0
                                        EXCLUDE_DIR $exlude $dir excludefullstat
                                        if [ $exlude -ge 1 ]; then
                                                echo "EXCLUDING" $dir
                                                continue;
                                        fi

                                        if [ "$APP" = 'redis' ]; then
						REDIS_CONSOLIDATE_RESULT $dir $APP
						APPFILE=$APP"-all.out-"$TYPE
                                        else
                                                APPFILE=$APP".out-"$TYPE
                                        fi
                                        PULL_RESULT $APP $dir $j $APPFILE "motivate" "-"$BW
                                done
                        done
                        j=$((j+$INCR_ONE_SPACE))
                done
        done
}

FORMAT_RESULT_REDIS() {
        files=""
	APP=$1
        rm $APP".data"
        APPFILE=""

	for device in "${devices[@]}"
        do
                TYPE=$device
                APPFILE=$APP".out-"$device

		for dir in $TARGET/*$TYPE*
		do
			REDIS_CONSOLIDATE_RESULT $dir $APP
		done
	done
}

####################MOTIVATION ANALYSIS########################a
M_ALL_STATS_APP() {

	j=0
	configarr=("${configarrbw[@]}")

	APP='rocksdb'
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/m-rocksdb_sensitivity"
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT_COMPARE "rocksdb"

	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/redis-sensitivity"
	APP='filebench'
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT_COMPARE "filebench"

	APP='redis'
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/redis-sensitivity"
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT_COMPARE "redis"

	APP='cassandra'
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/redis-sensitivity"
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT_COMPARE "cassandra"

	APP='spark-bench'
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/sparkbench-sensitivity"
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT_COMPARE "spark-bench"

	cd $ZPLOT
	python2.7 $NVMBASE/graphs/zplot/scripts/m-allapps-total.py
}

####################PAGESTAT STAT ################################
M_ALL_LIFE_STATS() {
	j=0
	j=$((j+1))
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/lifetime-stats"
	TARGET=$OUTPUTDIR

	APP='filebench'
	GETLIFESTAT $APP

	APP='redis'
	GETLIFESTAT $APP

	APP='rocksdb'
	GETLIFESTAT $APP

	#APP='spark-bench'
	#GETLIFESTAT $APP

	APP='cassandra'
	GETLIFESTAT $APP

	cd $ZPLOT
	python2.7 $NVMBASE/graphs/zplot/scripts/m-lifestat.py -o "m-all-lifestat" -a "rocksdb" -y 400 -r 50 -s "NVM"
}


####################PAGESTAT STAT ################################
M_ALL_PAGE_STATS() {
	j=0
	j=$((j+1))
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/page-stats"
	TARGET=$OUTPUTDIR

	APP='filebench'
	GETPAGESTAT $APP

	APP='redis'
	GETPAGESTAT $APP

	APP='rocksdb'
	GETPAGESTAT $APP

	APP='spark-bench'
	GETPAGESTAT $APP

	APP='cassandra'
	GETPAGESTAT $APP

	cd $ZPLOT
	python2.7 $NVMBASE/graphs/zplot/scripts/m-pagestat.py -o "e-all-pagestat" -a "rocksdb" -y 400 -r 50 -s "NVM"
}

####################PAGESTAT STAT ################################
M_ALL_KERN_STATS() {
	j=0
	j=$((j+1))
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/mem-stats/kernstat"
	TARGET=$OUTPUTDIR

	APP='filebench'
	GETSYSSTAT $APP

	APP='redis'
	GETSYSSTAT $APP

	APP='rocksdb'
	GETSYSSTAT $APP

	APP='spark-bench'
	GETSYSSTAT $APP

	APP='cassandra'
	GETSYSSTAT $APP

	cd $ZPLOT
	python2.7 $NVMBASE/graphs/zplot/scripts/m-sysstat.py -o "e-all-sysstat" -a "rocksdb" -y 400 -r 50 -s "NVM"
}

####################LLCSTAT STAT ################################
M_ALL_LLC_STATS() {
	j=0
	j=$((j+1))
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/llcstat"
	TARGET=$OUTPUTDIR

	APP='filebench'
	GETLLCSTAT $APP

	APP='redis'
	GETLLCSTAT $APP

	APP='rocksdb'
	GETLLCSTAT $APP

	APP='spark-bench'
	GETLLCSTAT $APP

	APP='cassandra'
	GETLLCSTAT $APP

	cd $ZPLOT
	python2.7 $NVMBASE/graphs/zplot/scripts/m-llcstat.py -o "m-all-llcstat" -a "rocksdb" -y 400 -r 50 -s "NVM"
}


E_ROCKSDB_KERNSTAT() {
	####################KERNEL STAT ################################
	j=0
	APP='rocksdb'
	OUTPUTDIR="/users/skannan/ssd/NVM/results/output-Aug11-allapps"
	TARGET=$OUTPUTDIR
	EXTRACT_KERNSTAT "rocksdb"
	cd $ZPLOT
	python2.7 $NVMBASE/graphs/zplot/scripts/e-rocksdb-kernstat.py -o "e-rocksdb-kernstat" -a "rocksdb" -y 400 -r 50 -s "NVM"
}


CONTEXT_SESITIVITY() {
	j=0
	configarr=("${configarrbwall[@]}")
	APP='rocksdb'
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/rocksdb-sensitivity-context"
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT_SENSITIVE_CONTEXT $APP

	j=$((j+$INCR_FULL_BAR_SPACE))

	APP='spark-bench'
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/spark-sensitivity-context"
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT_SENSITIVE_CONTEXT $APP

	cd $ZPLOT
	python $NVMBASE/graphs/zplot/scripts/e-rocksdb-sensitivity-BW.py "BW"
}

REDIS_BREAKDOWN() {
	#####################REDIS NETWORK##############################
	j=0
	APP='redis'
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/redis-results-Aug11"
	TARGET=$OUTPUTDIR
	EXTRACT_REDIS_BREAKDOWN_RESULT "redis"
	cd $ZPLOT
	python2.7 $NVMBASE/graphs/zplot/scripts/e-redis-breakdown.py
}

E_ALL_APPS() {
	####################MOTIVATION ANALYSIS########################
	excludefullstat=("${excludefullstat_noprefetch[@]}")
	j=0
	APP='rocksdb'
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
}

E_ALL_PREFETCH_APPS() {
	####################MOTIVATION ANALYSIS########################
	excludefullstat=("${excludefullstat_prefetch[@]}")
        placearr=("${placearrprefetch[@]}")
	j=0
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/prefetch-results"
	APP='rocksdb'
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT "filebench" "prefetch"

	APP='redis'
	#FORMAT_RESULT_REDIS "redis"
	#EXTRACT_RESULT "redis"

	APP='rocksdb'
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT "rocksdb" "prefetch"

	APP='cassandra'
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT "cassandra" "prefetch"

	APP='spark-bench'
	TARGET=$OUTPUTDIR
	EXTRACT_RESULT "spark-bench" "prefetch"

	cd $ZPLOT
	python2.7 $NVMBASE/graphs/zplot/scripts/e-prefetch-allapps-total.py
}




E_PREFETCH_ROCKSDB_APPS() {
	#######################ROCKSDB PREFETCH#########################
	j=0
	APP='rocksdb'
	OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/prefetch-results"
	TARGET=$OUTPUTDIR
	EXTRACT_BREAKDOWN_RESULT "rocksdb"
	cd $ZPLOT
	python2.7 $NVMBASE/graphs/zplot/scripts/e-rocksdb-breakdown.py
	exit
}


E_ALL_PREFETCH_APPS
exit

E_PREFETCH_ROCKSDB_APPS
exit

REDIS_BREAKDOWN
exit

E_ROCKSDB_KERNSTAT
exit

CONTEXT_SESITIVITY
exit

E_ALL_APPS
exit

M_ALL_LLC_STATS
exit
M_ALL_LIFE_STATS
exit
M_ALL_STATS_APP
exit
M_ALL_PAGE_STATS
M_ALL_KERN_STATS
REDIS_BREAKDOWN
exit




####################CAP STAT ################################
configarr=("${configarrbw[@]}") 

j=0
APP='rocksdb'
OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/rocksdb_sensitivity"
TARGET=$OUTPUTDIR
EXTRACT_RESULT_SENSITIVE_MOTIVATE "rocksdb"

j=$((j+$INCR_FULL_BAR_SPACE))
j=$((j+$INCR_FULL_BAR_SPACE))

APP='spark-bench'
OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/sparkbench-sensitivity"
TARGET=$OUTPUTDIR
EXTRACT_RESULT_SENSITIVE_MOTIVATE "spark-bench"

cd $ZPLOT
python2.7 $NVMBASE/graphs/zplot/scripts/m-rocksdb-sensitivity-BW.py "BW"


configarr=("${configarrcap[@]}")

j=0
APP='rocksdb'
OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/rocksdb_sensitivity"
TARGET=$OUTPUTDIR
EXTRACT_RESULT_SENSITIVE_MOTIVATE "rocksdb"

j=$((j+$INCR_FULL_BAR_SPACE))
j=$((j+$INCR_FULL_BAR_SPACE))

APP='spark-bench'
OUTPUTDIR="/proj/fsperfatscale-PG0/sudarsun/context/results/sparkbench-sensitivity"
TARGET=$OUTPUTDIR
EXTRACT_RESULT_SENSITIVE_MOTIVATE "spark-bench"

cd $ZPLOT
python2.7 $NVMBASE/graphs/zplot/scripts/m-rocksdb-sensitivity-BW.py "CAP"
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

EXTRACT_RESULT
cd $ZPLOT
python $NVMBASE/graphs/zplot/scripts/e-rocksdb-total.py
exit

