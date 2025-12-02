# 🚀 CPU Core Burner - Quick Start Guide

## What You Have Now

✅ **Grafana + Prometheus** monitoring stack  
✅ **Pushgateway** for custom metrics  
✅ **CPU Benchmark** tool with automatic graphing  
✅ **Pre-built dashboard** for visualization  

## 📊 Run Your First Benchmark

### Option 1: Quick Example (Recommended to start)
```bash
cd /root/wls/graphana
./example-benchmark.sh
```
This will test 1, 2, 4, and 8 cores (20 seconds each).

### Option 2: Full Scaling Test
```bash
cd /root/wls/graphana
./cpu-benchmark.sh --test-name full_test --duration 30
```
This tests 1, 2, 4, 8, 16, 32... cores up to your max (192 cores).

### Option 3: Specific Core Count
```bash
cd /root/wls/graphana
./cpu-benchmark.sh --cores 16 --duration 60 --test-name my_test
```

## 📈 View Results in Grafana

1. **Open Grafana**: http://localhost:3000 (or http://10.140.157.132:3000)
2. **Login**: admin / admin
3. **Go to Dashboards** → "CPU Core Scaling Benchmark"
4. **Watch real-time graphs** as your tests run!

### What You'll See:
- **Line Graph**: Operations/sec vs Core Count (main performance chart)
- **Bar Chart**: Total operations completed
- **Line Chart**: CPU usage during tests
- **Bar Gauges**: Core counts tested and test durations
- **Pie Chart**: Operations distribution

## 🎯 Understanding the Results

### Example Output:
```
1 core:   1,000 ops/sec
2 cores:  2,000 ops/sec  (100% scaling efficiency)
4 cores:  3,800 ops/sec  (95% scaling efficiency)
8 cores:  7,200 ops/sec  (90% scaling efficiency)
16 cores: 13,600 ops/sec (85% scaling efficiency)
```

**Perfect scaling** = ops/sec doubles when cores double  
**Diminishing returns** = graph flattens at higher core counts (normal due to memory/cache limits)

## 📁 Results Storage

### 1. Real-time in Grafana
- Live graphs update as tests run
- Historical data preserved in Prometheus

### 2. CSV File
Location: `/root/wls/graphana/benchmark_results.csv`
```bash
# View results
cat /root/wls/graphana/benchmark_results.csv

# Get average ops/sec
awk -F',' 'NR>1 {sum+=$5; count++} END {print "Avg ops/sec:", sum/count}' /root/wls/graphana/benchmark_results.csv
```

## 🔧 Common Commands

```bash
cd /root/wls/graphana

# Quick 10-second test
./cpu-benchmark.sh --cores 8 --duration 10 --test-name quick_test

# Long stability test
./cpu-benchmark.sh --cores 32 --duration 300 --test-name stability_test

# Full scaling analysis
./cpu-benchmark.sh --test-name scaling_analysis --duration 60

# View current metrics
curl http://localhost:9091/metrics | grep cpu_benchmark

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | grep pushgateway

# Restart monitoring stack
./restart.sh

# View logs
./logs.sh prometheus
./logs.sh pushgateway
```

## 🎨 Dashboard Customization

The dashboard shows:
- **Real-time updates** (refreshes every 5 seconds)
- **Last 1 hour** of data (adjustable in time picker)
- **Multiple test runs** on same graph (compare different tests)

To modify:
1. Open dashboard in Grafana
2. Click any panel → Edit
3. Modify query, visualization, or settings
4. Save dashboard

## 💡 Pro Tips

### 1. Compare Different Configurations
```bash
# Test with different durations
./cpu-benchmark.sh --test-name short --duration 15
./cpu-benchmark.sh --test-name long --duration 120

# View both in Grafana - they'll show different colored lines
```

### 2. Automated Testing
```bash
# Create a test script
cat > ~/my_benchmark.sh <<'EOF'
#!/bin/bash
cd /root/wls/graphana
date
./cpu-benchmark.sh --test-name daily_$(date +%Y%m%d) --duration 60
EOF

chmod +x ~/my_benchmark.sh
```

### 3. Set CPU Governor for Consistent Results
```bash
# Set to performance mode (optional, for consistent results)
sudo cpupower frequency-set -g performance

# Check current governor
cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

### 4. Monitor During Benchmark
```bash
# In another terminal, watch CPU usage
watch -n 1 mpstat -P ALL 1 1

# Or use htop
htop
```

## 🐛 Troubleshooting

### No data in Grafana?
```bash
# Check services
cd /root/wls/graphana
docker compose ps

# Check if metrics are being pushed
curl http://localhost:9091/metrics | grep cpu_benchmark

# Check Prometheus can see Pushgateway
curl http://localhost:9090/api/v1/targets | grep pushgateway

# Restart everything
./restart.sh
```

### Dashboard not showing?
1. Refresh Grafana page
2. Check time range (top right) - set to "Last 1 hour"
3. Make sure you ran a benchmark recently
4. Check Datasource is set to "Prometheus"

### Script errors?
```bash
# Make sure stress-ng is installed
which stress-ng

# Check permissions
chmod +x /root/wls/graphana/cpu-benchmark.sh

# Run with debug
bash -x /root/wls/graphana/cpu-benchmark.sh --cores 2 --duration 10 --test-name debug_test
```

## 📚 Next Steps

### Run Comprehensive Analysis
```bash
cd /root/wls/graphana
./cpu-benchmark.sh --test-name comprehensive_$(date +%Y%m%d) --duration 120
```

### Compare with Workloads
Run your actual workloads (Redis, MongoDB, Cassandra) and compare CPU usage patterns.

### Export Results
```bash
# Export dashboard as PDF (from Grafana web UI)
# Or export metrics
curl 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second' | python3 -m json.tool > results.json
```

## 🎯 Example Use Cases

### 1. Find Optimal Core Count
```bash
# Test all powers of 2
./cpu-benchmark.sh --test-name optimal_cores --duration 60
# Look at the graph - where does it flatten? That's your optimal point.
```

### 2. Stress Test
```bash
# Run max cores for extended period
./cpu-benchmark.sh --cores $(nproc) --duration 600 --test-name stress_test
```

### 3. Performance Regression Testing
```bash
# Run before and after system changes
./cpu-benchmark.sh --test-name before_update --duration 60
# ... apply updates ...
./cpu-benchmark.sh --test-name after_update --duration 60
# Compare graphs in Grafana
```

## 📞 Quick Reference

| Command | What it does |
|---------|-------------|
| `./example-benchmark.sh` | Quick demo (1,2,4,8 cores) |
| `./cpu-benchmark.sh --help` | Show all options |
| `./test.sh` | Check if monitoring is working |
| `./restart.sh` | Restart all services |
| `./logs.sh prometheus` | View Prometheus logs |
| `docker compose ps` | Check service status |

---

**Ready to start? Run this:**
```bash
cd /root/wls/graphana
./example-benchmark.sh
```

Then open http://localhost:3000 and watch your graphs! 🎉
