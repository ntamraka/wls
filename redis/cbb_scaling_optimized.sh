#!/bin/bash

# Simple Cross-NUMA Scaling Test - Optimized Version
set -e

# Configuration
INTERFACE="ens3np0"
TOTAL_CORES=223
IRQ_CPUS=14

# Test configurations: "segments cores queues description"  
TESTS=(
    "0 55 14 CBB0 1"
    "0 55 14 CBB0 16"
    "0,1 111 28 CBB1 1" 
    "0,1 111 28 CBB1 16" 
    "0,1,2 167 42 CBB2 1"
    "0,1,2 167 42 CBB2 16"
    "0,1,2,3 223 56 CBB3 1"
    "0,1,2,3 223 56 CBB3 16"

)

run_test() {
    local segments="$1" 
    local cores="$2"
    local queues="$3"
    local name="$4"
    local pipe="$5"
    
    # Convert comma-separated segments to space-separated for IRQ manager
    local irq_segments="${segments//,/ }"
    
    echo "Running $name test: cores 0-$cores, queues $queues, segments $segments"
    
    # CPU management
    ./core_manage.sh offline 0 $TOTAL_CORES
    ./core_manage.sh online 0 $cores
    
    # Network setup
    ethtool -L $INTERFACE combined $queues
    
    # Server and IRQ setup
    ./server_script.sh $((cores + 1))
    ./irq_dmr.sh "$irq_segments" $IRQ_CPUS
    
    # Run benchmark
    local test_name="cbb_scaling_Core_0-${cores}_${name}_irq_combined_${queues}_local_pipe_${pipe}_size_64"
    ./scaling.sh tls_medium "$test_name" $((cores + 1)) $pipe --emon
    
    echo "$name completed"
}

# Run all tests
for test in "${TESTS[@]}"; do
    read -r segments cores queues name pipe <<< "$test"
    run_test "$segments" "$cores" "$queues" "$name" "$pipe"
done

echo "All tests completed"