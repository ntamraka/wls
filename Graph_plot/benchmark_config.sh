#!/bin/bash
# Generic Benchmark Configuration File
# This file defines how to run benchmarks and extract metrics

# ==============================================================================
# BENCHMARK CONFIGURATION
# ==============================================================================

# Benchmark script to execute (must be executable)
BENCHMARK_SCRIPT="./mlc.sh"

# Core configurations to test
CORE_LIST=("2" "4" "8" "16" "32")

# NUMA node to bind to (0 for first node, -1 to disable NUMA binding)
NUMA_NODE=0

# Script arguments (use {CORES} as placeholder for core count, {MACHINE} for machine ID)
SCRIPT_ARGS="{MACHINE}"

# Additional environment variables (optional)
# export MY_VAR="value"

# ==============================================================================
# KPI EXTRACTION CONFIGURATION
# ==============================================================================

# Method: "regex", "grep", "awk", or "json"
EXTRACTION_METHOD="regex"

# For regex method: Extract values using regex patterns
# Format: "kpi_name:pattern" - use capture group () for the value
REGEX_PATTERNS=(
    "bandwidth:bandwidth[=:[:space:]]+([0-9.]+)"
    "latency:latency[=:[:space:]]+([0-9.]+)"
    "throughput:throughput[=:[:space:]]+([0-9.]+)"
)

# For grep+awk method: Extract values using grep pattern and awk field
# Format: "kpi_name:grep_pattern:awk_field"
GREP_AWK_PATTERNS=(
    "bandwidth:^[[:space:]]*[0-9]{5}:3"
    "latency:^[[:space:]]*[0-9]{5}:2"
)

# For json method: JSON keys to extract
JSON_KEYS=("bandwidth" "latency" "cpu_util")

# ==============================================================================
# EXECUTION SETTINGS
# ==============================================================================

# Delay between tests (seconds)
TEST_DELAY=1

# Timeout for each test (seconds, 0 = no timeout)
TEST_TIMEOUT=300

# Run with numactl (true/false)
USE_NUMACTL=true

# Custom numactl arguments (if USE_NUMACTL=true)
# Use {NODE} and {CORES} as placeholders
NUMACTL_ARGS="--cpunodebind={NODE} --physcpubind={CORES}"

# ==============================================================================
# OUTPUT CONFIGURATION
# ==============================================================================

# Output format: "json" or "csv"
OUTPUT_FORMAT="json"

# Additional custom fields to include in output (static values)
declare -A CUSTOM_FIELDS=(
    ["test_type"]="memory_benchmark"
    ["version"]="1.0"
)
