#!/bin/bash

pcpu=$1 # Number of Memtier instances (each bound to a different core)
x=0      # Start binding from core0
REDIS_SERVER="10.140.132.23"  # Redis server IP (assuming Redis is running locally)
LOG_DIR="./log_${1}"  # Directory to save log files

# Ensure the log directory exists
mkdir -p $LOG_DIR

# Loop through the number of instances (physical cores)
for j in $(seq 1 ${pcpu}); do
    portp=$((16000 + j))  # Calculate the port for each instance (16001, 16002, ...)

    # Run Memtier Benchmark on the specific core and port

    echo "taskset -c $x memtier_benchmark -s $REDIS_SERVER -p ${portp} \
        --threads=1 --clients=20 -n 1000000 --data-size=32 --ratio=1:0 \
        --out-file=${LOG_DIR}/log_${portp} &"

    taskset -c $x memtier_benchmark -s $REDIS_SERVER -p ${portp} \
        --threads=1 --clients=20 -n 1000000 --data-size=32 --ratio=1:0 \
        --out-file=${LOG_DIR}/log_${portp} &

    # Increment the core number for the next Memtier instance
    let x+=1
done
