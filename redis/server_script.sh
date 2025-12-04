#!/bin/bash

pcpu=$1  # Number of instances (each bound to a different physical core)
x=0      # Start binding from core

for j in $(seq 1 ${pcpu}); do
    portp=$((16000 + j))  # Redis port

    # Determine NUMA node based on core number
    if [ "$x" -ge 0 ] && [ "$x" -le 288 ]; then
        node=0
    elif [ "$x" -ge 64 ] && [ "$x" -le 127 ]; then
        node=1
    elif [ "$x" -ge 128 ] && [ "$x" -le 191 ]; then
        node=2
    else
        echo "CPU core $x is out of supported range (0–143). Stopping..."
        break
    fi

    echo "Starting Redis on core $x (NUMA node $node) using port $portp"

    numactl --physcpubind=$x --membind=$node \
        redis-server --save "" --protected-mode no --port $portp --daemonize yes &

    let x+=1
done



