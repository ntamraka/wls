#!/bin/bash

################################################################################
# MLC Complete Benchmark Script
# Runs all MLC tests, parses results, saves to CSV, and prints summaries
################################################################################

# Configuration
cores=${1:-$(lscpu | awk '/^Core\(s\) per socket:/{print $NF}')}
last_core=$((cores - 1))
cpuset="0-${last_core}"
numanode=0
latency_core=1
duration=10
bw_mem="1g"
lat_mem="4g"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mlc_binary="${SCRIPT_DIR}/mlc_internal"

# Output files
timestamp=$(date +%Y%m%d_%H%M%S)
LOG_FILE="${SCRIPT_DIR}/mlc_run_${timestamp}.log"
CSV_FILE="${SCRIPT_DIR}/mlc_results_${timestamp}.csv"
TEMP_LOG="${SCRIPT_DIR}/temp_test.log"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

################################################################################
# Functions
################################################################################

# Check if mlc_binary exists
check_binary() {
    if [[ ! -f "$mlc_binary" ]]; then
        echo -e "${RED}Error: MLC binary not found at $mlc_binary${NC}"
        exit 1
    fi
    if [[ ! -x "$mlc_binary" ]]; then
        echo -e "${YELLOW}Warning: Making MLC binary executable${NC}"
        chmod +x "$mlc_binary"
    fi
}

# Initialize CSV file with headers
init_csv() {
    echo "Timestamp,Test_Type,Bandwidth_MBps,Latency_ns,Read_Write_Ratio,Duration_sec,Cores_Used" > "$CSV_FILE"
    echo -e "${GREEN}CSV file created: $CSV_FILE${NC}"
}

# Print test header
print_test_header() {
    local test_name=$1
    local test_num=$2
    echo ""
    echo "========================================================================="
    echo "  Test $test_num: $test_name"
    echo "========================================================================="
}

# Parse bandwidth from output
parse_bandwidth() {
    local log_file=$1
    # Look for the bandwidth line that starts with " 00000"
    local bw=$(grep "^ 00000" "$log_file" | tail -n 1 | awk '{print $3}')
    echo "$bw"
}

# Parse latency from output
parse_latency() {
    local log_file=$1
    # Look for latency value in idle_latency output
    # Format: "Each iteration took 335.8 base frequency clocks (	146.0	ns)"
    # Extract the ns value between parentheses
    local lat=$(grep "Each iteration took" "$log_file" | tail -n 1 | sed 's/.*(\s*\([0-9.]*\)\s*ns).*/\1/')
    # If not found, try alternative format looking at the results table
    if [[ -z "$lat" ]]; then
        lat=$(grep "^ 00000" "$log_file" | tail -n 1 | awk '{print $2}')
    fi
    echo "$lat"
}

# Print summary for bandwidth test
print_bandwidth_summary() {
    local test_name=$1
    local bandwidth=$2
    local ratio=$3
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Summary: $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Read:Write Ratio:  ${YELLOW}$ratio${NC}"
    echo -e "  Bandwidth:         ${YELLOW}$bandwidth MB/s${NC}"
    echo -e "  Duration:          ${YELLOW}$duration seconds${NC}"
    echo -e "  Cores Used:        ${YELLOW}$cores (0-$last_core)${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Print summary for latency test
print_latency_summary() {
    local test_name=$1
    local latency=$2
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}  Summary: $test_name${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  Idle Latency:      ${YELLOW}$latency ns${NC}"
    echo -e "  Memory Size:       ${YELLOW}$lat_mem${NC}"
    echo -e "  Duration:          ${YELLOW}$duration seconds${NC}"
    echo -e "  NUMA Node:         ${YELLOW}$numanode${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Save to CSV
save_to_csv() {
    local test_type=$1
    local bandwidth=$2
    local latency=$3
    local ratio=$4
    local ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "$ts,$test_type,$bandwidth,$latency,$ratio,$duration,$cores" >> "$CSV_FILE"
}

# Run bandwidth test
run_bandwidth_test() {
    local test_num=$1
    local test_name=$2
    local flag=$3
    local ratio=$4
    
    print_test_header "$test_name" "$test_num"
    
    # Run test and capture output
    $mlc_binary --loaded_latency -k$cpuset -T -d0 -e -r -b$bw_mem -t${duration} $flag 2>&1 | tee "$TEMP_LOG"
    
    # Append to main log
    cat "$TEMP_LOG" >> "$LOG_FILE"
    
    # Parse results
    local bandwidth=$(parse_bandwidth "$TEMP_LOG")
    
    # Handle empty bandwidth
    if [[ -z "$bandwidth" || "$bandwidth" == "0" ]]; then
        bandwidth="N/A"
    fi
    
    # Print summary
    print_bandwidth_summary "$test_name" "$bandwidth" "$ratio"
    
    # Save to CSV
    save_to_csv "$test_name" "$bandwidth" "N/A" "$ratio"
    
    echo -e "${GREEN}✓ Test completed${NC}"
    echo "Cooling down for 10 seconds..."
    sleep 10
    
    # Clean up temp log
    rm -f "$TEMP_LOG"
}

# Run latency test
run_latency_test() {
    local test_num=$1
    
    print_test_header "Idle Latency Test" "$test_num"
    
    # Run test and capture output
    $mlc_binary --idle_latency -b$lat_mem -t${duration} -c1 -j$numanode -e -r -l128 2>&1 | tee "$TEMP_LOG"
    
    # Append to main log
    cat "$TEMP_LOG" >> "$LOG_FILE"
    
    # Parse results
    local latency=$(parse_latency "$TEMP_LOG")
    
    # Handle empty latency
    if [[ -z "$latency" || "$latency" == "0" ]]; then
        latency="N/A"
    fi
    
    # Print summary
    print_latency_summary "Idle Latency Test" "$latency"
    
    # Save to CSV
    save_to_csv "Idle_Latency" "N/A" "$latency" "N/A"
    
    echo -e "${GREEN}✓ Test completed${NC}"
    
    # Clean up temp log
    rm -f "$TEMP_LOG"
}

# Print final summary
print_final_summary() {
    echo ""
    echo "========================================================================="
    echo "                          FINAL SUMMARY"
    echo "========================================================================="
    echo ""
    echo "All tests completed successfully!"
    echo ""
    echo "Results saved to:"
    echo "  - Log file: $LOG_FILE"
    echo "  - CSV file: $CSV_FILE"
    echo ""
    echo "CSV Summary:"
    column -t -s',' "$CSV_FILE"
    echo ""
    echo "========================================================================="
}

################################################################################
# Main Execution
################################################################################

main() {
    echo "========================================================================="
    echo "             MLC Memory Performance Benchmark Suite"
    echo "========================================================================="
    echo ""
    echo "Configuration:"
    echo "  Cores: $cores (CPU set: $cpuset)"
    echo "  Duration per test: $duration seconds"
    echo "  Bandwidth memory: $bw_mem"
    echo "  Latency memory: $lat_mem"
    echo "  NUMA node: $numanode"
    echo ""
    echo "Output files:"
    echo "  Log: $LOG_FILE"
    echo "  CSV: $CSV_FILE"
    echo ""
    echo "========================================================================="
    
    # Check if binary exists
    check_binary
    
    # Initialize CSV
    init_csv
    
    # Initialize log file
    echo "MLC Benchmark Run - $(date)" > "$LOG_FILE"
    echo "Configuration: cores=$cores, duration=$duration, bw_mem=$bw_mem, lat_mem=$lat_mem" >> "$LOG_FILE"
    echo "=========================================================================" >> "$LOG_FILE"
    
    # Run all tests
    run_bandwidth_test "1/8" "Read-Only Traffic" "-R" "Read-only"
    run_bandwidth_test "2/8" "3:1 Read-Write Traffic" "-W3" "3:1 (Read:Write)"
    run_bandwidth_test "3/8" "2:1 Read-Write Traffic" "-W2" "2:1 (Read:Write)"
    run_bandwidth_test "4/8" "1:1 Read-Write Traffic" "-W5" "1:1 (Read:Write)"
    run_bandwidth_test "5/8" "2:1 Read-NT Write Traffic" "-W7" "2:1 (Read:NT-Write)"
    run_bandwidth_test "6/8" "1:1 Read-NT Write Traffic" "-W8" "1:1 (Read:NT-Write)"
    run_bandwidth_test "7/8" "Write-Only NT Traffic" "-W6" "Write-only (NT)"
    run_latency_test "8/8"
    
    # Print final summary
    print_final_summary
}

# Run main function
main

exit 0
