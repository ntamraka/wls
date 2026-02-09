#!/bin/bash

# Real-Time Performance Monitor v2.0
# A comprehensive system monitoring tool with advanced features

# Configuration
REFRESH_INTERVAL=2
SHOW_PROCESSES=5
SHOW_PER_CORE=0
SHOW_GRAPHS=1
SHOW_TEMP=1
SHOW_DETAILED_DISK=0
SHOW_DETAILED_NET=0

# Thresholds
CPU_THRESHOLD=80
MEM_THRESHOLD=80
DISK_THRESHOLD=80
TEMP_THRESHOLD=80

# History arrays for graphing
CPU_HISTORY=()
MEM_HISTORY=()
NET_RX_HISTORY=()
NET_TX_HISTORY=()

# Log file
LOG_FILE=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Check for required tools
check_tools() {
    local missing=0
    
    for tool in vmstat iostat free ps; do
        if ! command -v "$tool" &> /dev/null; then
            echo "Error: $tool not found. Install sysstat and procps packages."
            missing=1
        fi
    done
    
    return $missing
}

# Get per-core CPU usage
get_per_core_cpu() {
    mpstat -P ALL 1 1 2>/dev/null | awk '
    /^[0-9]/ && !/Average/ {
        cpu=$2
        idle=$NF
        used=100-idle
        printf "%s:%.0f ", cpu, used
    }'
}

# Get top CPU consuming processes
get_top_cpu_processes() {
    local count=${1:-5}
    ps aux --sort=-%cpu | head -n $((count + 1)) | tail -n $count | awk '{
        printf "%-8s %5s %5s %-20s\n", $2, $3, $4, substr($11, 1, 20)
    }'
}

# Get top memory consuming processes
get_top_mem_processes() {
    local count=${1:-5}
    ps aux --sort=-%mem | head -n $((count + 1)) | tail -n $count | awk '{
        printf "%-8s %5s %5s %-20s\n", $2, $3, $4, substr($11, 1, 20)
    }'
}

# Get CPU temperature
get_cpu_temp() {
    local temp=0
    local count=0
    
    # Try reading from thermal zones
    for zone in /sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            local t=$(cat "$zone" 2>/dev/null)
            if [ -n "$t" ] && [ "$t" -gt 0 ]; then
                temp=$((temp + t / 1000))
                count=$((count + 1))
            fi
        fi
    done
    
    if [ $count -gt 0 ]; then
        echo $((temp / count))
    else
        echo "N/A"
    fi
}

# Get detailed disk stats
get_disk_stats_detailed() {
    iostat -dx 1 2 | awk '
    BEGIN {print "DEVICE READS WRITES R_MB/s W_MB/s UTIL%"}
    /^[sv]d[a-z]|^nvme/ {
        if (NR > header && $1 != "") {
            printf "%-10s %6.0f %6.0f %7.2f %7.2f %5.1f\n", 
                $1, $4, $5, $6/1024, $7/1024, $NF
        }
    }
    /^Device/ {header = NR}'
}

# Get per-interface network stats
get_network_detailed() {
    echo "INTERFACE RX_BYTES TX_BYTES RX_PKT TX_PKT"
    for iface in /sys/class/net/*; do
        local name=$(basename "$iface")
        if [[ "$name" != "lo" ]] && [[ "$name" != "docker"* ]] && [[ "$name" != "veth"* ]]; then
            if [ -f "$iface/statistics/rx_bytes" ]; then
                local rx_bytes=$(cat "$iface/statistics/rx_bytes" 2>/dev/null || echo 0)
                local tx_bytes=$(cat "$iface/statistics/tx_bytes" 2>/dev/null || echo 0)
                local rx_packets=$(cat "$iface/statistics/rx_packets" 2>/dev/null || echo 0)
                local tx_packets=$(cat "$iface/statistics/tx_packets" 2>/dev/null || echo 0)
                
                printf "%-10s %10s %10s %8s %8s\n" \
                    "$name" \
                    "$(format_bytes $rx_bytes)" \
                    "$(format_bytes $tx_bytes)" \
                    "$rx_packets" \
                    "$tx_packets"
            fi
        fi
    done
}

# Format bytes to human-readable
format_bytes() {
    local bytes=$1
    
    if [ -z "$bytes" ] || [ "$bytes" -eq 0 ]; then
        echo "0B"
        return
    fi
    
    local gb=$((bytes / 1024 / 1024 / 1024))
    local mb=$((bytes / 1024 / 1024 % 1024))
    local kb=$((bytes / 1024 % 1024))
    
    if [ $gb -gt 0 ]; then
        echo "${gb}GB"
    elif [ $mb -gt 0 ]; then
        echo "${mb}MB"
    else
        echo "${kb}KB"
    fi
}

# Draw ASCII graph
draw_graph() {
    local title=$1
    shift
    local values=("$@")
    local max_val=1
    local graph_height=10
    local graph_width=${#values[@]}
    
    # Find max value
    for val in "${values[@]}"; do
        [ "$val" -gt "$max_val" ] && max_val=$val
    done
    
    # Normalize to 0-100 range if needed
    if [ "$max_val" -gt 100 ]; then
        local scale=$((max_val / 100 + 1))
    else
        local scale=1
    fi
    
    echo -e "\n${CYAN}${title}${NC} (Last ${graph_width} samples)"
    
    # Draw graph lines
    for ((h=graph_height; h>=0; h--)); do
        local threshold=$((h * 10))
        printf "%3d%% " $threshold
        
        for val in "${values[@]}"; do
            local scaled=$((val / scale))
            if [ "$scaled" -ge "$threshold" ]; then
                if [ "$scaled" -ge 80 ]; then
                    echo -n "${RED}█${NC}"
                elif [ "$scaled" -ge 60 ]; then
                    echo -n "${YELLOW}█${NC}"
                else
                    echo -n "${GREEN}█${NC}"
                fi
            else
                echo -n " "
            fi
        done
        echo
    done
    
    # Draw baseline
    printf "     "
    for ((i=0; i<graph_width; i++)); do
        echo -n "─"
    done
    echo
}

# Check thresholds and generate alerts
check_thresholds() {
    local alerts=()
    
    [ "${cpu_usage:-0}" -gt "$CPU_THRESHOLD" ] && \
        alerts+=("${RED}⚠${NC} CPU usage: ${cpu_usage}% (threshold: ${CPU_THRESHOLD}%)")
    
    [ "${mem_usage:-0}" -gt "$MEM_THRESHOLD" ] && \
        alerts+=("${RED}⚠${NC} Memory usage: ${mem_usage}% (threshold: ${MEM_THRESHOLD}%)")
    
    if [ "$SHOW_TEMP" -eq 1 ] && [ "$cpu_temp" != "N/A" ]; then
        [ "${cpu_temp:-0}" -gt "$TEMP_THRESHOLD" ] && \
            alerts+=("${RED}⚠${NC} CPU temperature: ${cpu_temp}°C (threshold: ${TEMP_THRESHOLD}°C)")
    fi
    
    if [ ${#alerts[@]} -gt 0 ]; then
        echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${RED}                 ALERTS                   ${NC}"
        echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        for alert in "${alerts[@]}"; do
            echo -e "  $alert"
        done
        
        # Log alerts if logging is enabled
        if [ -n "$LOG_FILE" ]; then
            for alert in "${alerts[@]}"; do
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] ALERT: $alert" | sed 's/\x1b\[[0-9;]*m//g' >> "$LOG_FILE"
            done
        fi
    fi
}

# Log stats to file
log_stats() {
    [ -z "$LOG_FILE" ] && return
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp,CPU:${cpu_usage}%,MEM:${mem_usage}%,TEMP:${cpu_temp}°C,RX:${net_rx_rate},TX:${net_tx_rate}" >> "$LOG_FILE"
}

# Get CPU usage from vmstat
get_cpu_stats() {
    # vmstat output: r b swpd free buff cache si so bi bo in cs us sy id wa st
    vmstat 1 2 | tail -1 | awk '{
        printf "%d %d %d %d %d", $13, $14, $15, $16, $17
    }'
}

# Get memory usage
get_memory_stats() {
    free -m | awk '
    /^Mem:/ {
        total=$2
        used=$3
        free=$4
        available=$7
        percent=int((used/total)*100)
        printf "%d %d %d %d %d", total, used, free, available, percent
    }'
}

# Get disk I/O stats
get_disk_io() {
    iostat -dx 1 2 | awk '
    /^[sv]d[a-z]|^nvme/ {
        if (NR > header) {
            reads += $4
            writes += $5
            read_mb += $6/1024
            write_mb += $7/1024
        }
    }
    /^Device/ {header = NR}
    END {
        printf "%.2f %.2f %.2f %.2f", reads, writes, read_mb, write_mb
    }'
}

# Get network I/O stats
get_network_io() {
    local rx_bytes=0
    local tx_bytes=0
    
    for iface in /sys/class/net/*; do
        local name=$(basename "$iface")
        # Skip loopback and virtual interfaces
        if [[ "$name" != "lo" ]] && [[ "$name" != "docker"* ]] && [[ "$name" != "veth"* ]]; then
            if [ -f "$iface/statistics/rx_bytes" ] && [ -f "$iface/statistics/tx_bytes" ]; then
                rx_bytes=$((rx_bytes + $(cat "$iface/statistics/rx_bytes" 2>/dev/null || echo 0)))
                tx_bytes=$((tx_bytes + $(cat "$iface/statistics/tx_bytes" 2>/dev/null || echo 0)))
            fi
        fi
    done
    
    echo "$rx_bytes $tx_bytes"
}

# Calculate rate (delta per second)
calculate_rate() {
    local current=$1
    local previous=$2
    local interval=$3
    
    if [ -z "$previous" ] || [ "$previous" = "0" ]; then
        echo "0"
    else
        echo $(( (current - previous) / interval ))
    fi
}

# Format bytes to human readable rate
format_bytes_rate() {
    local bytes=$1
    
    if [ "$bytes" -lt 1024 ]; then
        echo "${bytes}B/s"
    elif [ "$bytes" -lt $((1024*1024)) ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1024}")KB/s"
    elif [ "$bytes" -lt $((1024*1024*1024)) ]; then
        echo "$(awk "BEGIN {printf \"%.1f\", $bytes/1024/1024}")MB/s"
    else
        echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024/1024/1024}")GB/s"
    fi
}

# Draw progress bar
draw_bar() {
    local percent=$1
    local width=40
    local filled=$((percent * width / 100))
    local empty=$((width - filled))
    
    # Choose color based on percentage
    local color=$GREEN
    [ "$percent" -ge 60 ] && color=$YELLOW
    [ "$percent" -ge 80 ] && color=$RED
    
    echo -n "["
    echo -n "${color}"
    for ((i=0; i<filled; i++)); do echo -n "█"; done
    echo -n "${NC}"
    for ((i=0; i<empty; i++)); do echo -n "░"; done
    echo -n "]"
    printf " %3d%%" "$percent"
}

# Clear screen and draw header
draw_header() {
    clear
    echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${CYAN}║              Real-Time Performance Monitor v2.0                        ║${NC}"
    echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BOLD}Host:${NC} $(hostname)  ${BOLD}|${NC}  ${BOLD}Time:${NC} $(date '+%Y-%m-%d %H:%M:%S')  ${BOLD}|${NC}  ${BOLD}Uptime:${NC} $(uptime -p)"
    echo ""
}

# Main monitoring loop
monitor() {
    local prev_rx=0
    local prev_tx=0
    local prev_time=$(date +%s)
    local iteration=0
    
    check_tools || exit 1
    
    # Initialize history arrays
    CPU_HISTORY=()
    MEM_HISTORY=()
    NET_RX_HISTORY=()
    NET_TX_HISTORY=()
    
    # Trap Ctrl+C for clean exit
    trap 'echo -e "\n${CYAN}Monitoring stopped.${NC}"; [ -n "$LOG_FILE" ] && echo "Log saved to: $LOG_FILE"; exit 0' INT TERM
    
    while true; do
        draw_header
        
        # Get current time
        local current_time=$(date +%s)
        local time_delta=$((current_time - prev_time))
        [ $time_delta -eq 0 ] && time_delta=1
        
        # CPU Statistics
        echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}CPU Usage:${NC}"
        read cpu_us cpu_sy cpu_id cpu_wa cpu_st <<< $(get_cpu_stats)
        
        cpu_usage=$((100 - cpu_id))
        echo -ne "  Overall:   "
        draw_bar $cpu_usage
        echo ""
        echo -e "  User:      ${cpu_us}%  |  System: ${cpu_sy}%  |  Idle: ${cpu_id}%  |  I/O Wait: ${cpu_wa}%"
        
        # Per-core CPU usage (if enabled)
        if [ "$SHOW_PER_CORE" -eq 1 ] && command -v mpstat &>/dev/null; then
            echo ""
            echo -e "${BOLD}Per-Core Usage:${NC}"
            local core_stats=$(get_per_core_cpu)
            local col=0
            for core_data in $core_stats; do
                local core=$(echo "$core_data" | cut -d: -f1)
                local usage=$(echo "$core_data" | cut -d: -f2)
                printf "  CPU%-2s: %3s%% " "$core" "$usage"
                col=$((col + 1))
                [ $col -eq 4 ] && { echo ""; col=0; }
            done
            [ $col -ne 0 ] && echo ""
        fi
        
        # Temperature (if enabled)
        if [ "$SHOW_TEMP" -eq 1 ]; then
            cpu_temp=$(get_cpu_temp)
            if [ "$cpu_temp" != "N/A" ]; then
                echo ""
                echo -ne "  Temperature: "
                if [ "$cpu_temp" -gt 80 ]; then
                    echo -e "${RED}${cpu_temp}°C [HOT]${NC}"
                elif [ "$cpu_temp" -gt 60 ]; then
                    echo -e "${YELLOW}${cpu_temp}°C [WARM]${NC}"
                else
                    echo -e "${GREEN}${cpu_temp}°C [NORMAL]${NC}"
                fi
            fi
        fi
        
        # Memory Statistics
        echo ""
        echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}Memory Usage:${NC}"
        read mem_total mem_used mem_free mem_avail mem_percent <<< $(get_memory_stats)
        
        mem_usage=$mem_percent
        echo -ne "  Memory:    "
        draw_bar $mem_percent
        echo ""
        echo -e "  Total: ${mem_total}MB  |  Used: ${mem_used}MB  |  Free: ${mem_free}MB  |  Available: ${mem_avail}MB"
        
        # Top Processes (if enabled)
        if [ "$SHOW_PROCESSES" -gt 0 ]; then
            echo ""
            echo -e "${BOLD}Top ${SHOW_PROCESSES} CPU Consumers:${NC}"
            echo -e "  ${BOLD}PID      %CPU  %MEM  COMMAND${NC}"
            get_top_cpu_processes $SHOW_PROCESSES | while read line; do
                echo "  $line"
            done
            
            echo ""
            echo -e "${BOLD}Top ${SHOW_PROCESSES} Memory Consumers:${NC}"
            echo -e "  ${BOLD}PID      %CPU  %MEM  COMMAND${NC}"
            get_top_mem_processes $SHOW_PROCESSES | while read line; do
                echo "  $line"
            done
        fi
        
        # Disk I/O Statistics
        echo ""
        echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}Disk I/O:${NC}"
        
        if [ "$SHOW_DETAILED_DISK" -eq 1 ]; then
            get_disk_stats_detailed | while read line; do
                if [[ "$line" == "DEVICE"* ]]; then
                    echo -e "  ${BOLD}$line${NC}"
                else
                    echo "  $line"
                fi
            done
        else
            read disk_r disk_w disk_rmb disk_wmb <<< $(get_disk_io)
            printf "  Reads:     %.0f IOPS  |  %.2f MB/s\n" "$disk_r" "$disk_rmb"
            printf "  Writes:    %.0f IOPS  |  %.2f MB/s\n" "$disk_w" "$disk_wmb"
        fi
        
        # Network I/O Statistics
        echo ""
        echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BOLD}Network I/O:${NC}"
        
        if [ "$SHOW_DETAILED_NET" -eq 1 ]; then
            get_network_detailed | while read line; do
                if [[ "$line" == "INTERFACE"* ]]; then
                    echo -e "  ${BOLD}$line${NC}"
                else
                    echo "  $line"
                fi
            done
        else
            read current_rx current_tx <<< $(get_network_io)
            
            if [ $prev_rx -gt 0 ]; then
                local rx_rate=$(calculate_rate $current_rx $prev_rx $time_delta)
                local tx_rate=$(calculate_rate $current_tx $prev_tx $time_delta)
                
                net_rx_rate=$(format_bytes_rate $rx_rate)
                net_tx_rate=$(format_bytes_rate $tx_rate)
                
                echo -e "  RX: $net_rx_rate  |  TX: $net_tx_rate"
                echo -e "  Total RX: $(format_bytes $current_rx)  |  Total TX: $(format_bytes $current_tx)"
                
                # Store rates for history
                NET_RX_HISTORY+=($((rx_rate / 1024 / 1024)))  # MB/s
                NET_TX_HISTORY+=($((tx_rate / 1024 / 1024)))  # MB/s
            else
                echo -e "  Initializing network statistics..."
            fi
            
            prev_rx=$current_rx
            prev_tx=$current_tx
        fi
        
        prev_time=$current_time
        
        # Store history (keep last 50 samples)
        CPU_HISTORY+=($cpu_usage)
        MEM_HISTORY+=($mem_usage)
        [ ${#CPU_HISTORY[@]} -gt 50 ] && CPU_HISTORY=("${CPU_HISTORY[@]:1}")
        [ ${#MEM_HISTORY[@]} -gt 50 ] && MEM_HISTORY=("${MEM_HISTORY[@]:1}")
        [ ${#NET_RX_HISTORY[@]} -gt 50 ] && NET_RX_HISTORY=("${NET_RX_HISTORY[@]:1}")
        [ ${#NET_TX_HISTORY[@]} -gt 50 ] && NET_TX_HISTORY=("${NET_TX_HISTORY[@]:1}")
        
        # Show graphs (if enabled and enough data)
        if [ "$SHOW_GRAPHS" -eq 1 ] && [ ${#CPU_HISTORY[@]} -gt 10 ]; then
            draw_graph "CPU Usage Trend" "${CPU_HISTORY[@]}"
            draw_graph "Memory Usage Trend" "${MEM_HISTORY[@]}"
        fi
        
        # Check thresholds and show alerts
        check_thresholds
        
        # Log stats to file
        log_stats
        
        # Footer
        echo ""
        echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${CYAN}Press Ctrl+C to stop monitoring${NC}  |  Refresh: ${REFRESH_INTERVAL}s  |  Iteration: $((++iteration))"
        [ -n "$LOG_FILE" ] && echo -e "Logging to: ${LOG_FILE}"
        
        sleep $REFRESH_INTERVAL
    done
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Real-Time Performance Monitor v2.0 - Comprehensive system statistics

OPTIONS:
    -h, --help                Show this help message
    -i, --interval SECONDS    Set refresh interval (default: 2)
    -p, --processes N         Show top N processes (default: 5, 0 to disable)
    -c, --per-core            Show per-core CPU usage
    -t, --temperature         Show CPU temperature
    -g, --graphs              Show historical graphs
    -d, --detailed-disk       Show per-disk statistics
    -n, --detailed-net        Show per-interface network statistics
    -l, --log FILE            Log statistics to file
    --cpu-threshold N         CPU alert threshold (default: 80%)
    --mem-threshold N         Memory alert threshold (default: 80%)
    --temp-threshold N        Temperature alert threshold (default: 80°C)

EXAMPLES:
    $0                                    # Basic monitoring
    $0 -i 1 -p 10 -c -t -g                # Full monitoring with 1s refresh
    $0 -d -n                              # Detailed disk and network stats
    $0 -l /tmp/perfmon.log --cpu-threshold 90  # With logging and custom threshold

FEATURES:
    • Real-time CPU, memory, disk, and network statistics
    • Per-core CPU usage monitoring
    • Temperature monitoring from thermal sensors
    • Top process tracking (CPU and memory consumers)
    • Historical ASCII graphs with color-coded values
    • Alert system with configurable thresholds
    • Detailed per-device disk and network statistics
    • CSV logging capability
    • Color-coded progress bars and visual indicators

EOF
    exit 0
}

# Parse arguments
while [ $# -gt 0 ]; do
    case $1 in
        -h|--help)
            usage
            ;;
        -i|--interval)
            shift
            REFRESH_INTERVAL=$1
            ;;
        -p|--processes)
            shift
            SHOW_PROCESSES=$1
            ;;
        -c|--per-core)
            SHOW_PER_CORE=1
            ;;
        -t|--temperature)
            SHOW_TEMP=1
            ;;
        -g|--graphs)
            SHOW_GRAPHS=1
            ;;
        -d|--detailed-disk)
            SHOW_DETAILED_DISK=1
            ;;
        -n|--detailed-net)
            SHOW_DETAILED_NET=1
            ;;
        -l|--log)
            shift
            LOG_FILE=$1
            # Initialize log file with header
            echo "timestamp,cpu,memory,temperature,rx_rate,tx_rate" > "$LOG_FILE"
            ;;
        --cpu-threshold)
            shift
            CPU_THRESHOLD=$1
            ;;
        --mem-threshold)
            shift
            MEM_THRESHOLD=$1
            ;;
        --temp-threshold)
            shift
            TEMP_THRESHOLD=$1
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
    shift
done

# Start monitoring
monitor
