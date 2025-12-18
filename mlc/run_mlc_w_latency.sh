#!/bin/bash

#kernel=`uname -r`
#clocksource=`cat /sys/devices/system/clocksource/clocksource0/current_clocksource`
#scaling_gov=`cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | head -n 1`


mlc_binary="/home/tdx/TDX_perf_test/mlc/mlc_internal"

#echo "$kernel"
#echo "$clocksource"
#echo "$scaling_gov"
cores=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
last_core=$(($cores-1))
cpuset="0,2-$(($last_core))"
numanode=0
latency_core=1
duration=60
bw_mem="1g"
lat_mem="4g"


echo "#########################################################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b$bw_mem -t${duration} -R && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b$bw_mem -t${duration} -W3 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b$bw_mem -t${duration} -W2 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b$bw_mem -t${duration} -W5 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b$bw_mem -t${duration} -W7 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b$bw_mem -t${duration} -W8 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b$bw_mem -t${duration} -W6 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --idle_latency -b$lat_mem -t${duration} -c1 -j$numanode -e -r -l128
echo "################################DONE#####################################"
echo ""

