
#!/bin/bash

# Configuration
readonly INTERFACE="ens3np0"
readonly COMBINED_QUEUES=20
readonly SERVER_CORES=56
readonly TOTAL_CORES=223
readonly CORES_PER_SEGMENT=56

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Error handling
set -euo pipefail
trap 'log "Error occurred at line $LINENO"' ERR

# Function to run benchmark for a specific segment
run_segment_benchmark() {
    local segment=$1
    local start_core=$((segment * CORES_PER_SEGMENT))
    local end_core=$((start_core + CORES_PER_SEGMENT - 1))
    
    # Ensure end_core doesn't exceed total cores
    [[ $end_core -gt $TOTAL_CORES ]] && end_core=$TOTAL_CORES
    
    local test_name="Core_${start_core}-${end_core}_CCB${segment}_irq_combined_${COMBINED_QUEUES}_local_pipe_1_size_64"
    
    log "Starting benchmark for segment $segment (cores $start_core-$end_core)"
    
    # CPU management
    log "Managing CPU cores..."
    ./core_manage.sh offline 0 $TOTAL_CORES || { log "Failed to offline cores"; return 1; }
    ./core_manage.sh online $start_core $end_core || { log "Failed to online cores $start_core-$end_core"; return 1; }
    
    # Network configuration
    log "Configuring network interface..."
    ethtool -L $INTERFACE combined $COMBINED_QUEUES || { log "Failed to configure $INTERFACE"; return 1; }
    
    # Server setup
    log "Starting server..."
    ./server_script.sh $SERVER_CORES || { log "Failed to start server"; return 1; }
    
    # IRQ affinity
    log "Configuring IRQ affinity..."
    ./irq_dmr.sh $segment || { log "Failed to configure IRQ for segment $segment"; return 1; }
    
    # Run benchmark
    log "Running scaling benchmark..."
    ./scaling.sh ping "$test_name" $SERVER_CORES || { log "Failed to run benchmark $test_name"; return 1; }
    
    log "Completed benchmark for segment $segment"
}

# Main execution
log "Starting optimized benchmark run"

# Run benchmarks for all 4 segments
for segment in {0..3}; do
    run_segment_benchmark $segment
    log "Segment $segment completed successfully"
done

log "All benchmarks completed successfully"