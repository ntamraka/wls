#!/bin/bash
set -e  # Exit on error

# ==============================================================================
# Generic Benchmark Runner
# Runs any benchmark script with configurable core counts and KPI extraction
# ==============================================================================

# Load configuration
CONFIG_FILE="${1:-benchmark_config.sh}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE" >&2
    echo "Usage: $0 [config_file] [machine_id]" >&2
    exit 1
fi

source "$CONFIG_FILE"

# Get machine identifier
MACHINE_ID="${2:-$(hostname)}"

# ==============================================================================
# KPI EXTRACTION FUNCTIONS
# ==============================================================================

extract_with_regex() {
    local output="$1"
    local kpi_name="$2"
    local pattern="$3"
    
    # Extract value using regex
    if [[ "$output" =~ $pattern ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "0"
    fi
}

extract_with_grep_awk() {
    local output="$1"
    local grep_pattern="$2"
    local awk_field="$3"
    
    # Extract value using grep and awk
    local result=$(echo "$output" | grep -E "$grep_pattern" | head -n 1 | awk "{print \$$awk_field}")
    echo "${result:-0}"
}

extract_kpis() {
    local output="$1"
    local cores="$2"
    
    declare -A kpis
    kpis["cores"]=$cores
    kpis["machine"]="$MACHINE_ID"
    
    if [ "$EXTRACTION_METHOD" == "regex" ]; then
        for pattern_def in "${REGEX_PATTERNS[@]}"; do
            IFS=':' read -r kpi_name pattern <<< "$pattern_def"
            value=$(extract_with_regex "$output" "$kpi_name" "$pattern")
            kpis["$kpi_name"]=$value
        done
        
    elif [ "$EXTRACTION_METHOD" == "grep" ] || [ "$EXTRACTION_METHOD" == "awk" ]; then
        for pattern_def in "${GREP_AWK_PATTERNS[@]}"; do
            IFS=':' read -r kpi_name grep_pattern awk_field <<< "$pattern_def"
            value=$(extract_with_grep_awk "$output" "$grep_pattern" "$awk_field")
            kpis["$kpi_name"]=$value
        done
        
    elif [ "$EXTRACTION_METHOD" == "json" ]; then
        # For JSON, just pass through if output is already JSON
        if echo "$output" | jq empty 2>/dev/null; then
            echo "$output"
            return
        fi
    fi
    
    # Add custom fields
    for key in "${!CUSTOM_FIELDS[@]}"; do
        kpis["$key"]="${CUSTOM_FIELDS[$key]}"
    done
    
    # Output as JSON
    output_json "${kpis[@]}"
}

output_json() {
    local -n kpi_map=$1
    local json="{"
    local first=true
    
    for key in "${!kpi_map[@]}"; do
        if [ "$first" = true ]; then
            first=false
        else
            json+=", "
        fi
        
        # Check if value is numeric
        if [[ "${kpi_map[$key]}" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            json+="\"$key\": ${kpi_map[$key]}"
        else
            json+="\"$key\": \"${kpi_map[$key]}\""
        fi
    done
    
    json+="}"
    echo "$json"
}

# ==============================================================================
# CPU UTILIZATION MONITORING
# ==============================================================================

get_cpu_util() {
    grep 'cpu ' /proc/stat | awk '{usage=($2+$4)*100/($2+$4+$5)} END {print usage}'
}

# ==============================================================================
# CORE MASK GENERATION
# ==============================================================================

generate_core_mask() {
    local num_cores=$1
    local mask=""
    
    for ((i=0; i<$num_cores; i++)); do
        if [ $i -eq 0 ]; then
            mask="$i"
        else
            mask="$mask,$i"
        fi
    done
    
    echo "$mask"
}

# ==============================================================================
# VALIDATION
# ==============================================================================

validate_setup() {
    if [ ! -x "$BENCHMARK_SCRIPT" ]; then
        echo "ERROR: Benchmark script not found or not executable: $BENCHMARK_SCRIPT" >&2
        return 1
    fi
    
    if [ "$USE_NUMACTL" = true ] && ! command -v numactl &> /dev/null; then
        echo "WARNING: numactl not found but USE_NUMACTL=true" >&2
        USE_NUMACTL=false
    fi
    
    return 0
}

# ==============================================================================
# BENCHMARK EXECUTION
# ==============================================================================

run_benchmark() {
    local cores=$1
    local core_mask=$(generate_core_mask $cores)
    
    echo ">>> Running benchmark with $cores cores" >&2
    
    # Prepare script arguments
    local args="$SCRIPT_ARGS"
    args="${args//\{CORES\}/$cores}"
    args="${args//\{MACHINE\}/$MACHINE_ID}"
    
    # Prepare numactl command
    local numa_cmd=""
    if [ "$USE_NUMACTL" = true ]; then
        numa_cmd="numactl $NUMACTL_ARGS"
        numa_cmd="${numa_cmd//\{NODE\}/$NUMA_NODE}"
        numa_cmd="${numa_cmd//\{CORES\}/$core_mask}"
    fi
    
    # Get CPU utilization before
    local cpu_start=$(get_cpu_util)
    
    # Run the benchmark
    local output
    local exit_code
    
    if [ $TEST_TIMEOUT -gt 0 ]; then
        output=$(timeout $TEST_TIMEOUT $numa_cmd $BENCHMARK_SCRIPT $args 2>&1) || exit_code=$?
    else
        output=$($numa_cmd $BENCHMARK_SCRIPT $args 2>&1) || exit_code=$?
    fi
    
    # Get CPU utilization after
    local cpu_end=$(get_cpu_util)
    local cpu_util=$(echo "scale=2; ($cpu_end + $cpu_start) / 2" | bc 2>/dev/null || echo "0")
    
    if [ ! -z "$exit_code" ] && [ $exit_code -ne 0 ]; then
        echo "WARNING: Benchmark exited with code $exit_code" >&2
        echo "{\"machine\": \"$MACHINE_ID\", \"cores\": $cores, \"error\": \"exit_code_$exit_code\", \"cpu_util\": $cpu_util}"
        return
    fi
    
    echo "RAW OUTPUT:" >&2
    echo "$output" >&2
    
    # Extract KPIs
    local kpi_json=$(extract_kpis "$output" "$cores")
    
    # Add CPU utilization if not already present
    if ! echo "$kpi_json" | grep -q '"cpu_util"'; then
        kpi_json=$(echo "$kpi_json" | sed "s/}/, \"cpu_util\": $cpu_util}/")
    fi
    
    echo "$kpi_json"
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    echo "===== Generic Benchmark Runner =====" >&2
    echo "Config: $CONFIG_FILE" >&2
    echo "Machine: $MACHINE_ID" >&2
    echo "Script: $BENCHMARK_SCRIPT" >&2
    echo "Cores: ${CORE_LIST[*]}" >&2
    echo "===================================" >&2
    
    # Validate setup
    if ! validate_setup; then
        exit 1
    fi
    
    # Run benchmarks for each core configuration
    for cores in "${CORE_LIST[@]}"; do
        run_benchmark "$cores"
        
        # Delay between tests
        if [ $TEST_DELAY -gt 0 ]; then
            sleep $TEST_DELAY
        fi
    done
    
    echo "===== Benchmark Complete =====" >&2
}

# Run main function
main
