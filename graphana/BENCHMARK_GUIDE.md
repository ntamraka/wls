# CPU Core Scaling Benchmark

Automated benchmarking tool to test CPU performance across different core counts and visualize results in Grafana.

## 🚀 Quick Start

```bash
cd /root/wls/graphana

# Run a full scaling benchmark (tests 1, 2, 4, 8, 16... cores)
./cpu-benchmark.sh --test-name my_test --duration 30

# Test with specific core count
./cpu-benchmark.sh --cores 8 --duration 60

# Quick test (10 seconds per core count)
./cpu-benchmark.sh --test-name quick_test --duration 10
```

## 📊 View Results in Grafana

1. Open Grafana: http://localhost:3000
2. Go to **Dashboards** → **CPU Core Scaling Benchmark**
3. Watch real-time performance metrics as tests run

## 📈 What It Measures

- **Operations per Second**: Performance scaling with core count
- **Total Operations**: Cumulative work done
- **CPU Usage**: Resource utilization during tests
- **Test Duration**: Actual runtime for each configuration

## 🛠️ Usage Examples

### Full Scaling Test
Tests performance with 1, 2, 4, 8, 16, 32... cores up to your system maximum:
```bash
./cpu-benchmark.sh --test-name full_scaling --duration 60
```

### Compare Different Durations
```bash
# Quick test
./cpu-benchmark.sh --test-name quick --duration 10

# Long test
./cpu-benchmark.sh --test-name long --duration 300
```

### Test Specific Core Counts
```bash
# Test with 4 cores
./cpu-benchmark.sh --cores 4 --duration 30

# Test with 16 cores
./cpu-benchmark.sh --cores 16 --duration 30

# Test with 64 cores
./cpu-benchmark.sh --cores 64 --duration 30
```

## 📁 Results

Results are saved in two formats:

1. **Prometheus Metrics**: Real-time in Grafana dashboards
2. **CSV File**: `benchmark_results.csv` for offline analysis

CSV Format:
```
test_name,cores,duration,operations,ops_per_sec,cpu_usage,timestamp
my_test_1core,1,30,30000,1000,25.5,2025-11-28 18:30:00
my_test_2core,2,30,58000,1933,48.2,2025-11-28 18:31:00
...
```

## 🔧 Advanced Usage

### Custom Test Scenarios

Create a script to test specific scenarios:
```bash
#!/bin/bash
# test-scenarios.sh

# Test low core counts
for cores in 1 2 4 8; do
    ./cpu-benchmark.sh --cores $cores --duration 60 --test-name low_core_test
    sleep 10
done

# Test high core counts
for cores in 32 64 128; do
    ./cpu-benchmark.sh --cores $cores --duration 60 --test-name high_core_test
    sleep 10
done
```

### Analyze Results

```bash
# View CSV results
cat benchmark_results.csv

# Get summary statistics
awk -F',' 'NR>1 {sum+=$5; count++} END {print "Average ops/sec:", sum/count}' benchmark_results.csv

# Find best performing configuration
awk -F',' 'NR>1 {print $2, $5}' benchmark_results.csv | sort -k2 -nr | head -1
```

## 📊 Dashboard Panels

The Grafana dashboard includes:

1. **Main Graph**: Operations/sec vs Core Count (line chart with points)
2. **Total Operations**: Bar chart showing total work done
3. **CPU Usage**: Line chart showing resource utilization
4. **Core Counts**: Bar gauge of tested configurations
5. **Test Duration**: Actual runtime for each test
6. **Operations Distribution**: Pie chart of work distribution

## 🔍 Metrics Explained

### cpu_benchmark_ops_per_second
Operations performed per second. Higher is better. Shows how performance scales with core count.

### cpu_benchmark_operations_total
Total number of operations completed. Counter metric.

### cpu_benchmark_cpu_usage_percent
Average CPU usage during the test (0-100%).

### cpu_benchmark_duration_seconds
Actual duration of the test in seconds.

### cpu_benchmark_cores
Number of CPU cores used in the test.

## 🎯 Interpreting Results

### Perfect Scaling
If ops/sec doubles when cores double, you have perfect linear scaling.

Example:
- 1 core: 1000 ops/sec
- 2 cores: 2000 ops/sec
- 4 cores: 4000 ops/sec

### Scaling Efficiency
Calculate scaling efficiency:
```
Efficiency = (actual_ops/sec) / (cores * baseline_ops/sec) * 100%
```

Where baseline is the ops/sec for 1 core.

### Diminishing Returns
If the graph flattens at higher core counts, you're hitting bottlenecks:
- Memory bandwidth
- Cache contention
- System resources

## 🛠️ Troubleshooting

### Pushgateway not accessible
```bash
cd /root/wls/graphana
docker compose up -d pushgateway
```

### stress-ng not installed
The script auto-installs it, but you can manually install:
```bash
sudo apt-get install stress-ng  # Ubuntu/Debian
sudo yum install stress-ng      # RHEL/CentOS
```

### No data in Grafana
1. Check if Pushgateway is running: `curl http://localhost:9091/metrics`
2. Check Prometheus targets: http://localhost:9090/targets
3. Wait 15 seconds for Prometheus to scrape
4. Refresh the Grafana dashboard

### Permission errors
```bash
sudo ./cpu-benchmark.sh --test-name test --duration 10
```

## 📚 Additional Commands

```bash
# Check Pushgateway metrics
curl http://localhost:9091/metrics | grep cpu_benchmark

# Query Prometheus directly
curl 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second'

# View Pushgateway web UI
# Open: http://localhost:9091

# Clear old metrics from Pushgateway
curl -X DELETE http://localhost:9091/metrics/job/cpu_benchmark
```

## 🔄 Continuous Benchmarking

Run benchmarks periodically to track performance over time:

```bash
# Add to crontab
# Run daily at 2 AM
0 2 * * * cd /root/wls/graphana && ./cpu-benchmark.sh --test-name daily_benchmark --duration 60
```

## 💡 Pro Tips

1. **Cool Down**: Wait 5-10 seconds between tests to avoid thermal throttling
2. **Consistent Load**: Keep background processes minimal during testing
3. **Multiple Runs**: Run each configuration 3-5 times and average results
4. **Governor Settings**: Set CPU governor to "performance" for consistent results:
   ```bash
   sudo cpupower frequency-set -g performance
   ```
5. **NUMA Awareness**: For multi-socket systems, test NUMA effects
6. **Time Range**: Set Grafana time range to match your test duration

## 🎨 Customizing the Dashboard

To modify the dashboard:
1. Open Grafana → Dashboards → CPU Core Scaling Benchmark
2. Click the gear icon (⚙️) → Dashboard settings
3. Make changes and click "Save dashboard"
4. Export JSON from Settings → JSON Model
5. Save to: `/root/wls/graphana/grafana/dashboards/cpu-benchmark.json`
