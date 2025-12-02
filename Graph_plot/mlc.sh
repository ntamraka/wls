#!/bin/bash
set -e  # Exit on error

NODE=0
CORE_LIST=("2" "4" "8" "16" "32")
MLC_BIN="./mlc_internal"
MLC_ARGS="--loaded_latency -T -d0 -e -r -b1g -t10 -R"

# Get machine identifier (hostname or IP)
MACHINE_ID="${1:-$(hostname)}"

# Validation checks
if [ ! -f "$MLC_BIN" ]; then
    echo "{\"error\": \"MLC binary not found: $MLC_BIN\"}" >&2
    exit 1
fi

if [ ! -x "$MLC_BIN" ]; then
    echo "{\"error\": \"MLC binary not executable: $MLC_BIN\"}" >&2
    exit 1
fi

if ! command -v numactl &> /dev/null; then
    echo "{\"error\": \"numactl command not found\"}" >&2
    exit 1
fi

echo "===== MLC NUMA Scaling Test =====" >&2

for CORES in "${CORE_LIST[@]}"
do
    echo ">>> Running MLC with $CORES cores" >&2
    
    CORE_MASK=""
    for ((i=0; i<$CORES; i++)); do
        if [ $i -eq 0 ]; then CORE_MASK="$i"
        else CORE_MASK="$CORE_MASK,$i"
        fi
    done

    # Run MLC and capture output
    # Start CPU monitoring in background
    CPU_START=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
    
    RESULT=$(numactl --cpunodebind=$NODE --physcpubind=$CORE_MASK \
        $MLC_BIN $MLC_ARGS 2>&1 | grep -E "^[[:space:]]*[0-9]{5}" | head -n 1)
    
    # Get CPU utilization after test
    CPU_END=$(grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}')
    CPU_UTIL=$(echo "scale=2; ($CPU_END + $CPU_START) / 2" | bc)

    if [ -z "$RESULT" ]; then
        echo "WARNING: No result for $CORES cores" >&2
        echo "{\"cores\": $CORES, \"latency\": 0, \"bandwidth\": 0, \"cpu_util\": 0, \"error\": \"no data\"}"
        continue
    fi

    echo "RAW RESULT: $RESULT" >&2

    LATENCY=$(echo "$RESULT" | awk '{print $2}')
    BANDWIDTH=$(echo "$RESULT" | awk '{print $3}')

    # Validate numeric values
    if ! [[ "$LATENCY" =~ ^[0-9]+\.?[0-9]*$ ]] || ! [[ "$BANDWIDTH" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        echo "WARNING: Invalid numeric values - lat=$LATENCY bw=$BANDWIDTH" >&2
        echo "{\"cores\": $CORES, \"latency\": 0, \"bandwidth\": 0, \"cpu_util\": 0, \"error\": \"invalid data\"}"
        continue
    fi

    # Emit JSON with CPU utilization
    echo "{\"machine\": \"$MACHINE_ID\", \"cores\": $CORES, \"latency\": $LATENCY, \"bandwidth\": $BANDWIDTH, \"cpu_util\": $CPU_UTIL}"
    
    # Small delay between tests
    sleep 1
done

echo "===== Test Complete =====" >&2

