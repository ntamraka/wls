#!/bin/bash

LOG_DIR="$1"

if [ -z "$LOG_DIR" ]; then
    echo "Usage: $0 <log_folder>"
    exit 1
fi

#echo "Folder,FileCount,Avg_DocCount,Avg_MeanRate,Avg_m1,Avg_m5,Avg_m15" > summary.csv

FILE_COUNT=$(ls -1 "$LOG_DIR"/*.log 2>/dev/null | wc -l)

TOTAL_DOC=0
TOTAL_MEAN=0
TOTAL_M1=0
TOTAL_M5=0
TOTAL_M15=0
COUNT=0

for file in "$LOG_DIR"/*.log; do
    LAST_LINE=$(tail -2 "$file" | tr -d ',')  # remove commas for safe parsing

    DOC=$(echo "$LAST_LINE" | grep -oP 'Document Count: \K[0-9]+' || echo 0)
    MEAN=$(echo "$LAST_LINE" | grep -oP 'Mean Rate: \K[0-9.]+' || echo 0)
    M1=$(echo "$LAST_LINE" | grep -oP 'm1_rate: \K[0-9.]+' || echo 0)
    M5=$(echo "$LAST_LINE" | grep -oP 'm5_rate: \K[0-9.]+' || echo 0)
    M15=$(echo "$LAST_LINE" | grep -oP 'm15_rate: \K[0-9.]+' || echo 0)

    TOTAL_DOC=$(echo "$TOTAL_DOC + $DOC" | bc)
    TOTAL_MEAN=$(echo "$TOTAL_MEAN + $MEAN" | bc)
    TOTAL_M1=$(echo "$TOTAL_M1 + $M1" | bc)
    TOTAL_M5=$(echo "$TOTAL_M5 + $M5" | bc)
    TOTAL_M15=$(echo "$TOTAL_M15 + $M15" | bc)

    COUNT=$((COUNT + 1))
    
done

AVG_DOC=$(echo "scale=2; $TOTAL_DOC / $COUNT" | bc)
AVG_MEAN=$(echo "scale=2; $TOTAL_MEAN / $COUNT" | bc)
AVG_M1=$(echo "scale=2; $TOTAL_M1 / $COUNT" | bc)
AVG_M5=$(echo "scale=2; $TOTAL_M5 / $COUNT" | bc)
AVG_M15=$(echo "scale=2; $TOTAL_M15 / $COUNT" | bc)

FOLDER_NAME=$(basename "$LOG_DIR")

echo "$FOLDER_NAME,$FILE_COUNT,$AVG_DOC,$AVG_MEAN,$AVG_M1,$AVG_M5,$AVG_M15" >> summary.csv

echo "Summary created: summary.csv"
