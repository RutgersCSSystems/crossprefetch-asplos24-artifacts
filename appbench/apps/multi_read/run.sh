#!/bin/bash

#APP=./bin/read_shared_seq
#APPNAME="shared_seq"

set -x
APP=./bin/read_pvt_seq
APPNAME="pvt_seq"

CACHE_STAT=$NVMBASE/scripts/helperscripts/cache-stat.sh

FlushDisk()
{
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sudo sh -c "echo 3 > /proc/sys/vm/drop_caches"
        sudo sh -c "sync"
        sleep 5
        sudo dmesg --clear
}

ENABLE_LOCK_STATS()
{
        sudo sh -c "echo 0 > /proc/lock_stat"
        sudo sh -c "echo 1 > /proc/sys/kernel/lock_stat"
}

DISABLE_LOCK_STATS()
{
        sudo sh -c "echo 0 > /proc/sys/kernel/lock_stat"
}


MMAP_RUN()
{
        FlushDisk
        #clear_os_stats
        #ENABLE_LOCK_STATS
        #export LD_PRELOAD="/usr/lib/lib_CII.so"
        #export LD_PRELOAD="/usr/lib/lib_VRA.so"
        #export LD_PRELOAD="/usr/lib/lib_CII_sync.so"
        #export LD_PRELOAD="/usr/lib/lib_Cross_Info_sync.so"
        #export LD_PRELOAD="/usr/lib/lib_Cross_Info.so"
        #export LD_PRELOAD="/usr/lib/lib_CIP.so"

        #$CACHE_STAT OSONLY_${APPNAME}_cachestat &

        #export LD_PRELOAD="/usr/lib/lib_OSonly.so"
        #export LD_PRELOAD="/usr/lib/lib_CICP.so"
        #export LD_PRELOAD="/usr/lib/lib_CIPI.so"
        #$APP &> OSONLY_$APPNAME
        #./bin/read_shared_mmap_seq

        #LD_PRELOAD=/usr/lib/lib_CIPI_mmap.so ./bin/read_shared_mmap_seq
        #LD_PRELOAD=/usr/lib/lib_Vanilla.so ./bin/read_shared_mmap_seq
        #FlushDisk


        LD_PRELOAD=/usr/lib/lib_OSonly.so ./bin/read_shared_mmap_seq
        #FlushDisk

        #LD_PRELOAD=/usr/lib/lib_CIPI_mmap.so ./bin/read_shared_mmap_seq
        #LD_PRELOAD=/usr/lib/lib_CIPI_mmap.so ./bin/read_shared_mmap_seq
        #./bin/read_shared_mmap_rand
        #export LD_PRELOAD=""

}

OSONLY_RUN()
{
        FlushDisk
        clear_os_stats
        ENABLE_LOCK_STATS
        #export LD_PRELOAD="/usr/lib/lib_CII.so"
        #export LD_PRELOAD="/usr/lib/lib_VRA.so"
        #export LD_PRELOAD="/usr/lib/lib_CII_sync.so"
        #export LD_PRELOAD="/usr/lib/lib_Cross_Info_sync.so"
        #export LD_PRELOAD="/usr/lib/lib_Cross_Info.so"
        #export LD_PRELOAD="/usr/lib/lib_CIP.so"

        #$CACHE_STAT OSONLY_${APPNAME}_cachestat &

        #export LD_PRELOAD="/usr/lib/lib_OSonly.so"
        #export LD_PRELOAD="/usr/lib/lib_CICP.so"
        #export LD_PRELOAD="/usr/lib/lib_CIPI.so"
        #$APP &> OSONLY_$APPNAME
        ./bin/read_pvt_seq_vanilla_opt
        export LD_PRELOAD=""

        #kill $(ps -s $$ -o pid=)

        DISABLE_LOCK_STATS
        dmesg &>> OSONLY_$APPNAME
        sudo cat /proc/lock_stat &>> OSONLY_$APPNAMEt
}

CROSS_INFO_RUN()
{
        FlushDisk
        clear_os_stats

        ENABLE_LOCK_STATS
        #export LD_PRELOAD="/usr/lib/lib_OSonly.so"
        echo "CrossInfo"
        export LD_PRELOAD="/usr/lib/lib_Cross_Info.so"
        ${APP} &> CROSS_INFO_$APPNAME
        export LD_PRELOAD=""
        DISABLE_LOCK_STATS
        dmesg
        sudo cat /proc/lock_stat
}

MINCORE_RUN()
{
        FlushDisk
        clear_os_stats

        ENABLE_LOCK_STATS
        echo "MINCORE"
        export LD_PRELOAD=""
        #${APP}_mincore &> MINCORE_$APPNAME
        ${APP}_mincore
        DISABLE_LOCK_STATS
        dmesg
        sudo cat /proc/lock_stat
}

CROSS_PREFETCH_RUN()
{
        FlushDisk
        clear_os_stats
        ENABLE_LOCK_STATS
        #export LD_PRELOAD="/usr/lib/lib_OSonly.so"
        echo "Cross Predict"
        export LD_PRELOAD="/usr/lib/lib_CIP.so"
        ${APP}
        export LD_PRELOAD=""
        DISABLE_LOCK_STATS

        dmesg
        sudo cat /proc/lock_stat
}


MMAP_RUN
#sudo ./utils/perf-tools/bin/cachestat
#OSONLY_RUN
#MINCORE_RUN
#CROSS_INFO_RUN
#CROSS_INFO_RUN
#exit
#CROSS_PREFETCH_RUN
