# Generic Benchmark Runner - Configuration Guide

The benchmark system is now fully generic and supports any custom script with flexible KPI extraction.

## Quick Start

### 1. Create Your Configuration File

```bash
cp example_config.sh my_benchmark_config.sh
# Edit the configuration
nano my_benchmark_config.sh
```

### 2. Run Locally

```bash
./generic_runner.sh my_benchmark_config.sh [machine_name]
```

### 3. Run via Agent

```bash
python3 remote_agent.py <server>:8000 <machine_name> my_benchmark_config.sh
```

## Configuration File Structure

### Benchmark Settings

```bash
# Script to run (must be executable)
BENCHMARK_SCRIPT="./my_script.sh"

# Core configurations to test
CORE_LIST=("2" "4" "8" "16" "32")

# NUMA node (0, 1, 2, ... or -1 to disable)
NUMA_NODE=0

# Arguments passed to script
# Placeholders: {CORES}, {MACHINE}
SCRIPT_ARGS="--threads {CORES} --machine {MACHINE}"
```

### KPI Extraction Methods

#### Method 1: Regex (Most Flexible)

Extract values using regex patterns with capture groups:

```bash
EXTRACTION_METHOD="regex"

REGEX_PATTERNS=(
    "throughput:Throughput:[[:space:]]*([0-9.]+)"
    "latency:Latency:[[:space:]]*([0-9.]+)"
    "bandwidth:Bandwidth[=:[:space:]]+([0-9.]+)"
)
```

**Example Output:**
```
Throughput: 12345.67 ops/sec
Latency: 23.45 ms
Bandwidth = 678.9 MB/s
```

**Result:** Extracts `12345.67`, `23.45`, `678.9`

#### Method 2: Grep + Awk (Structured Data)

Extract from structured output using grep pattern and awk field:

```bash
EXTRACTION_METHOD="grep"

GREP_AWK_PATTERNS=(
    "bandwidth:^RESULT:2"
    "latency:^RESULT:3"
    "ops_per_sec:^RESULT:4"
)
```

**Example Output:**
```
RESULT 12345 67.8 90.1
```

**Result:** Field 2=`12345`, Field 3=`67.8`, Field 4=`90.1`

#### Method 3: JSON (Pre-formatted)

If your script already outputs JSON:

```bash
EXTRACTION_METHOD="json"
JSON_KEYS=("bandwidth" "latency" "throughput")
```

### Execution Settings

```bash
# Delay between core tests (seconds)
TEST_DELAY=1

# Timeout per test (0 = no timeout)
TEST_TIMEOUT=300

# Use numactl for NUMA binding
USE_NUMACTL=true

# Numactl arguments (placeholders: {NODE}, {CORES})
NUMACTL_ARGS="--cpunodebind={NODE} --physcpubind={CORES}"
```

### Custom Fields

Add static metadata to all results:

```bash
declare -A CUSTOM_FIELDS=(
    ["benchmark_type"]="network_test"
    ["version"]="2.1"
    ["environment"]="production"
)
```

## Complete Examples

### Example 1: Redis Benchmark

```bash
# redis_config.sh
BENCHMARK_SCRIPT="/usr/bin/redis-benchmark"
CORE_LIST=("1" "2" "4" "8")
NUMA_NODE=0
SCRIPT_ARGS="-t set,get -n 100000 -q"

EXTRACTION_METHOD="regex"
REGEX_PATTERNS=(
    "set_ops:SET:[[:space:]]*([0-9.]+)[[:space:]]*requests"
    "get_ops:GET:[[:space:]]*([0-9.]+)[[:space:]]*requests"
)

TEST_DELAY=2
TEST_TIMEOUT=120
USE_NUMACTL=false
```

### Example 2: Network Bandwidth (iperf)

```bash
# iperf_config.sh
BENCHMARK_SCRIPT="iperf3"
CORE_LIST=("1" "2" "4" "8" "16")
NUMA_NODE=0
SCRIPT_ARGS="-c 192.168.1.100 -t 10 -P {CORES}"

EXTRACTION_METHOD="regex"
REGEX_PATTERNS=(
    "bandwidth:SUM.*[[:space:]]([0-9.]+)[[:space:]]Gbits/sec.*sender"
    "retransmits:SUM.*[[:space:]]([0-9]+)[[:space:]].*sender"
)

TEST_DELAY=3
TEST_TIMEOUT=60
USE_NUMACTL=false
```

### Example 3: Custom Script with Structured Output

```bash
# custom_config.sh
BENCHMARK_SCRIPT="./my_benchmark.sh"
CORE_LIST=("2" "4" "8" "16" "32" "64")
NUMA_NODE=0
SCRIPT_ARGS="-c {CORES} -m {MACHINE}"

EXTRACTION_METHOD="grep"
GREP_AWK_PATTERNS=(
    "throughput:^PERF:2"
    "latency_p50:^PERF:3"
    "latency_p99:^PERF:4"
    "errors:^PERF:5"
)

TEST_DELAY=5
TEST_TIMEOUT=600
USE_NUMACTL=true
NUMACTL_ARGS="--cpunodebind={NODE} --physcpubind={CORES}"

declare -A CUSTOM_FIELDS=(
    ["test_type"]="custom_benchmark"
    ["datacenter"]="dc01"
)
```

Your script should output:
```
PERF: 12345 45.6 123.4 2
```

## Usage Patterns

### Local Execution

```bash
# Run with default config
./generic_runner.sh

# Run with custom config
./generic_runner.sh my_config.sh

# Run with custom config and machine name
./generic_runner.sh my_config.sh server-01
```

### Remote Agent

```bash
# Start agent with default config
python3 remote_agent.py 10.140.157.132:8000 server-01

# Start agent with custom config
python3 remote_agent.py 10.140.157.132:8000 server-01 redis_config.sh
```

### Dashboard Integration

The dashboard automatically handles any KPIs extracted. If your config extracts:
- `throughput` → Creates "Throughput" chart
- `latency` → Creates "Latency" chart  
- `bandwidth` → Creates "Bandwidth" chart
- Any other KPI → Displayed in stats

## Tips & Best Practices

### 1. Test Your Regex Patterns

```bash
# Test extraction locally
echo "Throughput: 12345.67 ops/sec" | grep -oP 'Throughput:[[:space:]]*\K[0-9.]+'
```

### 2. Validate Your Script

```bash
# Ensure script is executable
chmod +x ./my_script.sh

# Test manually first
./my_script.sh --test-args
```

### 3. Debug Output

Set `TEST_DELAY=0` and check stderr output:
```bash
./generic_runner.sh my_config.sh 2>&1 | grep "RAW OUTPUT"
```

### 4. Handle Failures Gracefully

The runner automatically handles:
- Script timeouts
- Non-zero exit codes
- Missing KPIs (defaults to 0)
- CPU utilization tracking

### 5. Multiple Configurations

Run different benchmarks on different machines:

```bash
# Machine 1: Redis benchmark
python3 remote_agent.py server:8000 redis-node redis_config.sh

# Machine 2: Network benchmark
python3 remote_agent.py server:8000 network-node iperf_config.sh

# Machine 3: MLC benchmark
python3 remote_agent.py server:8000 mem-node mlc_config.sh
```

All results appear on the same dashboard!

## Troubleshooting

### KPIs Not Extracted

1. Check raw output: Look for "RAW OUTPUT:" in stderr
2. Test regex: Use `echo "your_output" | grep -E "your_pattern"`
3. Verify field numbers in awk (1-indexed)

### Script Not Found

- Ensure `BENCHMARK_SCRIPT` path is correct
- Make script executable: `chmod +x script.sh`
- Use absolute path if needed

### NUMA Binding Issues

- Check numactl installed: `which numactl`
- Verify NUMA nodes: `numactl --hardware`
- Set `USE_NUMACTL=false` to disable

### Timeout Issues

- Increase `TEST_TIMEOUT`
- Check if script hangs
- Test script manually first
