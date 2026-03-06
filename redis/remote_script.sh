#!/bin/bash

pcpu=$1
x=0
REDIS_SERVER="10.140.129.84"
LOG_DIR="/root/wls/redis/memtier_benchmark/log_${1}"

# Cleanup previous runs
rm -rf "$LOG_DIR"
mkdir -p "$LOG_DIR"
killall -9 memtier_benchmark 2>/dev/null

# Array to store PIDs
declare -a pids

for j in $(seq 1 4 ${pcpu}); do
    portp=$(($4 + j))
    
    taskset -c $x memtier_benchmark \
        -s $REDIS_SERVER -p ${portp} \
        --threads=10 --test-time 100 --pipeline=$3 \
        --clients=20 \
        --data-size-list=100:30,200:40,500:10,1000:10,10000:10 \
        --key-maximum=800000\
        --ratio=3:7 \
        --distinct-client-seed \
        --out-file=${LOG_DIR}/log_${portp} &

    pids[$x]=$!
    let x+=1
done

# Wait for all processes to complete
for pid in ${pids[*]}; do
    wait $pid
done

echo "Benchmark completed. Results in $LOG_DIR"
