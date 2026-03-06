#!/bin/bash

# Simple Cross-NUMA Scaling Test - Optimized Version
set -e

# Configuration
INTERFACE="ens3np0"
TOTAL_CORES=223
IRQ_CPUS=16

# Test configurations: "segments cores queues description"  
TESTS=(
    "0 55 16 CBB0"
    "0,1 111 32 CBB1" 
    "0,1,2 167 48 CBB2"
    "0,1,2,3 223 64 CBB3"
)

run_test() {
    local segments="$1" 
    local cores="$2"
    local queues="$3"
    local name="$4"
    
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
    ./irq_affinity_manager.sh "$irq_segments" $IRQ_CPUS
    
    # Run benchmark
    local test_name="cbb_scaling_Core_0-${cores}_${name}_irq_combined_${queues}_local_pipe_1_size_64"
    ./scaling.sh ping "$test_name" $((cores + 1))
    
    echo "$name completed"
}

# Run all tests
for test in "${TESTS[@]}"; do
    read -r segments cores queues name <<< "$test"
    run_test "$segments" "$cores" "$queues" "$name"
done

echo "All tests completed"