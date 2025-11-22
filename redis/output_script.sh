#!/bin/bash
    grep -r "Total" $1 | awk '{sum += $2; print $2; next} END {print "total number of IOPS for",NR, " Instance ", sum/NR }'

    