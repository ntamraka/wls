#!/bin/bash

#kernel=`uname -r`
#clocksource=`cat /sys/devices/system/clocksource/clocksource0/current_clocksource`
#scaling_gov=`cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | head -n 1`


mlc_binary="/home/tdx/TDX_perf_test/mlc/mlc_internal"

#echo "$kernel"
#echo "$clocksource"
#echo "$scaling_gov"

cpuset="0-6"
numanode=0
latency_core=7
duration=30

echo "#########################################################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b1g -t${duration} -R && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b1g -t${duration} -W3 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b1g -t${duration} -W2 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b1g -t${duration} -W5 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b1g -t${duration} -W7 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b1g -t${duration} -W8 && wait
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -c$latency_core -j$numanode -d0 -e -r -b1g -t${duration} -W6 && wait
echo "################################DONE#####################################"
echo ""
#$mlc_binary --idle_latency -b700000 -t10 -c0 -j$numanode -e -r -l128
$mlc_binary --idle_latency -b4g -t${duration} -c0 -j$numanode -e -r -l128
echo "################################DONE#####################################"
echo ""
