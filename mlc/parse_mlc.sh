#!/bin/bash

mlc_log_file=$1

echo ""

echo "################### MLC SUMMARY #######################"
echo ""

val=`grep -i -A 5 "idle_latency" $mlc_log_file | tail -n 3 | head -n 1 | awk '{print $9}'`
echo "idle latency (ns):                                    $val"

val=`grep -i -A 4 " Read-only traffic type" $mlc_log_file | tail -n 1 | awk '{print $3}'`
echo "read-only traffic bandwidth (MB/s):                   $val"

val=`grep -i -A 9 "W3" $mlc_log_file | tail -n 1 | awk '{print $3}'`
echo "3:1 read-write ratio bandwidth (MB/s):                $val"

val=`grep -i -A 9 "W2" $mlc_log_file | tail -n 1 | awk '{print $3}'`
echo "2:1 read-write ratio bandwidth (MB/s):                $val"

val=`grep -i -A 9 "W5" $mlc_log_file | tail -n 1 | awk '{print $3}'`
echo "1:1 read-write ratio bandwidth (MB/s):                $val"

val=`grep -i -A 9 "W7" $mlc_log_file | tail -n 1 | awk '{print $3}'`
echo "2:1 read-Non Temporal Write ratio bandwidth (MB/s):   $val"

val=`grep -i -A 9 "W8" $mlc_log_file | tail -n 1 | awk '{print $3}'`
echo "1:1 read-Non Temporal Write ratio bandwidth (MB/s):   $val"

val=`grep -i -A 9 "W6" $mlc_log_file | tail -n 1 | awk '{print $3}'`
echo "0:1 read-Non Temporal Write ratio bandwidth (MB/s):   $val"




