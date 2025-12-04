#!/bin/bash

# Unified Scaling Script for Redis Benchmarks
# Usage: ./scaling_unified.sh <operation> <name>
# Operations: ping, read, write, readwrite

OPERATION=$1
NAME=$2

if [ -z "$OPERATION" ] || [ -z "$NAME" ]; then
    echo "Usage: $0 <operation> <name>"
    echo "Operations: ping, read, write, readwrite"
    echo "Example: $0 ping Core_Scaling_Test_Run1"
    exit 1
fi

# Validate operation type
case "$OPERATION" in
    ping|read|write|readwrite)
        echo "Running $OPERATION benchmark with name: $NAME"
        ;;
    *)
        echo "Error: Invalid operation '$OPERATION'"
        echo "Valid operations: ping, read, write, readwrite"
        exit 1
        ;;
esac

# Create results directory for this run
RESULTS_DIR="results/${NAME}"
mkdir -p "$RESULTS_DIR"
echo "Results will be saved to: $RESULTS_DIR"

# Loop through pipeline depths (modify as needed)
for pipe in 1
do
    # Loop through core counts (modify as needed)
    #for core in $(seq 16 16 144);
    for core in 288
    do 
        # Loop through data sizes (modify as needed)
        for size in 64
        do
            echo ""
            echo "=============================================="
            echo "Running: Operation=$OPERATION Pipe=$pipe Core=$core Size=$size"
            echo "=============================================="
            echo ""
            
            # Run the unified benchmark
            echo "python3 benchmark_unified.py -o ${OPERATION} -p ${pipe} -c ${core} -s ${size}"
            
            # Output file path in results directory
            OUTPUT_FILE="${RESULTS_DIR}/Redis_${OPERATION}_pipe-${pipe}_size-${size}_core-${core}_${NAME}.txt"
            
            # Direct execution with output saved to results directory
            python3 benchmark_unified.py -o ${OPERATION} -p ${pipe} -c ${core} -s ${size} 2>&1 | tee "$OUTPUT_FILE"
            
            # Option 2: With TMC wrapper (uncomment if using TMC)
            # python3 /root/tmc/tmc.py -u -Z metrics2 -n -x ntamraka -d /root/tmc/redis \
            #     -G Redis_study_scale -r 30 -t 60 -i redis \
            #     -a ${OPERATION}_pipe-${pipe}_size-${size}_core-${core}_${NAME} \
            #     -c "python3 benchmark_unified.py -o ${OPERATION} -p ${pipe} -c ${core} -s ${size} 2>&1 | tee Redis_${OPERATION}_pipe-${pipe}_size-${size}_core-${core}_${NAME}.txt"
            
            sleep 5
        done
    done
done

echo ""
echo "=============================================="
echo "Benchmarking completed!"
echo "=============================================="

# Aggregate results into CSV
echo ""
echo "=============================================="
echo "Aggregating Results..."
echo "=============================================="

# Determine number of clients based on operation
case "$OPERATION" in
    ping)
        NUM_CLIENTS=6
        ;;
    read|write|readwrite)
        NUM_CLIENTS=2
        ;;
esac

echo "Operation: $OPERATION has $NUM_CLIENTS clients"

# Output CSV file in results directory
OUTPUT_CSV="${RESULTS_DIR}/output_${NAME}.csv"

# Build dynamic header based on number of clients
HEADER="file,core,size,pipe"
for i in $(seq 1 $NUM_CLIENTS); do
    HEADER="${HEADER},client${i}_iops"
done
HEADER="${HEADER},total_iops,average_iops"
echo "$HEADER" > "$OUTPUT_CSV"

# Loop through each file matching the pattern in results directory
for FILE in ${RESULTS_DIR}/Redis_${OPERATION}_pipe-*_${NAME}.txt ; do
    if [ -f "$FILE" ]; then
        # Extract core, size, and pipe from the filename
        BASENAME=$(basename "$FILE")
        CORE=$(echo "$BASENAME" | grep -oP 'core-\K\d+')
        SIZE=$(echo "$BASENAME" | grep -oP 'size-\K\d+')
        PIPE=$(echo "$BASENAME" | grep -oP 'pipe-\K\d+')

        # Extract all IOPS outputs from the file
        OUTPUTS=$(grep "total number of IOPS for" "$FILE" | awk '{print $NF}')
        
        # Read outputs into array
        OUTPUT_ARRAY=()
        TOTAL=0
        COUNT=0
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                OUTPUT_ARRAY+=("$line")
                TOTAL=$(echo "scale=2; $TOTAL + $line" | bc)
                COUNT=$((COUNT + 1))
            fi
        done <<< "$OUTPUTS"
        
        # Ensure we have exactly NUM_CLIENTS outputs (pad with 0 if missing)
        while [ ${#OUTPUT_ARRAY[@]} -lt $NUM_CLIENTS ]; do
            OUTPUT_ARRAY+=(0)
        done
        
        # Calculate average
        if [ $COUNT -gt 0 ]; then
            AVERAGE=$(echo "scale=2; $TOTAL / $COUNT" | bc)
        else
            AVERAGE=0
        fi

        # Build CSV row
        CSV_ROW="$FILE,$CORE,$SIZE,$PIPE"
        for output in "${OUTPUT_ARRAY[@]}"; do
            CSV_ROW="${CSV_ROW},${output}"
        done
        CSV_ROW="${CSV_ROW},${TOTAL},${AVERAGE}"
        
        # Write the results to the CSV file
        echo "$CSV_ROW" >> "$OUTPUT_CSV"
        
        echo "Processed: $FILE -> Total IOPS: $TOTAL (Avg per client: $AVERAGE)"
    fi
done

if [ -f "$OUTPUT_CSV" ]; then
    echo ""
    echo "=============================================="
    echo "Results Summary (${OUTPUT_CSV}):"
    echo "=============================================="
    cat "$OUTPUT_CSV"
    echo ""
    echo "CSV file created: $OUTPUT_CSV"
else
    echo "No results files found matching pattern: Redis_${OPERATION}_pipe-*_${NAME}.txt"
fi

# Append to global results summary
GLOBAL_SUMMARY="results_summary.csv"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Create global summary file with header if it doesn't exist
if [ ! -f "$GLOBAL_SUMMARY" ]; then
    echo "timestamp,run_name,operation,core,size,pipe,total_iops,avg_iops_per_client" > "$GLOBAL_SUMMARY"
    echo "Global results summary created: $GLOBAL_SUMMARY"
fi

# Append results from this run to global summary
if [ -f "$OUTPUT_CSV" ]; then
    # Skip header line and append data with timestamp and run info
    tail -n +2 "$OUTPUT_CSV" | while IFS=',' read -r file core size pipe rest; do
        # Extract total and average from the end of the line
        # The format is: file,core,size,pipe,client1,...,clientN,total,average
        TOTAL=$(echo "$rest" | awk -F',' '{print $(NF-1)}')
        AVERAGE=$(echo "$rest" | awk -F',' '{print $NF}')
        echo "$TIMESTAMP,$NAME,$OPERATION,$core,$size,$pipe,$TOTAL,$AVERAGE" >> "$GLOBAL_SUMMARY"
    done
    echo ""
    echo "=============================================="
    echo "Global summary updated: $GLOBAL_SUMMARY"
    echo "=============================================="
    echo ""
    echo "Recent entries:"
    tail -5 "$GLOBAL_SUMMARY" | column -t -s ','
fi
