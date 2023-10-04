set -x

VTUNECL=/users/kannan11/ssd/vtune/vtune_amplifier_2018/bin64/amplxe-cl
APPDIR=/users/kannan11/ssd/schedsp/NVM/leveldb/out-static
APP=db_bench
WORKLOAD="--value_size=4096 --num=100000 --benchmarks=fillrandom,readrandom"
OUTPUT=vtune_leveldb
RESULT=vtune_leveldb_analysis

mkdir $RESULT

sudo rm -rf r000*
sudo rm -rf $OUTPUT
#sudo $VTUNE -collect general-exploration -result-dir=$OUTPUT -- $APPDIR/$APP $WORKLOAD &> $OUTPUT.out
#sudo $VTUNE -report-output $OUTPUT.txt -report hw-events -result-dir=$OUTPUT -- $APPDIR/$APP $WORKLOAD
#sudo $VTUNE -R hw-events -report-output $OUTPUT.csv -format csv -csv-delimiter comma -result-dir=$OUTPUT

sudo export TMP_TESTDIR="/users/kannan11/ssd/leveldbout"
sudo export TEST_TMPDIR="/users/kannan11/ssd/leveldbout"
mkdir $TMP_TESTDIR

COUNTERS="INST_RETIRED.ANY_P,CYCLE_ACTIVITY.STALLS_LDM_PENDING,DTLB_LOAD_MISSES.WALK_DURATION"
#sudo $VTUNECL -collect-with runsa -knob event-config=$COUNTERS -- $APPDIR/$APP $WORKLOAD &> $OUTPUT.out
#sudo mv r000* $OUTPUT
#sudo $VTUNECL -report-output $OUTPUT.txt -report hw-events -result-dir=$OUTPUT -- $APPDIR/$APP $WORKLOAD
#sudo $VTUNECL -R hw-events -report-output $OUTPUT.csv -format csv -csv-delimiter tab -result-dir=$OUTPUT

sudo $VTUNECL -collect advanced-hotspots -knob enable-stack-collection=false -- $APPDIR/$APP $WORKLOAD &> $OUTPUT.out
#sudo $VTUNECL -report top-down -result-dir=$OUTPUT -column=time:total -- $APPDIR/$APP $WORKLOAD &> $OUTPUT.out
cat $OUTPUT.csv | grep "vmlinux" &> $OUTPUT_kernel.out


mkdir
mv $OUTPUT.csv $RESULT
mv $OUTPUT_kernel.out $RESULT 
mv $OUTPUT.out  $RESULT
