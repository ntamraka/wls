#!/bin/bash

# System Information Gathering Script
# Collects hardware and system configuration for performance analysis
# Requires: dmidecode, lscpu (root privileges recommended)
# Optional: ipmitool, ethtool, numactl

set -o pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Section flags - all enabled by default
SECTIONS=(
    "cpu:CPU Information"
    "memory:Memory Information"
    "platform:Platform Information"
    "hugepage:Hugepage Settings"
    "qdf:QDF Information"
    "cpu_advanced:CPU Advanced Information"
    "numa:NUMA Details"
    "storage:Storage & I/O"
    "network:Network Information"
    "irq:IRQ & Interrupt Distribution"
    "network_adv:Network Advanced"
    "resources:System Resources"
    "power:Power & Thermal"
    "virt:Virtualization"
    "pcie:PCIe & Hardware"
)

# Initialize all sections as enabled
for section in "${SECTIONS[@]}"; do
    key="${section%%:*}"
    eval "RUN_${key^^}=1"
done

# Output options
QUIET_MODE=0
OUTPUT_FILE=""
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

System Information Gathering Script - Collects hardware and system configuration

OPTIONS:
    -h, --help              Show this help message
    -a, --all               Run all sections (default)
    -q, --quiet             Quiet mode (no colors, minimal output)
    -o, --output FILE       Save output to file
    -t, --timestamp         Add timestamp to output filename
    
SECTION OPTIONS (run specific sections only):
EOF
    for section in "${SECTIONS[@]}"; do
        key="${section%%:*}"
        desc="${section#*:}"
        flag=$(echo "$key" | tr '_' '-')
        printf "    --%-20s %s\n" "$flag" "$desc"
    done
    cat << EOF

EXAMPLES:
    # Run all sections (default)
    $0
    
    # Run specific sections only
    $0 --cpu --memory --numa
    
    # Save to file with timestamp
    $0 --output system_info.txt --timestamp
    
    # Quiet mode, save to file
    $0 --quiet --output /tmp/sysinfo.log
    
    # Network analysis
    $0 --network --network-adv --irq

EOF
    exit 0
}

# Parse command line arguments
parse_args() {
    if [ $# -eq 0 ]; then
        return  # Run all sections by default
    fi
    
    # Check if any specific section is requested
    local specific_section=0
    for arg in "$@"; do
        if [[ "$arg" =~ ^--[a-z] ]] && [ "$arg" != "--help" ] && [ "$arg" != "--all" ] && [ "$arg" != "--quiet" ] && [ "$arg" != "--output" ] && [ "$arg" != "--timestamp" ]; then
            specific_section=1
            break
        fi
    done
    
    # If specific sections requested, disable all first
    if [ $specific_section -eq 1 ]; then
        for section in "${SECTIONS[@]}"; do
            key="${section%%:*}"
            eval "RUN_${key^^}=0"
        done
    fi
    
    while [ $# -gt 0 ]; do
        case $1 in
            -h|--help)
                usage
                ;;
            -a|--all)
                for section in "${SECTIONS[@]}"; do
                    key="${section%%:*}"
                    eval "RUN_${key^^}=1"
                done
                ;;
            -q|--quiet)
                QUIET_MODE=1
                RED=''
                GREEN=''
                YELLOW=''
                NC=''
                ;;
            -o|--output)
                shift
                OUTPUT_FILE="$1"
                ;;
            -t|--timestamp)
                if [ -n "$OUTPUT_FILE" ]; then
                    OUTPUT_FILE="${OUTPUT_FILE%.txt}_${TIMESTAMP}.txt"
                else
                    OUTPUT_FILE="system_info_${TIMESTAMP}.txt"
                fi
                ;;
            --cpu) RUN_CPU=1 ;;
            --memory) RUN_MEMORY=1 ;;
            --platform) RUN_PLATFORM=1 ;;
            --hugepage) RUN_HUGEPAGE=1 ;;
            --qdf) RUN_QDF=1 ;;
            --cpu-advanced) RUN_CPU_ADVANCED=1 ;;
            --numa) RUN_NUMA=1 ;;
            --storage) RUN_STORAGE=1 ;;
            --network) RUN_NETWORK=1 ;;
            --irq) RUN_IRQ=1 ;;
            --network-adv) RUN_NETWORK_ADV=1 ;;
            --resources) RUN_RESOURCES=1 ;;
            --power) RUN_POWER=1 ;;
            --virt) RUN_VIRT=1 ;;
            --pcie) RUN_PCIE=1 ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done
}

# Parse arguments
parse_args "$@"

# Redirect output to file if specified
if [ -n "$OUTPUT_FILE" ]; then
    exec > >(tee "$OUTPUT_FILE")
    exec 2>&1
fi

# Check if running as root
if [[ $EUID -ne 0 ]] && [ $QUIET_MODE -eq 0 ]; then
   echo -e "${YELLOW}Warning: Script not running as root. Some commands may fail.${NC}"
   echo "Consider running with: sudo $0"
   echo ""
fi

# Check for required commands
check_command() {
    command -v "$1" &> /dev/null
}

if [ $QUIET_MODE -eq 0 ]; then
    echo "Checking dependencies..."
    MISSING_DEPS=0
    for cmd in dmidecode lscpu; do
        if ! check_command "$cmd"; then
            echo -e "${RED}Error: $cmd is not installed${NC}"
            MISSING_DEPS=1
        fi
    done
    
    if [[ $MISSING_DEPS -eq 1 ]]; then
        echo -e "${RED}Please install missing dependencies${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}All required dependencies found${NC}"
    echo ""
fi

# ===================== CPU Information =============================
if [ $RUN_CPU -eq 1 ]; then
    echo "===================== CPU Information ========================="
    if check_command lscpu; then
        lscpu | grep "Model name:" | sed 's/Model name:[[:space:]]*/CPU Model: /'
        lscpu | grep "Architecture:" | sed 's/Architecture:[[:space:]]*/Architecture: /'
        lscpu | grep "CPU(s):" | head -n 1 | sed 's/CPU(s):[[:space:]]*/Total CPUs: /'
        lscpu | grep "Thread(s) per core:" | sed 's/Thread(s) per core:[[:space:]]*/Threads per Core: /'
        lscpu | grep "Core(s) per socket:" | sed 's/Core(s) per socket:[[:space:]]*/Cores per Socket: /'
        lscpu | grep "Socket(s):" | sed 's/Socket(s):[[:space:]]*/Sockets: /'
        lscpu | grep "NUMA node(s):" | sed 's/NUMA node(s):[[:space:]]*/NUMA Nodes: /'
        
        # CPU frequency
        if [ -f /proc/cpuinfo ]; then
            MAX_FREQ=$(grep "cpu MHz" /proc/cpuinfo | awk '{print $4}' | sort -n | tail -1)
            [ -n "$MAX_FREQ" ] && echo "Current Max Frequency: ${MAX_FREQ} MHz"
        fi
        
        # Scaling governor
        if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
            GOVERNOR=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)
            echo "Scaling Governor: $GOVERNOR"
        fi
        
        # Microcode
        if [ -f /proc/cpuinfo ]; then
            MICROCODE=$(grep "microcode" /proc/cpuinfo | uniq | awk '{print $3}')
            [ -n "$MICROCODE" ] && echo "Microcode Version: $MICROCODE"
        fi
    fi
fi

# ===================== Memory Information ==========================
if [ $RUN_MEMORY -eq 1 ]; then
    echo ""
    echo "===================== Memory Information ======================"
    if check_command dmidecode && dmidecode -t memory &> /dev/null; then
        # Memory technology
        MEM_TECH=$(dmidecode | grep "Memory Technology: " | head -n 1 | awk '{print $3}')
        [ -n "$MEM_TECH" ] && echo "Memory Technology: $MEM_TECH"
        
        # Count DIMMs
        DIMM_COUNT=$(dmidecode | grep "Volatile Size:" | grep "GB" | wc -l)
        echo "Number of DIMMs: $DIMM_COUNT"
        
        # DIMM size
        DIMM_SIZE=$(dmidecode | grep "Volatile Size:" | grep "GB" | head -n 1 | awk '{print $3, $4}')
        [ -n "$DIMM_SIZE" ] && echo "DIMM Size: $DIMM_SIZE"
        
        # Total memory
        if [ -n "$DIMM_SIZE" ] && [ "$DIMM_COUNT" -gt 0 ]; then
            SIZE_GB=$(echo "$DIMM_SIZE" | awk '{print $1}')
            TOTAL_MEM=$((SIZE_GB * DIMM_COUNT))
            echo "Total Memory: ${TOTAL_MEM} GB"
        fi
        
        # Memory speed
        MEM_SPEED=$(dmidecode | grep "Speed: " | grep "MT/s" | head -n 1 | awk '{print $2, $3}')
        [ -n "$MEM_SPEED" ] && echo "Memory Speed: $MEM_SPEED"
        
        # Configured speed
        CONF_SPEED=$(dmidecode | grep "Configured Memory Speed:" | grep "MT/s" | head -n 1 | awk '{print $4, $5}')
        [ -n "$CONF_SPEED" ] && echo "Configured Speed: $CONF_SPEED"
    else
        echo -e "${YELLOW}Unable to retrieve memory information${NC}"
    fi
fi

# ===================== Platform Information ========================
if [ $RUN_PLATFORM -eq 1 ]; then
    echo ""
    echo "===================== Platform Information ===================="
    if check_command dmidecode && dmidecode &> /dev/null; then
        PRODUCT=$(dmidecode | grep "Product Name:" | head -n 1 | sed 's/[[:space:]]*Product Name:[[:space:]]*//')
        [ -n "$PRODUCT" ] && echo "Product Name: $PRODUCT"
        
        BIOS_VER=$(dmidecode -t bios 2>/dev/null | grep "Version:" | head -n 1 | awk '{print $2}')
        [ -n "$BIOS_VER" ] && echo "BIOS Version: $BIOS_VER"
    fi
    
    echo "Kernel Version: $(uname -r)"
    
    if [ -f /etc/os-release ]; then
        OS_NAME=$(awk -F '"' '/PRETTY_NAME=/{print $2}' /etc/os-release)
        echo "Operating System: $OS_NAME"
    fi
fi

# ===================== Hugepage Settings ===========================
if [ $RUN_HUGEPAGE -eq 1 ]; then
    echo ""
    echo "===================== Hugepage Settings ======================="
    if [ -f /sys/kernel/mm/transparent_hugepage/enabled ]; then
        echo -n "Transparent Hugepages: "
        cat /sys/kernel/mm/transparent_hugepage/enabled
    fi
    
    if [ -f /proc/meminfo ]; then
        HUGEPAGES=$(grep "HugePages_" /proc/meminfo)
        [ -n "$HUGEPAGES" ] && echo "$HUGEPAGES"
    fi
fi

# ===================== QDF Information (Optional) ==================
if [ $RUN_QDF -eq 1 ]; then
    echo ""
    echo "===================== QDF Information ========================="
    if check_command ipmitool; then
        QDF_INFO=$(ipmitool raw 0x3e 0x52 0x40 12 0x50 19 0 2>/dev/null | tr "\n" " " | cut -d " " -f 17- | xxd -r -p 2>/dev/null)
        if [ $? -eq 0 ] && [ -n "$QDF_INFO" ]; then
            echo "$QDF_INFO"
        else
            echo -e "${YELLOW}QDF information not available${NC}"
        fi
    else
        echo -e "${YELLOW}ipmitool not installed - skipping${NC}"
    fi
fi

# ===================== CPU Advanced Information ====================
if [ $RUN_CPU_ADVANCED -eq 1 ]; then
    echo ""
    echo "===================== CPU Advanced Information ================"
    if check_command lscpu; then
        # Cache information
        lscpu | grep "L1d cache:" | sed 's/L1d cache:[[:space:]]*/L1d Cache: /'
        lscpu | grep "L1i cache:" | sed 's/L1i cache:[[:space:]]*/L1i Cache: /'
        lscpu | grep "L2 cache:" | sed 's/L2 cache:[[:space:]]*/L2 Cache: /'
        lscpu | grep "L3 cache:" | sed 's/L3 cache:[[:space:]]*/L3 Cache: /'
        
        # Virtualization
        VIRT=$(lscpu | grep "Virtualization:" | awk '{print $2}')
        [ -n "$VIRT" ] && echo "Virtualization: $VIRT"
        
        # CPU features
        if [ -f /proc/cpuinfo ]; then
            FLAGS=$(grep "flags" /proc/cpuinfo | head -n 1)
            if echo "$FLAGS" | grep -q "avx512"; then
                echo "AVX-512: Supported"
            elif echo "$FLAGS" | grep -q "avx2"; then
                echo "AVX2: Supported"
            elif echo "$FLAGS" | grep -q "avx"; then
                echo "AVX: Supported"
            fi
        fi
    fi
    
    # Turbo boost
    if [ -f /sys/devices/system/cpu/intel_pstate/no_turbo ]; then
        TURBO=$(cat /sys/devices/system/cpu/intel_pstate/no_turbo)
        [ "$TURBO" = "0" ] && echo "Intel Turbo Boost: Enabled" || echo "Intel Turbo Boost: Disabled"
    elif [ -f /sys/devices/system/cpu/cpufreq/boost ]; then
        BOOST=$(cat /sys/devices/system/cpu/cpufreq/boost)
        [ "$BOOST" = "1" ] && echo "CPU Boost: Enabled" || echo "CPU Boost: Disabled"
    fi
    
    # CPU vulnerabilities
    if [ -d /sys/devices/system/cpu/vulnerabilities ]; then
        echo ""
        echo "CPU Vulnerabilities & Mitigations:"
        for vuln in /sys/devices/system/cpu/vulnerabilities/*; do
            [ -f "$vuln" ] && echo "  $(basename "$vuln"): $(cat "$vuln")"
        done
    fi
    
    # C-states
    if [ -d /sys/devices/system/cpu/cpu0/cpuidle ]; then
        CSTATES=$(ls -d /sys/devices/system/cpu/cpu0/cpuidle/state* 2>/dev/null | wc -l)
        [ "$CSTATES" -gt 0 ] && echo "Available C-states: $CSTATES"
    fi
fi

# ===================== NUMA Details ================================
if [ $RUN_NUMA -eq 1 ]; then
    echo ""
    echo "===================== NUMA Details ============================"
    if check_command numactl; then
        echo "NUMA Configuration:"
        numactl --hardware 2>/dev/null | head -n 20
    else
        if [ -d /sys/devices/system/node ]; then
            NUMA_NODES=$(ls -d /sys/devices/system/node/node* 2>/dev/null | wc -l)
            echo "NUMA Nodes: $NUMA_NODES"
            
            for node in /sys/devices/system/node/node*; do
                if [ -d "$node" ] && [ -f "$node/meminfo" ]; then
                    NODE_NUM=$(basename "$node" | sed 's/node//')
                    MEM_TOTAL=$(grep "MemTotal:" "$node/meminfo" | awk '{print $4, $5}')
                    MEM_FREE=$(grep "MemFree:" "$node/meminfo" | awk '{print $4, $5}')
                    echo "  Node $NODE_NUM: Total=$MEM_TOTAL, Free=$MEM_FREE"
                fi
            done
        fi
    fi
    
    # NUMA balancing
    if [ -f /proc/sys/kernel/numa_balancing ]; then
        NUMA_BAL=$(cat /proc/sys/kernel/numa_balancing)
        [ "$NUMA_BAL" = "1" ] && echo "NUMA Balancing: Enabled" || echo "NUMA Balancing: Disabled"
    fi
fi

# ===================== Storage & I/O ===============================
if [ $RUN_STORAGE -eq 1 ]; then
    echo ""
    echo "===================== Storage & I/O ==========================="
    
    # Block devices
    if check_command lsblk; then
        echo "Block Devices:"
        lsblk -d -o NAME,SIZE,TYPE,MODEL,ROTA 2>/dev/null | head -n 10
    fi
    
    # I/O Schedulers
    echo ""
    echo "I/O Schedulers:"
    shopt -s nullglob
    for dev in /sys/block/sd* /sys/block/nvme* /sys/block/vd*; do
        if [ -d "$dev" ] && [ -f "$dev/queue/scheduler" ]; then
            DEV_NAME=$(basename "$dev")
            SCHEDULER=$(cat "$dev/queue/scheduler")
            echo "  $DEV_NAME: $SCHEDULER"
        fi
    done
    shopt -u nullglob
    
    # Filesystems
    echo ""
    echo "Mounted Filesystems:"
    df -Th 2>/dev/null | grep -v "tmpfs\|devtmpfs" | head -n 10
    
    # RAID
    if check_command mdadm && [ -f /proc/mdstat ]; then
        RAID_INFO=$(cat /proc/mdstat | grep -E "md[0-9]")
        if [ -n "$RAID_INFO" ]; then
            echo ""
            echo "RAID Configuration:"
            cat /proc/mdstat
        fi
    fi
fi

# ===================== Network Information =========================
if [ $RUN_NETWORK -eq 1 ]; then
    echo ""
    echo "===================== Network Information ====================="
    
    if check_command ip; then
        echo "Network Interfaces:"
        ip -br link show 2>/dev/null | grep -v "lo"
        
        echo ""
        echo "Network Interface IP Addresses:"
        printf "%-15s %-20s %-45s %s\n" "INTERFACE" "STATE" "IPv4 ADDRESS" "IPv6 ADDRESS"
        printf "%-15s %-20s %-45s %s\n" "----------" "-----" "------------" "------------"
        
        for iface in $(ip -br link show 2>/dev/null | grep -v "lo" | awk '{print $1}'); do
            STATE=$(ip -br link show "$iface" 2>/dev/null | awk '{print $2}')
            IPV4=$(ip -4 addr show "$iface" 2>/dev/null | grep -oP 'inet \K[\d.]+/\d+' | head -n 1)
            IPV6=$(ip -6 addr show "$iface" 2>/dev/null | grep -oP 'inet6 \K[0-9a-f:]+/\d+' | grep -v "^fe80" | head -n 1)
            
            [ -z "$IPV4" ] && IPV4="-"
            [ -z "$IPV6" ] && IPV6="-"
            
            printf "%-15s %-20s %-45s %s\n" "$iface" "$STATE" "$IPV4" "$IPV6"
        done
        
        echo ""
        echo "Network Interface Details:"
        for iface in $(ip -br link show 2>/dev/null | grep -v "lo" | awk '{print $1}'); do
            echo "  Interface: $iface"
            
            # Speed
            if [ -f "/sys/class/net/$iface/speed" ]; then
                SPEED=$(cat "/sys/class/net/$iface/speed" 2>/dev/null)
                [ -n "$SPEED" ] && [ "$SPEED" != "-1" ] && echo "    Speed: ${SPEED} Mbps"
            fi
            
            # MTU
            [ -f "/sys/class/net/$iface/mtu" ] && echo "    MTU: $(cat "/sys/class/net/$iface/mtu")"
            
            # Driver
            if [ -L "/sys/class/net/$iface/device/driver" ]; then
                DRIVER=$(readlink "/sys/class/net/$iface/device/driver" 2>/dev/null | xargs basename)
                [ -n "$DRIVER" ] && echo "    Driver: $DRIVER"
            fi
            
            # Offload features
            if check_command ethtool; then
                TSO=$(ethtool -k "$iface" 2>/dev/null | grep "tcp-segmentation-offload:" | awk '{print $2}')
                GRO=$(ethtool -k "$iface" 2>/dev/null | grep "generic-receive-offload:" | awk '{print $2}')
                [ -n "$TSO" ] && echo "    TSO: $TSO, GRO: $GRO"
            fi
        done
    fi
fi

# ===================== IRQ & Interrupt Distribution ================
if [ $RUN_IRQ -eq 1 ]; then
    echo ""
    echo "===================== IRQ & Interrupt Distribution ============"
    
    # Top IRQs
    if [ -f /proc/interrupts ]; then
        echo "Top 10 IRQs by count:"
        awk 'NR>1 {sum=0; for(i=2;i<=NF-3;i++) sum+=$i; if(sum>0) print sum, $NF}' /proc/interrupts | \
            sort -rn | head -n 10 | while read count name; do
            printf "  %-40s %s\n" "$name" "$count"
        done
        
        # IRQ affinity for network/storage devices
        echo ""
        echo "IRQ Affinity (network/storage devices):"
        for irq in /proc/irq/*/smp_affinity_list; do
            if [ -f "$irq" ]; then
                IRQ_NUM=$(echo "$irq" | cut -d'/' -f4)
                AFFINITY=$(cat "$irq" 2>/dev/null)
                IRQ_NAME=$(awk -v irq="$IRQ_NUM:" '$1==irq {print $NF}' /proc/interrupts 2>/dev/null)
                if [ -n "$IRQ_NAME" ] && [[ "$IRQ_NAME" =~ (eth|nvme|mlx|ens) ]]; then
                    printf "  IRQ %-4s %-30s CPUs: %s\n" "$IRQ_NUM" "$IRQ_NAME" "$AFFINITY"
                fi
            fi
        done | head -n 15
    fi
    
    # Default SMP affinity
    if [ -f /proc/irq/default_smp_affinity ]; then
        echo ""
        echo "Default IRQ SMP Affinity: $(cat /proc/irq/default_smp_affinity)"
    fi
    
    # RPS status
    echo ""
    echo "Receive Packet Steering (RPS):"
    RPS_FOUND=0
    for iface in /sys/class/net/*/queues/rx-*/rps_cpus; do
        if [ -f "$iface" ]; then
            RPS_VAL=$(cat "$iface" 2>/dev/null)
            if [ "$RPS_VAL" != "0" ] && [ -n "$RPS_VAL" ]; then
                IFACE_NAME=$(echo "$iface" | cut -d'/' -f5)
                QUEUE=$(echo "$iface" | cut -d'/' -f7)
                echo "  $IFACE_NAME $QUEUE: enabled"
                RPS_FOUND=1
            fi
        fi
    done
    [ $RPS_FOUND -eq 0 ] && echo "  RPS not configured"
fi

# ===================== Network Advanced ============================
if [ $RUN_NETWORK_ADV -eq 1 ]; then
    echo ""
    echo "===================== Network Advanced ========================"
    
    # Network interface details
    for iface in $(ip -br link show 2>/dev/null | grep -v "lo" | grep "UP" | awk '{print $1}'); do
        echo "Interface: $iface"
        echo "----------------------------------------"
        
        if check_command ethtool; then
            # Ring buffers
            RING_INFO=$(ethtool -g "$iface" 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo "  Ring Buffers:"
                echo "$RING_INFO" | grep -A 4 "Current hardware settings:" | tail -n 4 | sed 's/^/    /'
            fi
            
            # Channels/Queues
            CHANNELS=$(ethtool -l "$iface" 2>/dev/null)
            if [ $? -eq 0 ]; then
                echo "  Channels/Queues:"
                echo "$CHANNELS" | grep -A 4 "Current hardware settings:" | tail -n 4 | sed 's/^/    /'
            fi
            
            # RSS
            RSS_INFO=$(ethtool -x "$iface" 2>/dev/null | head -n 5)
            if [ $? -eq 0 ]; then
                echo "  RSS Configuration:"
                echo "$RSS_INFO" | sed 's/^/    /'
            fi
            
            # Coalescing
            COALESCE=$(ethtool -c "$iface" 2>/dev/null | grep -E "rx-usecs:|tx-usecs:" | head -n 2)
            [ -n "$COALESCE" ] && echo "  Interrupt Coalescing:" && echo "$COALESCE" | sed 's/^/    /'
        fi
        
        # Queue discipline
        if check_command tc; then
            QDISC=$(tc qdisc show dev "$iface" 2>/dev/null | head -n 1)
            [ -n "$QDISC" ] && echo "  Queue Discipline: $QDISC"
        fi
        
        # XPS
        XPS_COUNT=0
        if [ -d "/sys/class/net/$iface/queues" ]; then
            for xps in /sys/class/net/$iface/queues/tx-*/xps_cpus; do
                if [ -f "$xps" ]; then
                    XPS_VAL=$(cat "$xps" 2>/dev/null)
                    [ "$XPS_VAL" != "0" ] && [ -n "$XPS_VAL" ] && XPS_COUNT=$((XPS_COUNT + 1))
                fi
            done
            [ $XPS_COUNT -gt 0 ] && echo "  XPS (Transmit Packet Steering): Enabled on $XPS_COUNT queues"
        fi
        
        echo ""
    done
    
    # Bonding/Teaming
    echo "Bonding/Teaming:"
    if [ -d /proc/net/bonding ]; then
        BONDS=$(ls /proc/net/bonding/ 2>/dev/null)
        if [ -n "$BONDS" ]; then
            for bond in $BONDS; do
                echo "  Bond: $bond"
                grep -E "Mode:|Slave Interface:" /proc/net/bonding/$bond | sed 's/^/    /'
            done
        else
            echo "  No bonding configured"
        fi
    else
        echo "  No bonding configured"
    fi
    
    if check_command teamdctl; then
        TEAMS=$(teamdctl 2>/dev/null | grep -v "No such")
        [ -n "$TEAMS" ] && echo "  Team interfaces detected"
    fi
    
    # Connection tracking
    echo ""
    echo "Connection Tracking (conntrack):"
    [ -f /proc/sys/net/netfilter/nf_conntrack_max ] && \
        echo "  Max connections: $(cat /proc/sys/net/netfilter/nf_conntrack_max)"
    [ -f /proc/sys/net/netfilter/nf_conntrack_count ] && \
        echo "  Current connections: $(cat /proc/sys/net/netfilter/nf_conntrack_count)"
    [ -f /proc/sys/net/netfilter/nf_conntrack_buckets ] && \
        echo "  Hash buckets: $(cat /proc/sys/net/netfilter/nf_conntrack_buckets)"
    
    # TCP settings
    echo ""
    echo "TCP Configuration:"
    [ -f /proc/sys/net/ipv4/tcp_rmem ] && \
        echo "  TCP Read Buffer (min/default/max): $(cat /proc/sys/net/ipv4/tcp_rmem)"
    [ -f /proc/sys/net/ipv4/tcp_wmem ] && \
        echo "  TCP Write Buffer (min/default/max): $(cat /proc/sys/net/ipv4/tcp_wmem)"
    [ -f /proc/sys/net/core/rmem_max ] && \
        echo "  Socket Read Buffer Max: $(cat /proc/sys/net/core/rmem_max)"
    [ -f /proc/sys/net/core/wmem_max ] && \
        echo "  Socket Write Buffer Max: $(cat /proc/sys/net/core/wmem_max)"
    [ -f /proc/sys/net/core/netdev_max_backlog ] && \
        echo "  Netdev Max Backlog: $(cat /proc/sys/net/core/netdev_max_backlog)"
fi

# ===================== System Resources ============================
if [ $RUN_RESOURCES -eq 1 ]; then
    echo ""
    echo "===================== System Resources ========================"
    
    # Uptime and load
    echo "System Uptime: $(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"
    echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    
    # Memory usage
    if [ -f /proc/meminfo ]; then
        MEM_TOTAL=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
        MEM_AVAIL=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
        SWAP_TOTAL=$(grep "SwapTotal:" /proc/meminfo | awk '{print $2}')
        SWAP_FREE=$(grep "SwapFree:" /proc/meminfo | awk '{print $2}')
        
        MEM_TOTAL_GB=$((MEM_TOTAL / 1024 / 1024))
        MEM_AVAIL_GB=$((MEM_AVAIL / 1024 / 1024))
        SWAP_TOTAL_GB=$((SWAP_TOTAL / 1024 / 1024))
        SWAP_USED_GB=$(((SWAP_TOTAL - SWAP_FREE) / 1024 / 1024))
        
        echo "Memory Usage: ${MEM_AVAIL_GB} GB available of ${MEM_TOTAL_GB} GB total"
        echo "Swap Usage: ${SWAP_USED_GB} GB used of ${SWAP_TOTAL_GB} GB total"
    fi
    
    # Process limits
    echo ""
    echo "System Limits:"
    echo "  Max Open Files: $(ulimit -n 2>/dev/null || echo "N/A")"
    echo "  Max Processes: $(ulimit -u 2>/dev/null || echo "N/A")"
    echo "  Max Stack Size: $(ulimit -s 2>/dev/null || echo "N/A") KB"
    [ -f /proc/sys/kernel/threads-max ] && echo "  Kernel Max Threads: $(cat /proc/sys/kernel/threads-max)"
    [ -f /proc/sys/fs/file-max ] && echo "  Kernel Max Files: $(cat /proc/sys/fs/file-max)"
fi

# ===================== Power & Thermal =============================
if [ $RUN_POWER -eq 1 ]; then
    echo ""
    echo "===================== Power & Thermal ========================="
    
    # Tuned profile
    if check_command tuned-adm; then
        TUNED_PROFILE=$(tuned-adm active 2>/dev/null | awk '{print $4}')
        [ -n "$TUNED_PROFILE" ] && echo "Tuned Profile: $TUNED_PROFILE"
    fi
    
    # Energy performance
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference ]; then
        EPP=$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference)
        echo "Energy Performance Preference: $EPP"
    elif [ -f /sys/devices/system/cpu/cpu0/power/energy_perf_bias ]; then
        EPB=$(cat /sys/devices/system/cpu/cpu0/power/energy_perf_bias)
        echo "Energy Performance Bias: $EPB"
    fi
    
    # Temperature
    if check_command sensors; then
        TEMP_INFO=$(sensors 2>/dev/null | grep -E "Core|Package" | head -n 5)
        if [ -n "$TEMP_INFO" ]; then
            echo ""
            echo "CPU Temperature:"
            echo "$TEMP_INFO"
        fi
    elif [ -d /sys/class/thermal ]; then
        for zone in /sys/class/thermal/thermal_zone*/temp; do
            if [ -f "$zone" ]; then
                TEMP=$(cat "$zone" 2>/dev/null)
                if [ -n "$TEMP" ]; then
                    TEMP_C=$((TEMP / 1000))
                    ZONE_NAME=$(basename $(dirname "$zone"))
                    echo "  $ZONE_NAME: ${TEMP_C}°C"
                fi
            fi
        done
    fi
fi

# ===================== Virtualization ==============================
if [ $RUN_VIRT -eq 1 ]; then
    echo ""
    echo "===================== Virtualization =========================="
    
    # Detect hypervisor
    if check_command systemd-detect-virt; then
        VIRT_TYPE=$(systemd-detect-virt 2>/dev/null)
        [ "$VIRT_TYPE" = "none" ] && echo "Environment: Bare Metal" || echo "Environment: Virtualized ($VIRT_TYPE)"
    elif [ -f /proc/cpuinfo ]; then
        if grep -q "hypervisor" /proc/cpuinfo; then
            echo "Environment: Virtualized (detected via cpuinfo)"
            HYPERVISOR=$(lscpu | grep "Hypervisor vendor:" | awk '{print $3}')
            [ -n "$HYPERVISOR" ] && echo "Hypervisor: $HYPERVISOR"
        else
            echo "Environment: Bare Metal"
        fi
    fi
    
    # Container check
    [ -f /.dockerenv ] && echo "Container: Docker"
    [ -f /run/.containerenv ] && echo "Container: Podman"
    grep -q "lxc\|docker\|kubepods" /proc/1/cgroup 2>/dev/null && echo "Container: Detected"
fi

# ===================== PCIe & Hardware =============================
if [ $RUN_PCIE -eq 1 ]; then
    echo ""
    echo "===================== PCIe & Hardware ========================="
    
    if check_command lspci; then
        echo "PCIe Devices:"
        lspci 2>/dev/null | grep -E "Ethernet|Network|NVMe|RAID|VGA|Audio" | head -n 15
        
        echo ""
        echo "NVMe Devices Details:"
        lspci -vv 2>/dev/null | grep -A 10 "NVMe" | grep -E "LnkSta:|Width" | head -n 5
        
        echo ""
        echo "Network Controllers Details:"
        lspci -vv 2>/dev/null | grep -A 10 "Ethernet" | grep -E "LnkSta:|Width" | head -n 5
        
        # Hardware accelerators
        if lspci 2>/dev/null | grep -qi "accelerator"; then
            echo ""
            echo "Hardware Accelerators:"
            lspci 2>/dev/null | grep -i "accelerator"
        fi
    fi
fi

# ===================== Summary =====================================
echo ""
echo "==============================================================="
echo "System information collection complete"
echo "==============================================================="

if [ -n "$OUTPUT_FILE" ]; then
    echo "Output saved to: $OUTPUT_FILE"
fi

