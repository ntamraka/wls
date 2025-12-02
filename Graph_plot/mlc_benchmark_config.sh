#!/bin/bash

# ==============================================================================
# MLC (Memory Latency Checker) Benchmark Configuration
# ==============================================================================

# Benchmark script path
BENCHMARK_SCRIPT="./mlc_internal"

# Core list - cores to test
CORE_LIST=("1" "2" "4" "8")

# KPI extraction method: "regex", "grep", or "file"
EXTRACTION_METHOD="regex"

# For regex/grep method: pattern to extract KPI
# MLC outputs: "Inject  Delay:  1000  Bandwidth: 12345.67"
KPI_REGEX="Bandwidth:[[:space:]]*([0-9]+\\.?[0-9]*)"
KPI_FIELD="bandwidth"  # Field name in JSON output

# MLC command arguments (loaded latency test with sequential reads)
BENCHMARK_ARGS="--loaded_latency -d0 -T"

# Optional: Custom extraction function (leave empty to use default)
CUSTOM_EXTRACT_FUNCTION=""

# Note: mlc_internal requires sudo/root privileges
# Run agents with: sudo python3 remote_agent.py
