#!/bin/bash

# Directory containing the text files
DIR="."

# Output CSV file
OUTPUT_CSV="output.csv"

# Write the header to the CSV file
echo "core,size,pipe,output1,output2,average" > "$OUTPUT_CSV"

# Loop through each file matching the pattern
for FILE in "$DIR"/Redis_pipe-*${1}*.txt ; do
    # Extract core, size, and pipe from the filename
    BASENAME=$(basename "$FILE")
    CORE=$(echo "$BASENAME" | grep -oP 'core-\K\d+')
    SIZE=$(echo "$BASENAME" | grep -oP 'size-\K\d+')
    PIPE=$(echo "$BASENAME" | grep -oP 'pipe-\K\d+')

    # Extract the outputs from the file
    OUTPUTS=$(grep "total number of IOPS for" "$FILE" | awk '{print $NF}')
    OUTPUT1=$(echo "$OUTPUTS" | sed -n '1p')
    OUTPUT2=$(echo "$OUTPUTS" | sed -n '2p')
    OUTPUT3=$(echo "$OUTPUTS" | sed -n '3p')
    OUTPUT4=$(echo "$OUTPUTS" | sed -n '4p')
    OUTPUT5=$(echo "$OUTPUTS" | sed -n '5p')


    # Calculate the average of the two outputs
    AVERAGE=$(echo "scale=2; ($OUTPUT1 + $OUTPUT2 + $OUTPUT3+$OUTPUT4+$OUTPUT5) / 5" | bc)

    # Write the results to the CSV file
    echo "$FILE,$CORE,$SIZE,$PIPE,$OUTPUT1,$OUTPUT2,$OUTPUT3,$OUTPUT4,$OUTPUT5,$AVERAGE" >> "$OUTPUT_CSV"
done

echo "CSV file created: $OUTPUT_CSV"
cat output.csv
