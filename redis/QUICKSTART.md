# Redis Benchmark Quick Start Guide

## Overview
Complete Redis benchmark infrastructure with system tuning, distributed testing, and results aggregation.

## Quick Commands

### Run a Single Benchmark Test
```bash
# Default test (cores=288, size=64, pipeline=1)
./run_benchmark.sh ping MyTest1

# Skip system tuning (if already tuned)
./run_benchmark.sh ping MyTest2 true
```

### Run Predefined Test Suites
```bash
# Quick test (minimal configuration)
./run_benchmark.sh ping quick

# Full comprehensive test
./run_benchmark.sh read full
```

### Manual Benchmark Execution
```bash
# Direct benchmark (no orchestration)
python3 benchmark_unified.py -o ping -c 288 -s 64 -p 1
python3 benchmark_unified.py -o read -c 144 -s 1024 -p 16
python3 benchmark_unified.py -o write -c 96 -s 512 -p 8
python3 benchmark_unified.py -o readwrite -c 192 -s 256 -p 4
```

### System Tuning
```bash
# Apply performance tuning
sudo ./tuning.sh apply

# Check current status
sudo ./tuning.sh status

# Revert to original settings
sudo ./tuning.sh revert
```

## Test Configurations

### Default Configuration
- Cores: 288
- Data Size: 64 bytes
- Pipeline: 1

### Quick Test
- Cores: 16
- Data Size: 64 bytes
- Pipeline: 1

### Full Test
- Cores: 16, 32, 64, 96, 128, 144, 192, 240, 288
- Data Sizes: 64, 512, 1024, 4096 bytes
- Pipelines: 1, 8, 16, 32

## Operation Types

| Operation | Description | Ratio | Best For |
|-----------|-------------|-------|----------|
| **ping** | Latency test | N/A | Connection latency |
| **read** | Read-only | 0:1 | GET performance |
| **write** | Write-only | 1:0 | SET performance |
| **readwrite** | Mixed | 1:1 | Real-world workload |

## Results Location

After running benchmarks, results are saved to:
```
./results/<test_name>/
├── Redis_<operation>_pipe-<p>_size-<s>_core-<c>_<name>.txt
├── summary_results.csv
├── tuning.log
└── SUMMARY.txt
```

## Customizing Tests

Edit `/home/wls/redis/run_benchmark.sh` lines 76-93:
```bash
# Modify these arrays as needed
CORES=(288)
SIZES=(64)
PIPELINES=(1)
```

## Network Configuration

**PING Operation:**
- Clients: 192.168.200.2-7 (6 servers)
- Redis Server: 192.168.200.1

**READ/WRITE/READWRITE Operations:**
- Clients: 192.168.100.2-3 (2 servers)
- Redis Server: 192.168.100.1

## SSH Configuration

Set password via environment variable:
```bash
export SSH_PASSWORD="your_password"
```

## Troubleshooting

**Benchmark doesn't start:**
- Check SSH connectivity to client servers
- Verify Redis servers are running
- Check network interface (ens6np0) exists

**Permission denied:**
- Run with sudo for tuning.sh
- Ensure benchmark_unified.py is executable

**Low performance:**
- Run system tuning first: `sudo ./tuning.sh apply`
- Check all 63 RX/TX queues have RPS/XPS enabled
- Verify CPUs are in performance mode

## Performance Tips

1. **Always tune system first** before benchmarks
2. **Cool down** 30 seconds between tests
3. **Monitor** system resources during tests
4. **Use dedicated** client and server machines
5. **Test incrementally** - start with quick tests

## File Structure

```
redis/
├── benchmark_unified.py      # Main benchmark script
├── run_benchmark.sh          # Master orchestrator
├── scaling_unified.sh        # Legacy scaling script
├── tuning.sh                 # System tuning script
├── server_script.sh          # Redis server launcher
├── output.sh                 # Results parser
└── results/                  # Benchmark outputs
```

## Support

For issues or questions, check:
- Benchmark logs in `results/<test_name>/`
- System tuning status: `sudo ./tuning.sh status`
- Network connectivity: `ping <client_ip>`
