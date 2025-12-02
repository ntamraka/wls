#!/bin/bash
# MLC Benchmark Configuration

# ==============================================================================
# BENCHMARK CONFIGURATION
# ==============================================================================

BENCHMARK_SCRIPT="./mlc_internal"
CORE_LIST=("2" "4" "8" "16" "32")
NUMA_NODE=0
SCRIPT_ARGS="--loaded_latency -T -d0 -e -r -b1g -t10 -R"

# ==============================================================================
# KPI EXTRACTION CONFIGURATION
# ==============================================================================

EXTRACTION_METHOD="grep"

# MLC output format: "00000       0.00   603228.8"
# Field 2 is latency, Field 3 is bandwidth
GREP_AWK_PATTERNS=(
    "latency:^[[:space:]]*[0-9]{5}:2"
    "bandwidth:^[[:space:]]*[0-9]{5}:3"
)

# ==============================================================================
# EXECUTION SETTINGS
# ==============================================================================

TEST_DELAY=1
TEST_TIMEOUT=60
USE_NUMACTL=true
NUMACTL_ARGS="--cpunodebind={NODE} --physcpubind={CORES}"

# ==============================================================================
# OUTPUT CONFIGURATION
# ==============================================================================

OUTPUT_FORMAT="json"

declare -A CUSTOM_FIELDS=(
    ["benchmark_type"]="mlc_memory"
    ["test_mode"]="loaded_latency"
)
