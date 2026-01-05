#!/bin/bash

#kernel=`uname -r`
#clocksource=`cat /sys/devices/system/clocksource/clocksource0/current_clocksource`
#scaling_gov=`cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor | head -n 1`


mlc_binary="./mlc_internal"

#echo "$kernel"
#echo "$clocksource"
#echo "$scaling_gov"

#cores=$(lscpu | awk '/Core\(s\) per socket:/{print $NF}')
cores=$1
last_core=$(($cores-1))
cpuset="0,2-$(($last_core))"
cpuset="0-$(($last_core))"
numanode=0
latency_core=1
duration=120
bw_mem="1g"
lat_mem="4g"


echo "#########################################################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -T -d0 -e -r -b$bw_mem -t${duration} -R 
sleep 120
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -T -d0 -e -r -b$bw_mem -t${duration} -W3 
sleep 120 
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -T -d0 -e -r -b$bw_mem -t${duration} -W2 
sleep 120
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -T -d0 -e -r -b$bw_mem -t${duration} -W5
sleep 120
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -T -d0 -e -r -b$bw_mem -t${duration} -W7 
sleep 120
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -T -d0 -e -r -b$bw_mem -t${duration} -W8 
sleep 120
echo "################################DONE#####################################"
echo ""
$mlc_binary --loaded_latency -k$cpuset -T -d0 -e -r -b$bw_mem -t${duration} -W6 
sleep 120
echo "################################DONE#####################################"
echo ""
$mlc_binary --idle_latency -b$lat_mem -t${duration} -c1 -j$numanode -e -r -l128
echo "################################DONE#####################################"
echo ""
