#!/bin/bash

# Check if the correct number of arguments is provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <online|offline> <start_core> <end_core>"
    exit 1
fi

ACTION=$1
START_CORE=$2
END_CORE=$3

# Determine the value to write based on the action
if [ "$ACTION" == "offline" ]; then
    VALUE=0
elif [ "$ACTION" == "online" ]; then
    VALUE=1
else
    echo "Invalid action: $ACTION. Use 'online' or 'offline'."
    exit 1
fi

# Loop through the specified range of cores
for (( i=START_CORE; i<=END_CORE; i++ )); do
    CORE_PATH="/sys/devices/system/cpu/cpu$i/online"
    
    # Check if the core exists
    if [ -e "$CORE_PATH" ]; then
        echo $VALUE | sudo tee "$CORE_PATH"
        echo "Core $i set to $ACTION."
    else
        echo "Core $i does not exist."
    fi
done
