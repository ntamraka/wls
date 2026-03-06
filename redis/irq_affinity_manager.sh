#!/bin/bash

# IRQ Affinity Manager for High-Performance Redis Benchmarking
# Author: Enhanced version of irq_dmr.sh
# Purpose: Distribute network device IRQs across specified CPU segments
# Usage: ./irq_affinity_manager.sh <segments> <cpus_per_segment> [pci_device]

set -euo pipefail

# Configuration
readonly SCRIPT_NAME=$(basename "$0")
readonly SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
readonly LOG_PREFIX="[IRQ-MGR]"

# Default values
readonly DEFAULT_PCI_DEVICE="b1:00.0"
readonly DEFAULT_SEGMENT_SIZE=56  # CPUs per NUMA node/segment
readonly MIN_CPUS_PER_SEGMENT=1
readonly MAX_CPUS_PER_SEGMENT=56

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Global variables
declare -a CPU_LIST=()
declare -a IRQ_LIST=()
PCI_DEVICE="${DEFAULT_PCI_DEVICE}"

#######################################
# Logging functions
#######################################
log_info() {
    echo -e "${BLUE}${LOG_PREFIX} INFO:${NC} $*" >&2
}

log_warn() {
    echo -e "${YELLOW}${LOG_PREFIX} WARN:${NC} $*" >&2
}

log_error() {
    echo -e "${RED}${LOG_PREFIX} ERROR:${NC} $*" >&2
}

log_success() {
    echo -e "${GREEN}${LOG_PREFIX} SUCCESS:${NC} $*" >&2
}

#######################################
# Usage and validation functions
#######################################
show_usage() {
    cat << EOF
Usage: $SCRIPT_NAME <segments> <cpus_per_segment> [pci_device]

Arguments:
  segments           Space-separated segment numbers (e.g., "0 1 2 3")
  cpus_per_segment   Number of CPUs to use per segment (1-${MAX_CPUS_PER_SEGMENT})
  pci_device         Optional PCI device (default: ${DEFAULT_PCI_DEVICE})

Examples:
  $SCRIPT_NAME "0 1 2 3" 14                    # Use segments 0-3, 14 CPUs each
  $SCRIPT_NAME "1 2" 28                        # Use segments 1-2, 28 CPUs each  
  $SCRIPT_NAME "0 2" 7 "2a:00.0"              # Custom PCI device
  
Segment Layout (224-core system):
  Segment 0: CPUs 0-55    (NUMA node 0)
  Segment 1: CPUs 56-111  (NUMA node 1)
  Segment 2: CPUs 112-167 (NUMA node 2)
  Segment 3: CPUs 168-223 (NUMA node 3)
EOF
}

validate_inputs() {
    local segments="$1"
    local cpus_per_segment="$2"
    
    # Validate segments format
    if [[ ! "$segments" =~ ^[0-9\ ]+$ ]]; then
        log_error "Invalid segments format: '$segments'. Use space-separated numbers."
        return 1
    fi
    
    # Validate cpus_per_segment is numeric
    if ! [[ "$cpus_per_segment" =~ ^[0-9]+$ ]]; then
        log_error "CPUs per segment must be a number: '$cpus_per_segment'"
        return 1
    fi
    
    # Validate cpus_per_segment range
    if (( cpus_per_segment < MIN_CPUS_PER_SEGMENT || cpus_per_segment > MAX_CPUS_PER_SEGMENT )); then
        log_error "CPUs per segment must be between $MIN_CPUS_PER_SEGMENT and $MAX_CPUS_PER_SEGMENT"
        return 1
    fi
    
    # Validate PCI device format
    if [[ ! "$PCI_DEVICE" =~ ^[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]$ ]]; then
        log_error "Invalid PCI device format: '$PCI_DEVICE'. Expected format: XX:XX.X"
        return 1
    fi
    
    return 0
}

#######################################
# IRQ discovery and CPU management
#######################################
discover_irqs() {
    log_info "Discovering IRQs for PCI device: $PCI_DEVICE"
    
    local irq_nums
    irq_nums=$(grep "$PCI_DEVICE" /proc/interrupts 2>/dev/null | cut -d: -f1 | tr -d ' ' || true)
    
    if [[ -z "$irq_nums" ]]; then
        log_error "No IRQs found for PCI device $PCI_DEVICE"
        log_info "Available PCI devices with IRQs:"
        grep -E "^[[:space:]]*[0-9]+:" /proc/interrupts | grep -E "[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]" | head -5 || true
        return 1
    fi
    
    # Convert to array
    readarray -t IRQ_LIST <<< "$irq_nums"
    
    log_info "Found ${#IRQ_LIST[@]} IRQ(s): ${IRQ_LIST[*]}"
    return 0
}

build_cpu_layout() {
    local segments="$1"
    local cpus_per_segment="$2"
    
    log_info "Building CPU layout..."
    
    # Convert segments string to array
    local -a segment_array
    read -ra segment_array <<< "$segments"
    
    CPU_LIST=()
    
    echo
    echo "======================================================================"
    echo " CPU Segment Layout"
    echo "======================================================================"
    printf "%-10s %-15s %-15s %-10s\n" "Segment" "CPU Range" "NUMA Info" "Count"
    echo "----------------------------------------------------------------------"
    
    for segment in "${segment_array[@]}"; do
        local base_cpu=$((segment * DEFAULT_SEGMENT_SIZE))
        local start_cpu=$base_cpu
        local end_cpu=$((base_cpu + cpus_per_segment - 1))
        
        # Validate CPU range
        local available_cpus
        available_cpus=$(nproc)
        if (( end_cpu >= available_cpus )); then
            log_warn "CPU $end_cpu exceeds available CPUs ($available_cpus). Adjusting..."
            end_cpu=$((available_cpus - 1))
        fi
        
        # Get NUMA node info if available
        local numa_node="N/A"
        if command -v numactl >/dev/null 2>&1; then
            numa_node=$(numactl -H 2>/dev/null | grep "node $segment cpus:" | cut -d: -f2 | wc -w || echo "N/A")
        fi
        
        printf "%-10s %-15s %-15s %-10s\n" "$segment" "$start_cpu-$end_cpu" "Node $numa_node" "$cpus_per_segment"
        
        # Add CPUs to list
        for ((i=0; i<cpus_per_segment; i++)); do
            local cpu=$((base_cpu + i))
            if (( cpu < available_cpus )); then
                CPU_LIST+=("$cpu")
            fi
        done
    done
    
    echo "----------------------------------------------------------------------"
    echo "Total CPUs selected: ${#CPU_LIST[@]}"
    echo "======================================================================"
    echo
}

#######################################
# IRQ affinity application
#######################################
apply_irq_affinity() {
    log_info "Applying IRQ to CPU affinity mappings..."
    
    if (( ${#CPU_LIST[@]} == 0 )); then
        log_error "No CPUs available for IRQ mapping"
        return 1
    fi
    
    if (( ${#IRQ_LIST[@]} == 0 )); then
        log_error "No IRQs available for mapping"
        return 1
    fi
    
    echo
    echo "======================================================================"
    echo " IRQ Affinity Mapping"
    echo "======================================================================"
    printf "%-8s %-8s %-20s %-10s\n" "IRQ" "CPU" "Affinity File" "Status"
    echo "----------------------------------------------------------------------"
    
    local cpu_index=0
    local total_cpus=${#CPU_LIST[@]}
    local success_count=0
    
    for irq in "${IRQ_LIST[@]}"; do
        local cpu=${CPU_LIST[$((cpu_index % total_cpus))]}
        local affinity_file="/proc/irq/$irq/smp_affinity_list"
        local status="FAILED"
        
        if [[ -w "$affinity_file" ]]; then
            if echo "$cpu" > "$affinity_file" 2>/dev/null; then
                status="OK"
                ((success_count++))
            fi
        else
            log_warn "Cannot write to $affinity_file (permissions or file not found)"
        fi
        
        printf "%-8s %-8s %-20s %-10s\n" "$irq" "$cpu" "$affinity_file" "$status"
        ((cpu_index++))
    done
    
    echo "----------------------------------------------------------------------"
    echo "Successful mappings: $success_count/${#IRQ_LIST[@]}"
    echo "======================================================================"
    echo
    
    if (( success_count == ${#IRQ_LIST[@]} )); then
        log_success "All IRQ affinity mappings applied successfully"
        return 0
    else
        log_warn "Some IRQ affinity mappings failed"
        return 1
    fi
}

#######################################
# System information and verification
#######################################
show_system_info() {
    log_info "System Information:"
    echo "  - Available CPUs: $(nproc)"
    echo "  - PCI Device: $PCI_DEVICE"
    echo "  - Architecture: $(uname -m)"
    
    if command -v numactl >/dev/null 2>&1; then
        echo "  - NUMA Nodes: $(numactl -H 2>/dev/null | grep "available:" | awk '{print $2}' || echo "Unknown")"
    fi
    echo
}

verify_affinity() {
    log_info "Verifying current IRQ affinity settings..."
    
    for irq in "${IRQ_LIST[@]}"; do
        local affinity_file="/proc/irq/$irq/smp_affinity_list"
        if [[ -r "$affinity_file" ]]; then
            local current_affinity
            current_affinity=$(cat "$affinity_file" 2>/dev/null || echo "N/A")
            echo "  IRQ $irq -> CPUs: $current_affinity"
        fi
    done
    echo
}

#######################################
# Main function
#######################################
main() {
    local segments="$1"
    local cpus_per_segment="$2"
    local pci_device="${3:-$DEFAULT_PCI_DEVICE}"
    
    # Set PCI device
    PCI_DEVICE="$pci_device"
    
    echo
    echo "██████╗ ███████╗██████╗ ██╗███████╗    ██╗██████╗  ██████╗ "
    echo "██╔══██╗██╔════╝██╔══██╗██║██╔════╝    ██║██╔══██╗██╔═══██╗"
    echo "██████╔╝█████╗  ██║  ██║██║███████╗    ██║██████╔╝██║   ██║"
    echo "██╔══██╗██╔══╝  ██║  ██║██║╚════██║    ██║██╔══██╗██║▄▄ ██║"
    echo "██║  ██║███████╗██████╔╝██║███████║    ██║██║  ██║╚██████╔╝"
    echo "╚═╝  ╚═╝╚══════╝╚═════╝ ╚═╝╚══════╝    ╚═╝╚═╝  ╚═╝ ╚══▀▀═╝ "
    echo
    echo "           High-Performance IRQ Affinity Manager"
    echo "======================================================================"
    
    # Validate inputs
    if ! validate_inputs "$segments" "$cpus_per_segment"; then
        echo
        show_usage
        exit 1
    fi
    
    # Show system information
    show_system_info
    
    # Discover IRQs  
    if ! discover_irqs; then
        exit 1
    fi
    
    # Build CPU layout
    build_cpu_layout "$segments" "$cpus_per_segment"
    
    # Apply IRQ affinity
    if apply_irq_affinity; then
        verify_affinity
        log_success "IRQ affinity tuning completed successfully!"
    else
        log_error "IRQ affinity tuning completed with errors"
        exit 1
    fi
}

#######################################
# Script entry point
#######################################
if (( $# < 2 || $# > 3 )); then
    echo "Error: Invalid number of arguments"
    echo
    show_usage
    exit 1
fi

# Check if running as root (required for IRQ affinity changes)
if (( EUID != 0 )); then
    log_error "This script must be run as root (IRQ affinity modification requires root privileges)"
    exit 1
fi

# Execute main function
main "$@"