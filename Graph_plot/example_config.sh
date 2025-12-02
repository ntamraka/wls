#!/bin/bash
# Example configuration for a custom benchmark script

# ==============================================================================
# BENCHMARK CONFIGURATION
# ==============================================================================

BENCHMARK_SCRIPT="./my_custom_benchmark.sh"
CORE_LIST=("2" "4" "8" "16" "32")
NUMA_NODE=0
SCRIPT_ARGS="--threads {CORES} --duration 10"

# ==============================================================================
# KPI EXTRACTION CONFIGURATION
# ==============================================================================

# Example 1: Using regex to extract metrics from output like:
#   "Throughput: 1234.5 ops/sec"
#   "KPI: 12345"
EXTRACTION_METHOD="regex"

REGEX_PATTERNS=(
    "kpi:KPI:[[:space:]]*([0-9.]+)"
    "throughput:Throughput:[[:space:]]*([0-9.]+)"
)

# Example 2: Using grep + awk for structured output like:
#   "RESULT 12345 67.8"
# EXTRACTION_METHOD="grep"
# GREP_AWK_PATTERNS=(
#     "kpi:^RESULT:2"
#     "throughput:^RESULT:3"
# )

# ==============================================================================
# EXECUTION SETTINGS
# ==============================================================================

TEST_DELAY=2
TEST_TIMEOUT=120
USE_NUMACTL=true
NUMACTL_ARGS="--cpunodebind={NODE} --physcpubind={CORES}"

# ==============================================================================
# OUTPUT CONFIGURATION
# ==============================================================================

OUTPUT_FORMAT="json"

declare -A CUSTOM_FIELDS=(
    ["benchmark_type"]="custom_test"
    ["version"]="2.0"
)
