
    #!/bin/bash

    pcpu=$1
    x=0
    y=144
    REDIS_SERVER="192.168.200.1"
    LOG_DIR="/root/memtier_benchmark/log_${1}"

    # Cleanup previous runs
    rm -rf "$LOG_DIR"
    mkdir -p "$LOG_DIR"
    killall -9 memtier_benchmark 2>/dev/null

    # Array to store PIDs
    declare -a pids

    for j in $(seq 1 6 ${pcpu}); do
        portp=$(($4 + j))
        

        taskset -c $x memtier_benchmark             -s $REDIS_SERVER -p ${portp}             --threads=1 --test-time 100 --pipeline=$3             --hide-histogram --command='ping'             --clients=100 --data-size=64              --out-file=${LOG_DIR}/log_${portp} &
        
        pids[$x]=$!  # Store PID
        let x+=1
        let y+=1
    done

    # Wait for all processes to complete
    for pid in ${pids[*]}; do
        wait $pid
    done

    echo "Benchmark completed. Results in $LOG_DIR"
    