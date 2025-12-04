
#!/bin/bash
# ==============================================================================
# Redis/Memtier System Performance Tuning Script
# ==============================================================================
# Purpose:
#   - Optimize CPU frequency for consistent performance
#   - Enable network packet steering (RPS/XPS) across all CPUs
#   - Distribute network IRQs across NUMA nodes
#   - Backup all settings for safe revert
#
# Usage:
#   sudo ./tuning.sh [apply|revert|status]
#
# Requirements:
#   - Root privileges
#   - Network interface must exist
# ==============================================================================

set -e  # Exit on error

# ==============================================================================
# Configuration
# ==============================================================================
BACKUP_DIR="/tmp/sys_tuning_backup"
NIC_NAME="ens6np0"
PCI_DEVICE="34:00.0"

# CPU mask for RPS/XPS (all CPUs enabled)
CPU_MASK="ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# Helper Functions
# ==============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_nic_exists() {
    if [[ ! -d "/sys/class/net/$NIC_NAME" ]]; then
        log_error "Network interface $NIC_NAME not found"
        log_info "Available interfaces: $(ls /sys/class/net/)"
        exit 1
    fi
}

# ==============================================================================
# Backup Functions
# ==============================================================================

backup_settings() {
    mkdir -p "$BACKUP_DIR"
    log_info "Backing up current settings to $BACKUP_DIR"
    
    # Backup CPU governors
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null; do
        if [[ -f "$cpu" ]]; then
            CPU_NAME=$(basename $(dirname "$cpu"))
            cat "$cpu" > "$BACKUP_DIR/${CPU_NAME}_governor.bak"
        fi
    done
    
    # Backup RPS settings
    for q in /sys/class/net/$NIC_NAME/queues/rx-* 2>/dev/null; do
        if [[ -d "$q" ]]; then
            QUEUE=$(basename "$q")
            cat "$q/rps_cpus" > "$BACKUP_DIR/${QUEUE}_rps.bak" 2>/dev/null || true
        fi
    done
    
    # Backup XPS settings
    for q in /sys/class/net/$NIC_NAME/queues/tx-* 2>/dev/null; do
        if [[ -d "$q" ]]; then
            QUEUE=$(basename "$q")
            cat "$q/xps_cpus" > "$BACKUP_DIR/${QUEUE}_xps.bak" 2>/dev/null || true
        fi
    done
    
    # Backup IRQ affinities
    IRQ_NUMS=$(grep "$PCI_DEVICE" /proc/interrupts 2>/dev/null | cut -d: -f1 | tr -d ' ' || true)
    if [[ -n "$IRQ_NUMS" ]]; then
        for irq in $IRQ_NUMS; do
            if [[ -f "/proc/irq/${irq}/smp_affinity_list" ]]; then
                cat "/proc/irq/${irq}/smp_affinity_list" > "$BACKUP_DIR/irq_${irq}.bak"
            fi
        done
    fi
    
    log_success "Backup completed"
}

# ==============================================================================
# CPU Tuning
# ==============================================================================

tune_cpu_governor() {
    log_info "Setting CPU frequency governor to 'performance'"
    
    local count=0
    for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null; do
        if [[ -f "$cpu" ]]; then
            CPU_NAME=$(basename $(dirname "$cpu"))
            CURRENT=$(cat "$cpu")
            
            if [[ "$CURRENT" != "performance" ]]; then
                echo performance > "$cpu" 2>/dev/null || log_warning "Failed to set $CPU_NAME"
                ((count++))
            fi
        fi
    done
    
    log_success "Set $count CPUs to performance mode"
}

# ==============================================================================
# Network Tuning
# ==============================================================================

tune_network_queues() {
    log_info "Checking network interface: $NIC_NAME"
    
    RX_Q=$(ls -d /sys/class/net/$NIC_NAME/queues/rx-* 2>/dev/null | wc -l)
    TX_Q=$(ls -d /sys/class/net/$NIC_NAME/queues/tx-* 2>/dev/null | wc -l)
    
    log_info "RX queues: $RX_Q"
    log_info "TX queues: $TX_Q"
    
    if [[ $RX_Q -eq 0 ]] || [[ $TX_Q -eq 0 ]]; then
        log_warning "No queues found for $NIC_NAME"
        return 1
    fi
    
    # Enable RPS (Receive Packet Steering)
    log_info "Enabling RPS on all RX queues"
    for q in /sys/class/net/$NIC_NAME/queues/rx-*; do
        if [[ -d "$q" ]] && [[ -f "$q/rps_cpus" ]]; then
            echo "$CPU_MASK" > "$q/rps_cpus" 2>/dev/null || \
                log_warning "Failed to set RPS for $(basename $q)"
        fi
    done
    log_success "RPS enabled"
    
    # Enable XPS (Transmit Packet Steering)
    log_info "Enabling XPS on all TX queues"
    for q in /sys/class/net/$NIC_NAME/queues/tx-*; do
        if [[ -d "$q" ]] && [[ -f "$q/xps_cpus" ]]; then
            echo "$CPU_MASK" > "$q/xps_cpus" 2>/dev/null || \
                log_warning "Failed to set XPS for $(basename $q)"
        fi
    done
    log_success "XPS enabled"
}

# ==============================================================================
# IRQ Tuning
# ==============================================================================

tune_irq_affinity() {
    log_info "Distributing IRQs for PCI device: $PCI_DEVICE"
    
    IRQ_NUMS=$(grep "$PCI_DEVICE" /proc/interrupts 2>/dev/null | cut -d: -f1 | tr -d ' ' || true)
    
    if [[ -z "$IRQ_NUMS" ]]; then
        log_warning "No IRQs found for PCI device $PCI_DEVICE"
        log_info "Available PCI devices in /proc/interrupts:"
        grep -oP '\d+:\d+\.\d+' /proc/interrupts | sort -u | head -10
        return 1
    fi
    
    log_info "Found IRQs: $IRQ_NUMS"
    
    local start_cpu=0
    local total_cpus=$(nproc)
    local irq_count=0
    
    for irq in $IRQ_NUMS; do
        if [[ ! -f "/proc/irq/${irq}/smp_affinity_list" ]]; then
            log_warning "IRQ $irq affinity file not found, skipping"
            continue
        fi
        
        # Distribute across NUMA nodes (assuming 96 CPUs per node)
        local c0=$((start_cpu % total_cpus))
        local c1=$(((start_cpu + 96) % total_cpus))
        local c2=$(((start_cpu + 192) % total_cpus))
        
        echo "$c0,$c1,$c2" > "/proc/irq/${irq}/smp_affinity_list" 2>/dev/null || \
            log_warning "Failed to set affinity for IRQ $irq"
        
        log_info "IRQ $irq -> CPUs $c0,$c1,$c2"
        ((irq_count++))
        ((start_cpu++))
    done
    
    log_success "Distributed $irq_count IRQs"
}

# ==============================================================================
# Revert Functions
# ==============================================================================

revert_settings() {
    if [[ ! -d "$BACKUP_DIR" ]]; then
        log_error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi
    
    log_info "Reverting settings from $BACKUP_DIR"
    
    # Revert CPU governors
    for backup in "$BACKUP_DIR"/*_governor.bak; do
        if [[ -f "$backup" ]]; then
            CPU_NAME=$(basename "$backup" _governor.bak)
            CPU_PATH="/sys/devices/system/cpu/$CPU_NAME/cpufreq/scaling_governor"
            if [[ -f "$CPU_PATH" ]]; then
                cat "$backup" > "$CPU_PATH" 2>/dev/null || \
                    log_warning "Failed to revert $CPU_NAME"
            fi
        fi
    done
    
    # Revert RPS
    for backup in "$BACKUP_DIR"/*_rps.bak; do
        if [[ -f "$backup" ]]; then
            QUEUE=$(basename "$backup" _rps.bak)
            RPS_PATH="/sys/class/net/$NIC_NAME/queues/$QUEUE/rps_cpus"
            if [[ -f "$RPS_PATH" ]]; then
                cat "$backup" > "$RPS_PATH" 2>/dev/null || true
            fi
        fi
    done
    
    # Revert XPS
    for backup in "$BACKUP_DIR"/*_xps.bak; do
        if [[ -f "$backup" ]]; then
            QUEUE=$(basename "$backup" _xps.bak)
            XPS_PATH="/sys/class/net/$NIC_NAME/queues/$QUEUE/xps_cpus"
            if [[ -f "$XPS_PATH" ]]; then
                cat "$backup" > "$XPS_PATH" 2>/dev/null || true
            fi
        fi
    done
    
    # Revert IRQ affinities
    for backup in "$BACKUP_DIR"/irq_*.bak; do
        if [[ -f "$backup" ]]; then
            IRQ=$(basename "$backup" .bak | cut -d_ -f2)
            IRQ_PATH="/proc/irq/${IRQ}/smp_affinity_list"
            if [[ -f "$IRQ_PATH" ]]; then
                cat "$backup" > "$IRQ_PATH" 2>/dev/null || \
                    log_warning "Failed to revert IRQ $IRQ"
            fi
        fi
    done
    
    log_success "Settings reverted successfully"
}

# ==============================================================================
# Status Functions
# ==============================================================================

show_status() {
    echo "=============================================="
    echo "Current System Tuning Status"
    echo "=============================================="
    
    # CPU Governor Status
    echo -e "\n${BLUE}CPU Governors:${NC}"
    local perf_count=$(grep -c "performance" /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null || echo 0)
    local total_cpus=$(ls /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | wc -l)
    echo "  Performance mode: $perf_count / $total_cpus CPUs"
    
    # Network Status
    if [[ -d "/sys/class/net/$NIC_NAME" ]]; then
        echo -e "\n${BLUE}Network Interface: $NIC_NAME${NC}"
        local rx_q=$(ls -d /sys/class/net/$NIC_NAME/queues/rx-* 2>/dev/null | wc -l)
        local tx_q=$(ls -d /sys/class/net/$NIC_NAME/queues/tx-* 2>/dev/null | wc -l)
        echo "  RX Queues: $rx_q"
        echo "  TX Queues: $tx_q"
        
        # Check if RPS is enabled
        local rps_enabled=0
        for q in /sys/class/net/$NIC_NAME/queues/rx-*; do
            if [[ -f "$q/rps_cpus" ]]; then
                local val=$(cat "$q/rps_cpus")
                if [[ "$val" != "00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000000" ]]; then
                    ((rps_enabled++))
                fi
            fi
        done
        echo "  RPS Enabled: $rps_enabled / $rx_q queues"
    else
        echo -e "\n${YELLOW}Network interface $NIC_NAME not found${NC}"
    fi
    
    # IRQ Status
    echo -e "\n${BLUE}IRQ Distribution:${NC}"
    local irq_nums=$(grep "$PCI_DEVICE" /proc/interrupts 2>/dev/null | cut -d: -f1 | tr -d ' ' || echo "")
    if [[ -n "$irq_nums" ]]; then
        local irq_count=$(echo "$irq_nums" | wc -w)
        echo "  IRQs for $PCI_DEVICE: $irq_count"
    else
        echo "  No IRQs found for $PCI_DEVICE"
    fi
    
    # Backup Status
    echo -e "\n${BLUE}Backup Status:${NC}"
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_count=$(ls -1 "$BACKUP_DIR" 2>/dev/null | wc -l)
        echo "  Backup exists: Yes ($backup_count files)"
    else
        echo "  Backup exists: No"
    fi
    
    echo -e "\n=============================================="
}

# ==============================================================================
# Main Execution
# ==============================================================================

main() {
    local action="${1:-apply}"
    
    case "$action" in
        apply)
            check_root
            check_nic_exists
            
            echo "=============================================="
            echo "  Redis/Memtier System Tuning"
            echo "=============================================="
            echo ""
            
            backup_settings
            echo ""
            
            tune_cpu_governor
            echo ""
            
            tune_network_queues
            echo ""
            
            tune_irq_affinity
            echo ""
            
            echo "=============================================="
            log_success "All tuning completed successfully"
            echo "=============================================="
            echo ""
            echo "To revert changes: sudo $0 revert"
            echo "To check status:   sudo $0 status"
            ;;
            
        revert)
            check_root
            revert_settings
            ;;
            
        status)
            show_status
            ;;
            
        *)
            echo "Usage: $0 {apply|revert|status}"
            echo ""
            echo "Commands:"
            echo "  apply   - Apply performance tuning (default)"
            echo "  revert  - Revert to backed up settings"
            echo "  status  - Show current tuning status"
            exit 1
            ;;
    esac
}

main "$@"

echo "==== 0. Backup current CPU governors ===="
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    CPU_NAME=$(basename $(dirname $cpu))
    CURRENT=$(cat "$cpu")
    echo "$CURRENT" > "$BACKUP_DIR/${CPU_NAME}_governor.bak"
done
echo "---- CPU governors backed up ----"
echo

echo "==== 1. Set CPU frequency governor to 'performance' ===="
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    CPU_NAME=$(basename $(dirname $cpu))
    echo "  -> Setting $CPU_NAME to performance"
    echo performance > "$cpu"
done
echo "---- CPU governors set to performance ----"
echo

echo "==== 2. Check NIC RX/TX queues ===="
RX_Q=$(ls -d /sys/class/net/ens6np0/queues/rx-* | wc -l)
TX_Q=$(ls -d /sys/class/net/ens6np0/queues/tx-* | wc -l)
echo "  -> ens6np0 RX queues: $RX_Q"
echo "  -> ens6np0 TX queues: $TX_Q"
echo

#MASK="00000000,0f0f0f0f,0f0f0f0f,00000000,0f0f0f0f,0f0f0f0f,00000000,0f0f0f0f,0f0f0f0f"
#MASK="00000000,00000000,00000000,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f"
#MASK="00000000,00000000,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff"
#MASK="0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f,0f0f0f0f"
#MASK="0000ffff,0000fff,0000ffff,0000fff,0000ffff,0000fff,0000ffff,0000fff,0000ffff"
#MASK="00000000,ffffffff,00000000,ffffffff,00000000,ffffffff,00000000,ffffffff,00000000"
#MASK="ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff"
#MASK="00000000,00000000,00000000,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff"
MASK="ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff,ffffffff"
#MASK="00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000000,00000000"

echo "==== 3. Backup & enable RPS on all RX queues ===="
for q in /sys/class/net/ens6np0/queues/rx-*; 
do
    QUEUE=$(basename $q)
    cp "$q/rps_cpus" "$BACKUP_DIR/${QUEUE}_rps.bak"
done


for q in /sys/class/net/ens6np0/queues/rx-*; 
do
    echo "  -> Applying full CPU mask to $(basename $q)/rps_cpus"
    echo "$MASK" > "$q/rps_cpus"
done
echo "---- RPS enabled ----"
echo

echo "==== 4. Backup & enable XPS on all TX queues ===="
for q in /sys/class/net/ens6np0/queues/tx-*; 
do
    QUEUE=$(basename $q)
    cp "$q/xps_cpus" "$BACKUP_DIR/${QUEUE}_xps.bak"
done

for q in /sys/class/net/ens6np0/queues/tx-*;
do
    echo "  -> Applying full CPU mask to $(basename $q)/xps_cpus"
    echo "$MASK" > "$q/xps_cpus"
done
echo "---- XPS enabled ----"
echo

echo "==== 5. Backup IRQ affinities for PCI device 34:00.0 ===="
IRQ_NUMS=$(grep "34:00.0" /proc/interrupts | cut -d: -f1 | tr -d ' ')
echo "  -> Found IRQs: $IRQ_NUMS"
for irq in $IRQ_NUMS; 
do  
echo $irq
    cat "/proc/irq/${irq}/smp_affinity_list" > "$BACKUP_DIR/irq_${irq}.bak"
done
echo "---- IRQ affinities backed up ----"
echo

echo "==== 6. Distribute IRQs across 4 CPUs each ===="
start_cpu=0
total_cpus=$(nproc)
for irq in $IRQ_NUMS; do
    c0=$((start_cpu % total_cpus))
    c1=$(((start_cpu + 96) % total_cpus))
    c2=$(((start_cpu + 192) % total_cpus))
    #echo "$c0,$c1,$c2" > "/proc/irq/${irq}/smp_affinity_list"
    #c3=$(((start_cpu + 192) % total_cpus))
    echo "  -> IRQ $irq -> CPUs $c0,$c1,$c2"
    #echo "$c0" > "/proc/irq/${irq}/smp_affinity_list"
    echo "$c0,$c1,$c2" > "/proc/irq/${irq}/smp_affinity_list"
    start_cpu=$((start_cpu + 1))
done
echo "---- IRQ affinities set ----"
echo

echo "==== All tuning complete ===="
echo "Backup of original settings saved in $BACKUP_DIR"
echo

#echo "==== Revert instructions ===="
#echo "To revert changes, run:"
#echo "for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do"
#echo "    CPU_NAME=\$(basename \$(dirname \$cpu))"
#echo "    cat $BACKUP_DIR/\${CPU_NAME}_governor.bak > \$cpu"
#echo "done"
#echo "for q in /sys/class/net/ens6np0/queues/rx-*; do"
#echo "    QUEUE=\$(basename \$q); cat $BACKUP_DIR/\${QUEUE}_rps.bak > \$q/rps_cpus"
#echo "done"
#echo "for q in /sys/class/net/ens6np0/queues/tx-*; do"
#echo "    QUEUE=\$(basename \$q); cat $BACKUP_DIR/\${QUEUE}_xps.bak > \$q/xps_cpus"
#echo "done"
#echo "for irq in $IRQ_NUMS; do cat $BACKUP_DIR/irq_\${irq}.bak > /proc/irq/\${irq}/smp_affinity_list; done"




