set -x

VTUNECL=~/ssd/vtune/vtune_amplifier_xe_2017/bin64/amplxe-cl
APPDIR=/users/kannan11/ssd/schedsp/NVM/linux-scalability-benchmark/fio
APP=fio
WORKLOAD=$PWD/fio-rand-RW_dup.job
OUTPUT=fio_randrw

sudo rm -rf r000*
sudo rm -rf fio_randrw
#sudo $VTUNE -collect general-exploration -result-dir=$OUTPUT -- $APPDIR/$APP $WORKLOAD &> $OUTPUT.out
#sudo $VTUNE -report-output $OUTPUT.txt -report hw-events -result-dir=$OUTPUT -- $APPDIR/$APP $WORKLOAD
#sudo $VTUNE -R hw-events -report-output $OUTPUT.csv -format csv -csv-delimiter comma -result-dir=$OUTPUT

COUNTERS="INST_RETIRED.ANY_P,CYCLE_ACTIVITY.STALLS_LDM_PENDING,DTLB_LOAD_MISSES.WALK_DURATION"
sudo $VTUNECL -collect-with runsa -knob event-config=$COUNTERS -- $APPDIR/$APP $WORKLOAD &> $OUTPUT.out
sudo mv r000* fio_randrw
sudo $VTUNECL -report-output $OUTPUT.txt -report hw-events -result-dir=$OUTPUT -- $APPDIR/$APP $WORKLOAD
sudo $VTUNECL -R hw-events -report-output $OUTPUT.csv -format csv -csv-delimiter comma -result-dir=$OUTPUT

