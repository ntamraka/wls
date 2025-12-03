#!/bin/bash
# ALI Workload Benchmark Configuration

# ==============================================================================
# BENCHMARK CONFIGURATION
# ==============================================================================

# Benchmark script to execute (must be executable)
BENCHMARK_SCRIPT="/home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/start_ali_clients.sh"

# Core/VM configurations to test (1 to 18 VMs)
CORE_LIST=( "10" "11" "12" "13" "14" "15" "16" "17" "18")
#CORE_LIST=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18")
# NUMA node to bind to (-1 to disable NUMA binding for this workload)
NUMA_NODE=-1

# Script arguments
# start_ali_clients.sh takes: <num_vms> <test_name> <duration>
# {CORES} will be replaced with the core count
SCRIPT_ARGS="{CORES} SRF_C0288c_{CORES} 1"

# ==============================================================================
# PRE/POST EXECUTION COMMANDS
# ==============================================================================

# Clean up before each test
PRE_EXEC_COMMAND="cd /home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali && rm -rf results/SRF_*"

# No post-exec needed
POST_EXEC_COMMAND=""

# ==============================================================================
# KPI EXTRACTION CONFIGURATION
# ==============================================================================

# Method: "file" for reading from output file
EXTRACTION_METHOD="file"

# File to read KPI from (use {CORES} placeholder)
# Path is relative to the benchmark script directory
KPI_FILE="/home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/results/SRF_C0288c_{CORES}/data_wrk_{CORES}.out.csv"

# For file method: read entire file content as KPI value
# The CSV file contains the raw KPI number (request count)
FILE_KPI_NAME="requests"

# ==============================================================================
# EXECUTION SETTINGS
# ==============================================================================

# Delay between tests (seconds)
TEST_DELAY=2

# Timeout for each test (seconds, 0 = no timeout)
TEST_TIMEOUT=300

# Run with numactl (false for ALI workload)
USE_NUMACTL=false

# ==============================================================================
# OUTPUT CONFIGURATION
# ==============================================================================

# Output format: "json"
OUTPUT_FORMAT="json"

# No custom fields needed - keep it simple
# declare -A CUSTOM_FIELDS=()
