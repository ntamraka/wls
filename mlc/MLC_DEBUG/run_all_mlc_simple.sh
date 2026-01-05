#!/bin/bash

# Script to run multiple MLC commands, save logs, and parse results
# Usage: ./run_all_mlc_simple.sh <cores> [iterations]

if [ -z "$1" ]; then
    echo "Error: Number of cores required"
    echo "Usage: $0 <cores> [iterations]"
    exit 1
fi

cores=$1
iterations=${2:-3}  # Default to 3 iterations if not specified

# Create logs directory if it doesn't exist
log_dir="./mlc_logs"
mkdir -p "$log_dir"

# Generate timestamp for unique log filenames
timestamp=$(date +%Y%m%d_%H%M%S)

# Array to store all log files for later parsing
declare -a all_log_files

# Create CSV summary file
csv_file="${log_dir}/summary_${timestamp}.csv"
echo "Iteration,Script,Idle_Latency_ns,ReadOnly_BW_MBps,Read_Write_3to1_BW_MBps,Read_Write_2to1_BW_MBps,Read_Write_1to1_BW_MBps,Read_NT_Write_2to1_BW_MBps,Read_NT_Write_1to1_BW_MBps,NT_Write_Only_BW_MBps" > "$csv_file"

echo "========================================="
echo "Starting MLC Tests - $(date)"
echo "Cores: $cores"
echo "Iterations: $iterations"
echo "Log directory: $log_dir"
echo "CSV Summary: $csv_file"
echo "========================================="
echo ""

# Loop through iterations
for i in $(seq 1 $iterations); do
    echo "========================================"
    echo "ITERATION $i of $iterations"
    echo "========================================"
    echo ""
    
    # Run run_mlc.sh
    echo "Running run_mlc.sh (iteration $i)..."
    log_file1="${log_dir}/run_mlc_iter${i}_${timestamp}.log"
    ./run_mlc.sh "$cores" 2>&1 | tee "$log_file1"
    all_log_files+=("$log_file1")
    echo ""
    echo "Log saved to: $log_file1"
    
    # Parse and update CSV immediately
    echo "Parsing and updating CSV..."
    idle_lat=$(grep -i -A 5 "idle_latency" "$log_file1" | tail -n 3 | head -n 1 | awk '{print $9}')
    ro_bw=$(grep -i -A 4 " Read-only traffic type" "$log_file1" | tail -n 1 | awk '{print $3}')
    w3_bw=$(grep -i -A 9 "W3" "$log_file1" | tail -n 1 | awk '{print $3}')
    w2_bw=$(grep -i -A 9 "W2" "$log_file1" | tail -n 1 | awk '{print $3}')
    w5_bw=$(grep -i -A 9 "W5" "$log_file1" | tail -n 1 | awk '{print $3}')
    w7_bw=$(grep -i -A 9 "W7" "$log_file1" | tail -n 1 | awk '{print $3}')
    w8_bw=$(grep -i -A 9 "W8" "$log_file1" | tail -n 1 | awk '{print $3}')
    w6_bw=$(grep -i -A 9 "W6" "$log_file1" | tail -n 1 | awk '{print $3}')
    echo "$i,run_mlc.sh,$idle_lat,$ro_bw,$w3_bw,$w2_bw,$w5_bw,$w7_bw,$w8_bw,$w6_bw" >> "$csv_file"
    echo "CSV updated with run_mlc.sh results"
    echo ""
    
    # Run run_mlc_with_sleep.sh
    echo "Running run_mlc_with_sleep.sh (iteration $i)..."
    log_file2="${log_dir}/run_mlc_with_sleep_iter${i}_${timestamp}.log"
    ./run_mlc_with_sleep.sh "$cores" 2>&1 | tee "$log_file2"
    all_log_files+=("$log_file2")
    echo ""
    echo "Log saved to: $log_file2"
    
    # Parse and update CSV immediately
    echo "Parsing and updating CSV..."
    idle_lat=$(grep -i -A 5 "idle_latency" "$log_file2" | tail -n 3 | head -n 1 | awk '{print $9}')
    ro_bw=$(grep -i -A 4 " Read-only traffic type" "$log_file2" | tail -n 1 | awk '{print $3}')
    w3_bw=$(grep -i -A 9 "W3" "$log_file2" | tail -n 1 | awk '{print $3}')
    w2_bw=$(grep -i -A 9 "W2" "$log_file2" | tail -n 1 | awk '{print $3}')
    w5_bw=$(grep -i -A 9 "W5" "$log_file2" | tail -n 1 | awk '{print $3}')
    w7_bw=$(grep -i -A 9 "W7" "$log_file2" | tail -n 1 | awk '{print $3}')
    w8_bw=$(grep -i -A 9 "W8" "$log_file2" | tail -n 1 | awk '{print $3}')
    w6_bw=$(grep -i -A 9 "W6" "$log_file2" | tail -n 1 | awk '{print $3}')
    echo "$i,run_mlc_with_sleep.sh,$idle_lat,$ro_bw,$w3_bw,$w2_bw,$w5_bw,$w7_bw,$w8_bw,$w6_bw" >> "$csv_file"
    echo "CSV updated with run_mlc_with_sleep.sh results"
    echo ""
    
    # Run run_mlc_witout_wait.sh
    echo "Running run_mlc_witout_wait.sh (iteration $i)..."
    log_file3="${log_dir}/run_mlc_witout_wait_iter${i}_${timestamp}.log"
    ./run_mlc_witout_wait.sh "$cores" 2>&1 | tee "$log_file3"
    all_log_files+=("$log_file3")
    echo ""
    echo "Log saved to: $log_file3"
    
    # Parse and update CSV immediately
    echo "Parsing and updating CSV..."
    idle_lat=$(grep -i -A 5 "idle_latency" "$log_file3" | tail -n 3 | head -n 1 | awk '{print $9}')
    ro_bw=$(grep -i -A 4 " Read-only traffic type" "$log_file3" | tail -n 1 | awk '{print $3}')
    w3_bw=$(grep -i -A 9 "W3" "$log_file3" | tail -n 1 | awk '{print $3}')
    w2_bw=$(grep -i -A 9 "W2" "$log_file3" | tail -n 1 | awk '{print $3}')
    w5_bw=$(grep -i -A 9 "W5" "$log_file3" | tail -n 1 | awk '{print $3}')
    w7_bw=$(grep -i -A 9 "W7" "$log_file3" | tail -n 1 | awk '{print $3}')
    w8_bw=$(grep -i -A 9 "W8" "$log_file3" | tail -n 1 | awk '{print $3}')
    w6_bw=$(grep -i -A 9 "W6" "$log_file3" | tail -n 1 | awk '{print $3}')
    echo "$i,run_mlc_witout_wait.sh,$idle_lat,$ro_bw,$w3_bw,$w2_bw,$w5_bw,$w7_bw,$w8_bw,$w6_bw" >> "$csv_file"
    echo "CSV updated with run_mlc_witout_wait.sh results"
    echo ""
    
    echo "Completed iteration $i of $iterations"
    echo ""
done

echo ""
echo "========================================="
echo "All tests completed - $(date)"
echo "========================================="
echo "Total iterations: $iterations"
echo "Total log files: ${#all_log_files[@]}"
echo ""
echo "CSV Summary file: $csv_file"
echo ""
echo "Final results summary:"
cat "$csv_file"
echo ""
echo "Log files:"
for log_file in "${all_log_files[@]}"; do
    echo "  - $log_file"
done
