#!/bin/bash

# Script to run multiple MLC commands, save logs, and parse results
# Usage: ./run_all_mlc.sh <cores> [iterations]

if [ -z "$1" ]; then
    echo "Error: Number of cores required"
    echo "Usage: $0 <cores> [iterations]"
    exit 1
fi

cores=$1
iterations=${2:-3}  # Default to 3 iterations if not specified

# Hugepage settings
thp_path="/sys/kernel/mm/transparent_hugepage/enabled"

# Function to set hugepage mode
set_hugepage() {
    local mode=$1
    if [ -w "$thp_path" ]; then
        echo "$mode" > "$thp_path"
        echo "Hugepage set to: $mode"
    else
        echo "Warning: Cannot write to $thp_path (may need root privileges)"
        echo "Current hugepage setting: $(cat $thp_path 2>/dev/null || echo 'unknown')"
    fi
}

# Function to get current hugepage setting
get_hugepage() {
    if [ -r "$thp_path" ]; then
        cat "$thp_path"
    else
        echo "unknown"
    fi
}

# Create logs directory if it doesn't exist
log_dir="./mlc_logs"
mkdir -p "$log_dir"

# Generate timestamp for unique log filenames
timestamp=$(date +%Y%m%d_%H%M%S)

# Array to store all log files for later parsing
declare -a all_log_files

# Save original hugepage setting
original_hugepage=$(get_hugepage)

echo "========================================="
echo "Starting MLC Tests - $(date)"
echo "Cores: $cores"
echo "Iterations: $iterations"
echo "Log directory: $log_dir"
echo "Original hugepage setting: $original_hugepage"
echo "========================================="
echo ""

# Loop through iterations
for i in $(seq 1 $iterations); do
    echo "========================================"
    echo "ITERATION $i of $iterations"
    echo "========================================"
    echo ""
    
    # Run run_mlc.sh with hugepage=never
    echo "Setting hugepage to: never"
    set_hugepage "never"
    echo ""
    echo "Running run_mlc.sh (iteration $i) with hugepage=never..."
    log_file1="${log_dir}/run_mlc_hugepage_never_iter${i}_${timestamp}.log"
    ./run_mlc.sh "$cores" 2>&1 | tee "$log_file1"
    all_log_files+=("$log_file1")
    echo ""
    echo "Log saved to: $log_file1"
    echo ""
    
    # Run run_mlc.sh with hugepage=always
    echo "Setting hugepage to: always"
    set_hugepage "always"
    echo ""
    echo "Running run_mlc.sh (iteration $i) with hugepage=always..."
    log_file2="${log_dir}/run_mlc_hugepage_always_iter${i}_${timestamp}.log"
    ./run_mlc.sh "$cores" 2>&1 | tee "$log_file2"
    all_log_files+=("$log_file2")
    echo ""
    echo "Log saved to: $log_file2"
    echo ""
    
    # Run run_mlc_with_sleep.sh with hugepage=never
    echo "Setting hugepage to: never"
    set_hugepage "never"
    echo ""
    echo "Running run_mlc_with_sleep.sh (iteration $i) with hugepage=never..."
    log_file3="${log_dir}/run_mlc_with_sleep_hugepage_never_iter${i}_${timestamp}.log"
    ./run_mlc_with_sleep.sh "$cores" 2>&1 | tee "$log_file3"
    all_log_files+=("$log_file3")
    echo ""
    echo "Log saved to: $log_file3"
    echo ""
    
    # Run run_mlc_with_sleep.sh with hugepage=always
    echo "Setting hugepage to: always"
    set_hugepage "always"
    echo ""
    echo "Running run_mlc_with_sleep.sh (iteration $i) with hugepage=always..."
    log_file4="${log_dir}/run_mlc_with_sleep_hugepage_always_iter${i}_${timestamp}.log"
    ./run_mlc_with_sleep.sh "$cores" 2>&1 | tee "$log_file4"
    all_log_files+=("$log_file4")
    echo ""
    echo "Log saved to: $log_file4"
    echo ""
    
    # Run run_mlc_witout_wait.sh with hugepage=never
    echo "Setting hugepage to: never"
    set_hugepage "never"
    echo ""
    echo "Running run_mlc_witout_wait.sh (iteration $i) with hugepage=never..."
    log_file5="${log_dir}/run_mlc_witout_wait_hugepage_never_iter${i}_${timestamp}.log"
    ./run_mlc_witout_wait.sh "$cores" 2>&1 | tee "$log_file5"
    all_log_files+=("$log_file5")
    echo ""
    echo "Log saved to: $log_file5"
    echo ""
    
    # Run run_mlc_witout_wait.sh with hugepage=always
    echo "Setting hugepage to: always"
    set_hugepage "always"
    echo ""
    echo "Running run_mlc_witout_wait.sh (iteration $i) with hugepage=always..."
    log_file6="${log_dir}/run_mlc_witout_wait_hugepage_always_iter${i}_${timestamp}.log"
    ./run_mlc_witout_wait.sh "$cores" 2>&1 | tee "$log_file6"
    all_log_files+=("$log_file6")
    echo ""
    echo "Log saved to: $log_file6"
    echo ""
    
    echo "Completed iteration $i of $iterations"
    echo ""
done

# Restore original hugepage setting
echo ""
echo "Restoring original hugepage setting..."
set_hugepage "$original_hugepage"
echo ""

# Create CSV summary file
csv_file="${log_dir}/summary_${timestamp}.csv"
echo "Creating CSV summary: $csv_file"
echo "Iteration,Script,Hugepage,Idle_Latency_ns,ReadOnly_BW_MBps,Read_Write_3to1_BW_MBps,Read_Write_2to1_BW_MBps,Read_Write_1to1_BW_MBps,Read_NT_Write_2to1_BW_MBps,Read_NT_Write_1to1_BW_MBps,NT_Write_Only_BW_MBps" > "$csv_file"

# Parse all the logs using parse_mlc.sh
echo "========================================="
echo "Parsing All Results"
echo "========================================="
echo ""

for i in $(seq 1 $iterations); do
    echo "========================================="
    echo "ITERATION $i RESULTS"
    echo "========================================="
    echo ""
    
    # Parse run_mlc.sh (hugepage=never)
    log_file1="${log_dir}/run_mlc_hugepage_never_iter${i}_${timestamp}.log"
    echo "--- run_mlc.sh (hugepage=never) ---"
    ./parse_mlc.sh "$log_file1"
    
    # Extract values and write to CSV
    idle_lat=$(grep -i -A 5 "idle_latency" "$log_file1" | tail -n 3 | head -n 1 | awk '{print $9}')
    ro_bw=$(grep -i -A 4 " Read-only traffic type" "$log_file1" | tail -n 1 | awk '{print $3}')
    w3_bw=$(grep -i -A 9 "W3" "$log_file1" | tail -n 1 | awk '{print $3}')
    w2_bw=$(grep -i -A 9 "W2" "$log_file1" | tail -n 1 | awk '{print $3}')
    w5_bw=$(grep -i -A 9 "W5" "$log_file1" | tail -n 1 | awk '{print $3}')
    w7_bw=$(grep -i -A 9 "W7" "$log_file1" | tail -n 1 | awk '{print $3}')
    w8_bw=$(grep -i -A 9 "W8" "$log_file1" | tail -n 1 | awk '{print $3}')
    w6_bw=$(grep -i -A 9 "W6" "$log_file1" | tail -n 1 | awk '{print $3}')
    echo "$i,run_mlc.sh,never,$idle_lat,$ro_bw,$w3_bw,$w2_bw,$w5_bw,$w7_bw,$w8_bw,$w6_bw" >> "$csv_file"
    echo ""
    
    # Parse run_mlc.sh (hugepage=always)
    log_file2="${log_dir}/run_mlc_hugepage_always_iter${i}_${timestamp}.log"
    echo "--- run_mlc.sh (hugepage=always) ---"
    ./parse_mlc.sh "$log_file2"
    
    idle_lat=$(grep -i -A 5 "idle_latency" "$log_file2" | tail -n 3 | head -n 1 | awk '{print $9}')
    ro_bw=$(grep -i -A 4 " Read-only traffic type" "$log_file2" | tail -n 1 | awk '{print $3}')
    w3_bw=$(grep -i -A 9 "W3" "$log_file2" | tail -n 1 | awk '{print $3}')
    w2_bw=$(grep -i -A 9 "W2" "$log_file2" | tail -n 1 | awk '{print $3}')
    w5_bw=$(grep -i -A 9 "W5" "$log_file2" | tail -n 1 | awk '{print $3}')
    w7_bw=$(grep -i -A 9 "W7" "$log_file2" | tail -n 1 | awk '{print $3}')
    w8_bw=$(grep -i -A 9 "W8" "$log_file2" | tail -n 1 | awk '{print $3}')
    w6_bw=$(grep -i -A 9 "W6" "$log_file2" | tail -n 1 | awk '{print $3}')
    echo "$i,run_mlc.sh,always,$idle_lat,$ro_bw,$w3_bw,$w2_bw,$w5_bw,$w7_bw,$w8_bw,$w6_bw" >> "$csv_file"
    echo ""
    
    # Parse run_mlc_with_sleep.sh (hugepage=never)
    log_file3="${log_dir}/run_mlc_with_sleep_hugepage_never_iter${i}_${timestamp}.log"
    echo "--- run_mlc_with_sleep.sh (hugepage=never) ---"
    ./parse_mlc.sh "$log_file3"
    
    idle_lat=$(grep -i -A 5 "idle_latency" "$log_file3" | tail -n 3 | head -n 1 | awk '{print $9}')
    ro_bw=$(grep -i -A 4 " Read-only traffic type" "$log_file3" | tail -n 1 | awk '{print $3}')
    w3_bw=$(grep -i -A 9 "W3" "$log_file3" | tail -n 1 | awk '{print $3}')
    w2_bw=$(grep -i -A 9 "W2" "$log_file3" | tail -n 1 | awk '{print $3}')
    w5_bw=$(grep -i -A 9 "W5" "$log_file3" | tail -n 1 | awk '{print $3}')
    w7_bw=$(grep -i -A 9 "W7" "$log_file3" | tail -n 1 | awk '{print $3}')
    w8_bw=$(grep -i -A 9 "W8" "$log_file3" | tail -n 1 | awk '{print $3}')
    w6_bw=$(grep -i -A 9 "W6" "$log_file3" | tail -n 1 | awk '{print $3}')
    echo "$i,run_mlc_with_sleep.sh,never,$idle_lat,$ro_bw,$w3_bw,$w2_bw,$w5_bw,$w7_bw,$w8_bw,$w6_bw" >> "$csv_file"
    echo ""
    
    # Parse run_mlc_with_sleep.sh (hugepage=always)
    log_file4="${log_dir}/run_mlc_with_sleep_hugepage_always_iter${i}_${timestamp}.log"
    echo "--- run_mlc_with_sleep.sh (hugepage=always) ---"
    ./parse_mlc.sh "$log_file4"
    
    idle_lat=$(grep -i -A 5 "idle_latency" "$log_file4" | tail -n 3 | head -n 1 | awk '{print $9}')
    ro_bw=$(grep -i -A 4 " Read-only traffic type" "$log_file4" | tail -n 1 | awk '{print $3}')
    w3_bw=$(grep -i -A 9 "W3" "$log_file4" | tail -n 1 | awk '{print $3}')
    w2_bw=$(grep -i -A 9 "W2" "$log_file4" | tail -n 1 | awk '{print $3}')
    w5_bw=$(grep -i -A 9 "W5" "$log_file4" | tail -n 1 | awk '{print $3}')
    w7_bw=$(grep -i -A 9 "W7" "$log_file4" | tail -n 1 | awk '{print $3}')
    w8_bw=$(grep -i -A 9 "W8" "$log_file4" | tail -n 1 | awk '{print $3}')
    w6_bw=$(grep -i -A 9 "W6" "$log_file4" | tail -n 1 | awk '{print $3}')
    echo "$i,run_mlc_with_sleep.sh,always,$idle_lat,$ro_bw,$w3_bw,$w2_bw,$w5_bw,$w7_bw,$w8_bw,$w6_bw" >> "$csv_file"
    echo ""
    
    # Parse run_mlc_witout_wait.sh (hugepage=never)
    log_file5="${log_dir}/run_mlc_witout_wait_hugepage_never_iter${i}_${timestamp}.log"
    echo "--- run_mlc_witout_wait.sh (hugepage=never) ---"
    ./parse_mlc.sh "$log_file5"
    
    idle_lat=$(grep -i -A 5 "idle_latency" "$log_file5" | tail -n 3 | head -n 1 | awk '{print $9}')
    ro_bw=$(grep -i -A 4 " Read-only traffic type" "$log_file5" | tail -n 1 | awk '{print $3}')
    w3_bw=$(grep -i -A 9 "W3" "$log_file5" | tail -n 1 | awk '{print $3}')
    w2_bw=$(grep -i -A 9 "W2" "$log_file5" | tail -n 1 | awk '{print $3}')
    w5_bw=$(grep -i -A 9 "W5" "$log_file5" | tail -n 1 | awk '{print $3}')
    w7_bw=$(grep -i -A 9 "W7" "$log_file5" | tail -n 1 | awk '{print $3}')
    w8_bw=$(grep -i -A 9 "W8" "$log_file5" | tail -n 1 | awk '{print $3}')
    w6_bw=$(grep -i -A 9 "W6" "$log_file5" | tail -n 1 | awk '{print $3}')
    echo "$i,run_mlc_witout_wait.sh,never,$idle_lat,$ro_bw,$w3_bw,$w2_bw,$w5_bw,$w7_bw,$w8_bw,$w6_bw" >> "$csv_file"
    echo ""
    
    # Parse run_mlc_witout_wait.sh (hugepage=always)
    log_file6="${log_dir}/run_mlc_witout_wait_hugepage_always_iter${i}_${timestamp}.log"
    echo "--- run_mlc_witout_wait.sh (hugepage=always) ---"
    ./parse_mlc.sh "$log_file6"
    
    idle_lat=$(grep -i -A 5 "idle_latency" "$log_file6" | tail -n 3 | head -n 1 | awk '{print $9}')
    ro_bw=$(grep -i -A 4 " Read-only traffic type" "$log_file6" | tail -n 1 | awk '{print $3}')
    w3_bw=$(grep -i -A 9 "W3" "$log_file6" | tail -n 1 | awk '{print $3}')
    w2_bw=$(grep -i -A 9 "W2" "$log_file6" | tail -n 1 | awk '{print $3}')
    w5_bw=$(grep -i -A 9 "W5" "$log_file6" | tail -n 1 | awk '{print $3}')
    w7_bw=$(grep -i -A 9 "W7" "$log_file6" | tail -n 1 | awk '{print $3}')
    w8_bw=$(grep -i -A 9 "W8" "$log_file6" | tail -n 1 | awk '{print $3}')
    w6_bw=$(grep -i -A 9 "W6" "$log_file6" | tail -n 1 | awk '{print $3}')
    echo "$i,run_mlc_witout_wait.sh,always,$idle_lat,$ro_bw,$w3_bw,$w2_bw,$w5_bw,$w7_bw,$w8_bw,$w6_bw" >> "$csv_file"
    echo ""
    echo ""
done

echo "========================================="
echo "All tests completed - $(date)"
echo "========================================="
echo "Total iterations: $iterations"
echo "Total log files: ${#all_log_files[@]}"
echo ""
echo "CSV Summary file created: $csv_file"
echo ""
echo "Log files:"
for log_file in "${all_log_files[@]}"; do
    echo "  - $log_file"
done
echo ""
echo "To view CSV summary:"
echo "  cat $csv_file"
echo "  or open in spreadsheet application"
