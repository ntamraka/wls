#!/bin/bash
# Simple benchmark runner - reads config and runs tests

CONFIG_FILE="${1:-ali_benchmark_config.sh}"
MACHINE_ID="${2:-$(hostname)}"

# Load config
source "$CONFIG_FILE"

# Run each test
for cores in "${CORE_LIST[@]}"; do
    echo ">>> Testing with $cores VMs" >&2
    
    # Cleanup
    eval "$PRE_EXEC_COMMAND" 2>&1 >&2
    
    # Replace {CORES} in args
    args="${SCRIPT_ARGS//\{CORES\}/$cores}"
    
    # Run benchmark
    $BENCHMARK_SCRIPT $args 2>&1 >&2
    
    # Read KPI from file
    kpi_file="${KPI_FILE//\{CORES\}/$cores}"
    if [ -f "$kpi_file" ]; then
        kpi_value=$(cat "$kpi_file" | tr -d '\n\r')
    else
        kpi_value=0
    fi
    
    # Output JSON
    echo "{\"machine\": \"$MACHINE_ID\", \"cores\": $cores, \"$FILE_KPI_NAME\": $kpi_value}"
    
    # Delay
    sleep $TEST_DELAY
done
