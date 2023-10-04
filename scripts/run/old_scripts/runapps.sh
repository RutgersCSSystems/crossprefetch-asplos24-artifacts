#!/bin/bash
set -x

RUNNOW=1
RUNSCRIPT=runexp_variation_sudarsun.sh
mkdir $OUTPUTDIR
sudo dmesg -c &> del.txt

USAGE(){
  echo "echo some content on how run"
}

RUNAPP(){

  echo "$APP NOW RUNNING"
  cd $APPBASE
  $APPBASE/$RUNSCRIPT $RUNNOW #$OUTPUTDIR/$APP &> $OUTPUTDIR/$APP
  #echo "******************"  &>> $OUTPUTDIR/$APP
  #echo "KERNEL  DMESG"  &>> $OUTPUTDIR/$APP
  #echo "******************"  &>> $OUTPUTDIR/$APP 	
  #echo "  "  &>> $OUTPUTDIR/$APP
  #sudo dmesg -c &>> $OUTPUTDIR/$APP
  #echo 1 > $FLAGPATH
}


intexit() {
    # Kill all subprocesses (all processes in the current process group)
    kill -HUP -$$
}

hupexit() {
    # HUP'd (probably by intexit)
    echo
    echo "Interrupted"
    exit
}

trap hupexit HUP
trap intexit INT

if [ -z "$1" ]  then	
  USAGE 
  exit
fi

if [ -z "$4" ]
  then
        APPBASE=$APPBENCH/apps/ior/benchmarks
        APP=ior
        RUNAPP

	APPBASE=$APPBENCH/apps/strided_MADbench
	APP=MADbench2_io
	echo "running $APP..."
	RUNAPP
	$NVMBASE/scripts/reset.sh
fi
	#APPBASE=$APPBENCH/apps/fio
	#APP=fio
	#echo "running $APP ..."
	#RUNAPP

	#APPBASE=$APPBENCH/graphchi
	#APP=graphchi
	#RUNAPP
	# We need data files
	#$SCRIPTS/createdata.sh
	#rm $SHARED_DATA/com-orkut.ungraph.txt.*

	#RUNSCRIPT="runfcreate.sh"
        #APP=fcreate
        #RUNAPP
        #RUNSCRIPT=run.sh

	#APPBASE=$APPBENCH/apps/mongo-perf
	#APP=mongodb
	#RUNAPP


	#APPBASE=$APPBENCH/xstream_release
	#APP=xstream_release
	#scp -r $HOSTIP:$SHARED_DATA*.ini $APPBASE
        #cp $APPBASE/*.ini $SHARED_DATA
	#RUNAPP
#currentDate=`date +"%D %T"`
set +x
