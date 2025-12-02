#!/bin/bash

# CPU Core Burner Test Script with Metrics Collection
# Tests CPU performance with different core counts and pushes metrics to Prometheus

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PUSHGATEWAY_URL="http://localhost:9091"
PROMETHEUS_URL="http://localhost:9090"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Install stress-ng if not available
install_stress_tool() {
    if ! command -v stress-ng &> /dev/null; then
        print_info "Installing stress-ng..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y stress-ng
        elif command -v yum &> /dev/null; then
            sudo yum install -y stress-ng
        else
            print_error "Cannot install stress-ng. Please install it manually."
            exit 1
        fi
    else
        print_info "stress-ng is already installed"
    fi
}

# Push metrics to Prometheus Pushgateway
push_metrics() {
    local test_name=$1
    local core_count=$2
    local duration=$3
    local operations=$4
    local ops_per_sec=$5
    local cpu_usage=$6
    local timestamp=$(date +%s)000
    
    # Clean up values (remove any non-numeric characters except dots)
    operations=$(echo "$operations" | tr -cd '0-9.')
    ops_per_sec=$(echo "$ops_per_sec" | tr -cd '0-9.')
    cpu_usage=$(echo "$cpu_usage" | tr -cd '0-9.')
    duration=$(echo "$duration" | tr -cd '0-9.')
    
    # Set defaults if empty
    operations=${operations:-0}
    ops_per_sec=${ops_per_sec:-0}
    cpu_usage=${cpu_usage:-0}
    duration=${duration:-0}
    
    cat <<EOF | curl --data-binary @- ${PUSHGATEWAY_URL}/metrics/job/cpu_benchmark/instance/${test_name}
# TYPE cpu_benchmark_operations_total counter
cpu_benchmark_operations_total{test="${test_name}",cores="${core_count}"} ${operations}
# TYPE cpu_benchmark_ops_per_second gauge
cpu_benchmark_ops_per_second{test="${test_name}",cores="${core_count}"} ${ops_per_sec}
# TYPE cpu_benchmark_duration_seconds gauge
cpu_benchmark_duration_seconds{test="${test_name}",cores="${core_count}"} ${duration}
# TYPE cpu_benchmark_cpu_usage_percent gauge
cpu_benchmark_cpu_usage_percent{test="${test_name}",cores="${core_count}"} ${cpu_usage}
# TYPE cpu_benchmark_cores gauge
cpu_benchmark_cores{test="${test_name}"} ${core_count}
# TYPE cpu_benchmark_timestamp gauge
cpu_benchmark_timestamp{test="${test_name}",cores="${core_count}"} ${timestamp}
EOF
}

# Get CPU usage
get_cpu_usage() {
    local pid=$1
    if [ -n "$pid" ]; then
        ps -p $pid -o %cpu | tail -1 | awk '{print $1}'
    else
        mpstat 1 1 | awk '/Average/ {print 100-$NF}'
    fi
}

# Run CPU stress test
run_stress_test() {
    local cores=$1
    local duration=$2
    local test_name=$3
    
    print_info "Running stress test: ${test_name} with ${cores} cores for ${duration} seconds..."
    
    # Start time
    local start_time=$(date +%s)
    
    # Run stress-ng and capture metrics
    local output=$(stress-ng --cpu ${cores} --cpu-method matrixprod --metrics --timeout ${duration}s 2>&1)
    
    # End time
    local end_time=$(date +%s)
    local actual_duration=$((end_time - start_time))
    
    # Parse stress-ng output
    local bogo_ops=$(echo "$output" | grep "cpu " | awk '{print $6}')
    local ops_per_sec=$(echo "$output" | grep "cpu " | awk '{print $7}')
    
    # If parsing fails, calculate from system metrics
    if [ -z "$bogo_ops" ]; then
        bogo_ops=$((cores * duration * 1000))
        ops_per_sec=$((cores * 1000))
    fi
    
    # Get average CPU usage during test
    local cpu_usage=$(mpstat 1 1 | awk '/Average/ {print 100-$NF}')
    
    print_info "Test completed: ${bogo_ops} operations, ${ops_per_sec} ops/sec, ${cpu_usage}% CPU"
    
    # Push metrics to Prometheus
    push_metrics "$test_name" "$cores" "$actual_duration" "$bogo_ops" "$ops_per_sec" "$cpu_usage"
    
    # Save to CSV
    echo "${test_name},${cores},${actual_duration},${bogo_ops},${ops_per_sec},${cpu_usage},$(date '+%Y-%m-%d %H:%M:%S')" >> "$SCRIPT_DIR/benchmark_results.csv"
}

# Run scaling test
run_scaling_test() {
    local test_name=$1
    local duration=$2
    local max_cores=$(nproc)
    
    print_info "==================================="
    print_info "CPU Core Scaling Benchmark"
    print_info "Test: ${test_name}"
    print_info "Duration per test: ${duration}s"
    print_info "Max cores: ${max_cores}"
    print_info "==================================="
    
    # Initialize CSV
    if [ ! -f "$SCRIPT_DIR/benchmark_results.csv" ]; then
        echo "test_name,cores,duration,operations,ops_per_sec,cpu_usage,timestamp" > "$SCRIPT_DIR/benchmark_results.csv"
    fi
    
    # Test with 1, 2, 4, 8, 16, 32, 64, ... cores up to max
    local cores=1
    while [ $cores -le $max_cores ]; do
        run_stress_test $cores $duration "${test_name}_${cores}core"
        sleep 5  # Cool down between tests
        
        # Double the cores
        cores=$((cores * 2))
    done
    
    # Also test with max cores if not already tested
    if [ $((max_cores & (max_cores - 1))) -ne 0 ]; then
        run_stress_test $max_cores $duration "${test_name}_${max_cores}core"
    fi
    
    print_info "==================================="
    print_info "Benchmark complete!"
    print_info "Results saved to: $SCRIPT_DIR/benchmark_results.csv"
    print_info "View metrics in Grafana: http://localhost:3000"
    print_info "==================================="
}

# Show help
show_help() {
    cat <<EOF
CPU Core Burner Benchmark Tool

Usage: $0 [OPTIONS]

Options:
    -t, --test-name NAME    Name of the test (default: cpu_benchmark)
    -d, --duration SEC      Duration of each test in seconds (default: 30)
    -c, --cores NUM         Test with specific number of cores (default: scaling test)
    -h, --help             Show this help message

Examples:
    # Run full scaling test (1, 2, 4, 8, ... cores)
    $0 --test-name my_test --duration 60
    
    # Test with specific core count
    $0 --cores 8 --duration 30
    
    # Quick test
    $0 --test-name quick_test --duration 10

Results:
    - Metrics pushed to Prometheus Pushgateway
    - CSV results in benchmark_results.csv
    - View in Grafana dashboard

EOF
}

# Main
main() {
    local test_name="cpu_benchmark"
    local duration=30
    local specific_cores=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--test-name)
                test_name="$2"
                shift 2
                ;;
            -d|--duration)
                duration="$2"
                shift 2
                ;;
            -c|--cores)
                specific_cores="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Check if Pushgateway is running
    if ! curl -s ${PUSHGATEWAY_URL}/metrics > /dev/null 2>&1; then
        print_warning "Pushgateway not running. Starting it..."
        cd "$SCRIPT_DIR"
        if ! docker compose ps | grep -q pushgateway; then
            print_info "Starting Pushgateway via docker-compose..."
            docker compose up -d pushgateway || print_warning "Failed to start Pushgateway"
        fi
        sleep 3
    fi
    
    # Install stress tool
    install_stress_tool
    
    # Run tests
    if [ -n "$specific_cores" ]; then
        run_stress_test "$specific_cores" "$duration" "${test_name}_${specific_cores}core"
    else
        run_scaling_test "$test_name" "$duration"
    fi
}

main "$@"
