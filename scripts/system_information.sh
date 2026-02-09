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
    "msr:MSR Registers (CPU Frequency, Temperature, Power)"
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
            --msr) RUN_MSR=1 ;;
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

# ===================== MSR Registers ===================================
if [ $RUN_MSR -eq 1 ]; then
    echo ""
    echo "===================== MSR Registers (Model-Specific) =========="
    
    # Check if msr module is loaded
    if ! lsmod | grep -q "^msr"; then
        echo "Loading MSR kernel module..."
        modprobe msr 2>/dev/null
        if [ $? -ne 0 ]; then
            echo -e "${YELLOW}Cannot load MSR module (requires root privileges)${NC}"
            echo "Run: modprobe msr"
        fi
    fi
    
    # Check if rdmsr is available
    if ! check_command rdmsr; then
        echo -e "${YELLOW}rdmsr tool not found. Install msr-tools package.${NC}"
        echo "  Ubuntu/Debian: apt-get install msr-tools"
        echo "  RHEL/CentOS: yum install msr-tools"
    elif [ ! -c /dev/cpu/0/msr ]; then
        echo -e "${YELLOW}MSR device not available. Load msr module: modprobe msr${NC}"
    else
        # Get number of CPUs
        NUM_CPUS=$(nproc)
        
        echo "Reading MSR registers from CPU 0..."
        echo ""
        
        # CPU Frequency - IA32_PERF_STATUS (0x198)
        if PERF_STATUS=$(rdmsr -p 0 0x198 2>/dev/null); then
            CURRENT_RATIO=$(( (0x$PERF_STATUS >> 8) & 0xFF ))
            if [ $CURRENT_RATIO -gt 0 ]; then
                # Assuming 100 MHz base clock
                FREQ_MHZ=$((CURRENT_RATIO * 100))
                echo "CPU Frequency (MSR 0x198 - IA32_PERF_STATUS):"
                echo "  Current Ratio: $CURRENT_RATIO"
                echo "  Estimated Frequency: ${FREQ_MHZ} MHz"
            fi
        fi
        
        # MPERF/APERF for actual frequency
        if check_command rdmsr; then
            APERF_START=$(rdmsr -p 0 0xE8 2>/dev/null)
            MPERF_START=$(rdmsr -p 0 0xE7 2>/dev/null)
            sleep 0.1
            APERF_END=$(rdmsr -p 0 0xE8 2>/dev/null)
            MPERF_END=$(rdmsr -p 0 0xE7 2>/dev/null)
            
            if [ -n "$APERF_START" ] && [ -n "$MPERF_START" ] && [ -n "$APERF_END" ] && [ -n "$MPERF_END" ]; then
                APERF_DELTA=$((0x$APERF_END - 0x$APERF_START))
                MPERF_DELTA=$((0x$MPERF_END - 0x$MPERF_START))
                
                if [ $MPERF_DELTA -gt 0 ]; then
                    # Get max frequency from cpuinfo
                    MAX_FREQ=$(grep "model name" /proc/cpuinfo | head -n 1 | grep -oP '\d+\.\d+GHz' | grep -oP '\d+')
                    if [ -z "$MAX_FREQ" ]; then
                        MAX_FREQ=$(lscpu | grep "CPU max MHz" | awk '{print $4}' | cut -d'.' -f1)
                    fi
                    [ -z "$MAX_FREQ" ] && MAX_FREQ=3000
                    
                    AVG_FREQ=$(awk "BEGIN {printf \"%.0f\", ($APERF_DELTA * $MAX_FREQ) / $MPERF_DELTA}")
                    echo ""
                    echo "Average CPU Frequency (APERF/MPERF):"
                    echo "  APERF Delta: $APERF_DELTA"
                    echo "  MPERF Delta: $MPERF_DELTA"
                    echo "  Average Frequency: ${AVG_FREQ} MHz"
                fi
            fi
        fi
        
        # Temperature - IA32_THERM_STATUS (0x19C)
        if THERM_STATUS=$(rdmsr -p 0 0x19C 2>/dev/null); then
            DIGITAL_READOUT=$(( (0x$THERM_STATUS >> 16) & 0x7F ))
            
            # Get TjMax (usually from MSR 0x1A2 or assume 100°C)
            TJMAX=100
            if TEMP_TARGET=$(rdmsr -p 0 0x1A2 2>/dev/null); then
                TJMAX=$(( (0x$TEMP_TARGET >> 16) & 0xFF ))
            fi
            
            TEMP=$((TJMAX - DIGITAL_READOUT))
            
            echo ""
            echo "CPU Temperature (MSR 0x19C - IA32_THERM_STATUS):"
            echo "  TjMax: ${TJMAX}°C"
            echo "  Digital Readout: $DIGITAL_READOUT"
            echo "  Current Temperature: ${TEMP}°C"
            
            # Check thermal throttling
            THERMAL_THROTTLE=$(( (0x$THERM_STATUS >> 0) & 0x1 ))
            [ $THERMAL_THROTTLE -eq 1 ] && echo "  WARNING: Thermal throttling active!"
        fi
        
        # Turbo Boost Status - IA32_MISC_ENABLE (0x1A0)
        if MISC_ENABLE=$(rdmsr -p 0 0x1A0 2>/dev/null); then
            TURBO_DISABLED=$(( (0x$MISC_ENABLE >> 38) & 0x1 ))
            echo ""
            echo "Turbo Boost Status (MSR 0x1A0 - IA32_MISC_ENABLE):"
            if [ $TURBO_DISABLED -eq 0 ]; then
                echo "  Turbo Boost: Enabled"
            else
                echo "  Turbo Boost: Disabled"
            fi
        fi
        
        # Turbo Ratio Limits - MSR_TURBO_RATIO_LIMIT (0x1AD)
        if TURBO_RATIO=$(rdmsr -p 0 0x1AD 2>/dev/null); then
            echo ""
            echo "Turbo Ratio Limits (MSR 0x1AD):"
            for i in {0..7}; do
                SHIFT=$((i * 8))
                RATIO=$(( (0x$TURBO_RATIO >> $SHIFT) & 0xFF ))
                if [ $RATIO -gt 0 ]; then
                    FREQ=$((RATIO * 100))
                    echo "  $(($i + 1)) Core(s): ${RATIO}x (${FREQ} MHz)"
                fi
            done
        fi
        
        # Power Limit Information - MSR_PKG_POWER_LIMIT (0x610)
        if PKG_POWER_LIMIT=$(rdmsr -p 0 0x610 2>/dev/null); then
            echo ""
            echo "Package Power Limits (MSR 0x610):"
            
            # PL1 (bits 0-14)
            PL1_POWER=$(( 0x$PKG_POWER_LIMIT & 0x7FFF ))
            PL1_WATTS=$(awk "BEGIN {printf \"%.2f\", $PL1_POWER / 8}")
            echo "  PL1 (Sustained): ${PL1_WATTS} W"
            
            # PL1 Enable (bit 15)
            PL1_ENABLE=$(( (0x$PKG_POWER_LIMIT >> 15) & 0x1 ))
            [ $PL1_ENABLE -eq 1 ] && echo "    PL1 Enabled: Yes" || echo "    PL1 Enabled: No"
            
            # PL2 (bits 32-46)
            PL2_POWER=$(( (0x$PKG_POWER_LIMIT >> 32) & 0x7FFF ))
            PL2_WATTS=$(awk "BEGIN {printf \"%.2f\", $PL2_POWER / 8}")
            echo "  PL2 (Burst): ${PL2_WATTS} W"
            
            # PL2 Enable (bit 47)
            PL2_ENABLE=$(( (0x$PKG_POWER_LIMIT >> 47) & 0x1 ))
            [ $PL2_ENABLE -eq 1 ] && echo "    PL2 Enabled: Yes" || echo "    PL2 Enabled: No"
        fi
        
        # Package Energy Status - MSR_PKG_ENERGY_STATUS (0x611)
        if PKG_ENERGY=$(rdmsr -p 0 0x611 2>/dev/null); then
            ENERGY_UNIT=0.000061  # Default for Intel CPUs (1/2^14)
            
            # Read RAPL Power Unit (0x606) if available
            if RAPL_UNIT=$(rdmsr -p 0 0x606 2>/dev/null); then
                ENERGY_UNIT_RAW=$(( 0x$RAPL_UNIT & 0x1F ))
                ENERGY_UNIT=$(awk "BEGIN {printf \"%.9f\", 1 / (2 ^ $ENERGY_UNIT_RAW)}")
            fi
            
            ENERGY_RAW=$(( 0x$PKG_ENERGY & 0xFFFFFFFF ))
            ENERGY_JOULES=$(awk "BEGIN {printf \"%.2f\", $ENERGY_RAW * $ENERGY_UNIT}")
            
            echo ""
            echo "Package Energy (MSR 0x611):"
            echo "  Total Energy Consumed: ${ENERGY_JOULES} J (since last reset)"
        fi
        
        # C-State Residency
        echo ""
        echo "C-State Residency Counters:"
        
        # Core C-states
        declare -A CSTATE_MSRS=(
            ["C3"]=0x3FC
            ["C6"]=0x3FD
            ["C7"]=0x3FE
        )
        
        for state in "${!CSTATE_MSRS[@]}"; do
            MSR_ADDR=${CSTATE_MSRS[$state]}
            if RESIDENCY=$(rdmsr -p 0 $MSR_ADDR 2>/dev/null); then
                echo "  Core ${state} Residency (MSR ${MSR_ADDR}): 0x${RESIDENCY}"
            fi
        done
        
        # Package C-states
        declare -A PKG_CSTATE_MSRS=(
            ["PC2"]=0x60D
            ["PC3"]=0x3F8
            ["PC6"]=0x3F9
            ["PC7"]=0x3FA
        )
        
        for state in "${!PKG_CSTATE_MSRS[@]}"; do
            MSR_ADDR=${PKG_CSTATE_MSRS[$state]}
            if RESIDENCY=$(rdmsr -p 0 $MSR_ADDR 2>/dev/null); then
                echo "  Package ${state} Residency (MSR ${MSR_ADDR}): 0x${RESIDENCY}"
            fi
        done
        
        # RAPL Power Unit
        if RAPL_UNIT=$(rdmsr -p 0 0x606 2>/dev/null); then
            echo ""
            echo "RAPL Power Unit (MSR 0x606):"
            POWER_UNIT=$(( 0x$RAPL_UNIT & 0xF ))
            POWER_WATTS=$(awk "BEGIN {printf \"%.6f\", 1 / (2 ^ $POWER_UNIT)}")
            echo "  Power Unit: ${POWER_WATTS} W"
            
            TIME_UNIT=$(( (0x$RAPL_UNIT >> 16) & 0xF ))
            TIME_SECONDS=$(awk "BEGIN {printf \"%.6f\", 1 / (2 ^ $TIME_UNIT)}")
            echo "  Time Unit: ${TIME_SECONDS} s"
        fi
        
        # Uncore Frequency (Ring/LLC) - MSR_UNCORE_RATIO_LIMIT (0x620)
        if UNCORE_RATIO=$(rdmsr -p 0 0x620 2>/dev/null); then
            echo ""
            echo "Uncore (Ring/LLC) Frequency Limits (MSR 0x620):"
            MIN_RATIO=$(( 0x$UNCORE_RATIO & 0x7F ))
            MAX_RATIO=$(( (0x$UNCORE_RATIO >> 8) & 0x7F ))
            
            if [ $MIN_RATIO -gt 0 ]; then
                MIN_FREQ=$((MIN_RATIO * 100))
                echo "  Min Uncore Frequency: ${MIN_RATIO}x (${MIN_FREQ} MHz)"
            fi
            if [ $MAX_RATIO -gt 0 ]; then
                MAX_FREQ=$((MAX_RATIO * 100))
                echo "  Max Uncore Frequency: ${MAX_RATIO}x (${MAX_FREQ} MHz)"
            fi
        fi
        
        # Current Uncore Frequency - MSR_UNCORE_PERF_STATUS (0x621)
        if UNCORE_STATUS=$(rdmsr -p 0 0x621 2>/dev/null); then
            CURRENT_RATIO=$(( 0x$UNCORE_STATUS & 0x7F ))
            if [ $CURRENT_RATIO -gt 0 ]; then
                CURRENT_FREQ=$((CURRENT_RATIO * 100))
                echo "  Current Uncore Frequency: ${CURRENT_RATIO}x (${CURRENT_FREQ} MHz)"
            fi
        fi
        
        # Hardware Prefetcher Control - MSR_MISC_FEATURE_CONTROL (0x1A4)
        if PREFETCH_CTRL=$(rdmsr -p 0 0x1A4 2>/dev/null); then
            echo ""
            echo "Hardware Prefetcher Control (MSR 0x1A4):"
            
            L2_HW_PREFETCH=$(( (0x$PREFETCH_CTRL >> 0) & 0x1 ))
            L2_ADJ_PREFETCH=$(( (0x$PREFETCH_CTRL >> 1) & 0x1 ))
            DCU_PREFETCH=$(( (0x$PREFETCH_CTRL >> 2) & 0x1 ))
            DCU_IP_PREFETCH=$(( (0x$PREFETCH_CTRL >> 3) & 0x1 ))
            
            [ $L2_HW_PREFETCH -eq 0 ] && echo "  L2 Hardware Prefetcher: Enabled" || echo "  L2 Hardware Prefetcher: Disabled"
            [ $L2_ADJ_PREFETCH -eq 0 ] && echo "  L2 Adjacent Cache Line Prefetcher: Enabled" || echo "  L2 Adjacent Cache Line Prefetcher: Disabled"
            [ $DCU_PREFETCH -eq 0 ] && echo "  DCU Hardware Prefetcher: Enabled" || echo "  DCU Hardware Prefetcher: Disabled"
            [ $DCU_IP_PREFETCH -eq 0 ] && echo "  DCU IP Prefetcher: Enabled" || echo "  DCU IP Prefetcher: Disabled"
        fi
        
        # DRAM RAPL Domain Energy - MSR_DRAM_ENERGY_STATUS (0x619)
        if DRAM_ENERGY=$(rdmsr -p 0 0x619 2>/dev/null); then
            ENERGY_RAW=$(( 0x$DRAM_ENERGY & 0xFFFFFFFF ))
            ENERGY_UNIT=${ENERGY_UNIT:-0.000061}
            DRAM_JOULES=$(awk "BEGIN {printf \"%.2f\", $ENERGY_RAW * $ENERGY_UNIT}")
            
            echo ""
            echo "DRAM Energy Status (MSR 0x619):"
            echo "  DRAM Energy Consumed: ${DRAM_JOULES} J (since last reset)"
        fi
        
        # PP0 (Core) Energy Status - MSR_PP0_ENERGY_STATUS (0x639)
        if PP0_ENERGY=$(rdmsr -p 0 0x639 2>/dev/null); then
            ENERGY_RAW=$(( 0x$PP0_ENERGY & 0xFFFFFFFF ))
            PP0_JOULES=$(awk "BEGIN {printf \"%.2f\", $ENERGY_RAW * $ENERGY_UNIT}")
            
            echo ""
            echo "PP0 (Core) Energy Status (MSR 0x639):"
            echo "  Core Energy Consumed: ${PP0_JOULES} J (since last reset)"
        fi
        
        # PP1 (Graphics) Energy Status - MSR_PP1_ENERGY_STATUS (0x641)
        if PP1_ENERGY=$(rdmsr -p 0 0x641 2>/dev/null); then
            ENERGY_RAW=$(( 0x$PP1_ENERGY & 0xFFFFFFFF ))
            PP1_JOULES=$(awk "BEGIN {printf \"%.2f\", $ENERGY_RAW * $ENERGY_UNIT}")
            
            echo ""
            echo "PP1 (Graphics) Energy Status (MSR 0x641):"
            echo "  Graphics Energy Consumed: ${PP1_JOULES} J (since last reset)"
        fi
        
        # Platform Energy Counter - MSR_PLATFORM_ENERGY_COUNTER (0x64D)
        if PLATFORM_ENERGY=$(rdmsr -p 0 0x64D 2>/dev/null); then
            ENERGY_RAW=$(( 0x$PLATFORM_ENERGY & 0xFFFFFFFF ))
            PLATFORM_JOULES=$(awk "BEGIN {printf \"%.2f\", $ENERGY_RAW * $ENERGY_UNIT}")
            
            echo ""
            echo "Platform Energy Counter (MSR 0x64D):"
            echo "  Platform Energy Consumed: ${PLATFORM_JOULES} J (since last reset)"
        fi
        
        # DRAM Power Limit - MSR_DRAM_POWER_LIMIT (0x618)
        if DRAM_POWER_LIMIT=$(rdmsr -p 0 0x618 2>/dev/null); then
            echo ""
            echo "DRAM Power Limits (MSR 0x618):"
            
            DRAM_PL=$(( 0x$DRAM_POWER_LIMIT & 0x7FFF ))
            DRAM_WATTS=$(awk "BEGIN {printf \"%.2f\", $DRAM_PL / 8}")
            echo "  DRAM Power Limit: ${DRAM_WATTS} W"
            
            DRAM_ENABLE=$(( (0x$DRAM_POWER_LIMIT >> 15) & 0x1 ))
            [ $DRAM_ENABLE -eq 1 ] && echo "    Enabled: Yes" || echo "    Enabled: No"
        fi
        
        # Fixed Performance Counters
        echo ""
        echo "Fixed Performance Counters:"
        
        # Instructions Retired - MSR_PERF_FIXED_CTR0 (0x309)
        if FIXED_CTR0=$(rdmsr -p 0 0x309 2>/dev/null); then
            echo "  Instructions Retired (MSR 0x309): 0x${FIXED_CTR0}"
        fi
        
        # Core Cycles - MSR_PERF_FIXED_CTR1 (0x30A)
        if FIXED_CTR1=$(rdmsr -p 0 0x30A 2>/dev/null); then
            echo "  Core Cycles (MSR 0x30A): 0x${FIXED_CTR1}"
        fi
        
        # Reference Cycles - MSR_PERF_FIXED_CTR2 (0x30B)
        if FIXED_CTR2=$(rdmsr -p 0 0x30B 2>/dev/null); then
            echo "  Reference Cycles (MSR 0x30B): 0x${FIXED_CTR2}"
        fi
        
        # TSC Frequency - MSR_PLATFORM_INFO (0xCE)
        if PLATFORM_INFO=$(rdmsr -p 0 0xCE 2>/dev/null); then
            echo ""
            echo "Platform Info (MSR 0xCE):"
            
            MAX_NON_TURBO=$(( (0x$PLATFORM_INFO >> 8) & 0xFF ))
            if [ $MAX_NON_TURBO -gt 0 ]; then
                BASE_FREQ=$((MAX_NON_TURBO * 100))
                echo "  Max Non-Turbo Ratio: ${MAX_NON_TURBO}x"
                echo "  Base Frequency: ${BASE_FREQ} MHz"
            fi
            
            MIN_RATIO=$(( (0x$PLATFORM_INFO >> 40) & 0xFF ))
            if [ $MIN_RATIO -gt 0 ]; then
                MIN_FREQ=$((MIN_RATIO * 100))
                echo "  Min Operating Ratio: ${MIN_RATIO}x (${MIN_FREQ} MHz)"
            fi
            
            MAX_EFFICIENCY=$(( (0x$PLATFORM_INFO >> 48) & 0xFF ))
            if [ $MAX_EFFICIENCY -gt 0 ]; then
                EFF_FREQ=$((MAX_EFFICIENCY * 100))
                echo "  Max Efficiency Ratio: ${MAX_EFFICIENCY}x (${EFF_FREQ} MHz)"
            fi
        fi
        
        # Turbo Activation Ratio - MSR_TURBO_ACTIVATION_RATIO (0x64C)
        if TURBO_ACTIVATION=$(rdmsr -p 0 0x64C 2>/dev/null); then
            ACTIVATION_RATIO=$(( 0x$TURBO_ACTIVATION & 0xFF ))
            if [ $ACTIVATION_RATIO -gt 0 ]; then
                ACT_FREQ=$((ACTIVATION_RATIO * 100))
                echo ""
                echo "Turbo Activation Ratio (MSR 0x64C): ${ACTIVATION_RATIO}x (${ACT_FREQ} MHz)"
            fi
        fi
        
        # Config TDP Control - MSR_CONFIG_TDP_CONTROL (0x64B)
        if CONFIG_TDP=$(rdmsr -p 0 0x64B 2>/dev/null); then
            TDP_LEVEL=$(( 0x$CONFIG_TDP & 0x3 ))
            echo ""
            echo "Config TDP Level (MSR 0x64B): $TDP_LEVEL"
        fi
        
        # SMI Counter - MSR_SMI_COUNT (0x34)
        if SMI_COUNT=$(rdmsr -p 0 0x34 2>/dev/null); then
            SMI_NUM=$(( 0x$SMI_COUNT & 0xFFFFFFFF ))
            echo ""
            echo "SMI Count (MSR 0x34):"
            echo "  Total SMI Interrupts: $SMI_NUM"
            [ $SMI_NUM -gt 10000 ] && echo "  WARNING: High SMI count may impact performance!"
        fi
        
        # Machine Check Status
        echo ""
        echo "Machine Check Status:"
        
        # MCG_STATUS - MSR_MCG_STATUS (0x17A)
        if MCG_STATUS=$(rdmsr -p 0 0x17A 2>/dev/null); then
            MCIP=$(( (0x$MCG_STATUS >> 2) & 0x1 ))
            RIPV=$(( (0x$MCG_STATUS >> 0) & 0x1 ))
            EIPV=$(( (0x$MCG_STATUS >> 1) & 0x1 ))
            
            echo "  MCG_STATUS (MSR 0x17A): 0x${MCG_STATUS}"
            [ $MCIP -eq 1 ] && echo "    Machine Check In Progress: Yes" || echo "    Machine Check In Progress: No"
        fi
        
        # IA32_MCG_CAP - Machine Check Capabilities (0x179)
        if MCG_CAP=$(rdmsr -p 0 0x179 2>/dev/null); then
            MCG_COUNT=$(( 0x$MCG_CAP & 0xFF ))
            echo "  Machine Check Banks Available: $MCG_COUNT"
        fi
        
        # HWP (Hardware P-States) - MSR_HWP_CAPABILITIES (0x771)
        if HWP_CAP=$(rdmsr -p 0 0x771 2>/dev/null); then
            echo ""
            echo "Hardware P-States (HWP) Capabilities (MSR 0x771):"
            
            HIGHEST_PERF=$(( 0x$HWP_CAP & 0xFF ))
            GUARANTEED_PERF=$(( (0x$HWP_CAP >> 8) & 0xFF ))
            EFFICIENT_PERF=$(( (0x$HWP_CAP >> 16) & 0xFF ))
            LOWEST_PERF=$(( (0x$HWP_CAP >> 24) & 0xFF ))
            
            echo "  Highest Performance: $HIGHEST_PERF"
            echo "  Guaranteed Performance: $GUARANTEED_PERF"
            echo "  Most Efficient Performance: $EFFICIENT_PERF"
            echo "  Lowest Performance: $LOWEST_PERF"
        fi
        
        # HWP Request - MSR_HWP_REQUEST (0x774)
        if HWP_REQ=$(rdmsr -p 0 0x774 2>/dev/null); then
            echo ""
            echo "HWP Request (MSR 0x774):"
            
            MIN_PERF=$(( 0x$HWP_REQ & 0xFF ))
            MAX_PERF=$(( (0x$HWP_REQ >> 8) & 0xFF ))
            DESIRED_PERF=$(( (0x$HWP_REQ >> 16) & 0xFF ))
            EPP=$(( (0x$HWP_REQ >> 24) & 0xFF ))
            
            echo "  Minimum Performance: $MIN_PERF"
            echo "  Maximum Performance: $MAX_PERF"
            echo "  Desired Performance: $DESIRED_PERF"
            echo "  Energy Performance Preference: $EPP"
        fi
        
        echo ""
        echo "Note: MSR values are read from CPU 0 only."
        echo "For per-core analysis, use: rdmsr -a <MSR_ADDRESS>"
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

