# MLC Benchmark Dashboard

A real-time, multi-machine benchmark dashboard with centralized control. Run any benchmark script on multiple systems and visualize results in one place.

## 🚀 Quick Start

### System 1 (Dashboard + Workload)
```bash
cd /root/wls/Graph_plot
./setup.sh                    # Install dependencies
./start.sh                    # Start dashboard
# Open: http://<system1-ip>:8000
```

### System 2 (Workload Only)
```bash
cd /root/wls/Graph_plot
./setup.sh                    # Install dependencies
python3 remote_agent.py <system1-ip>:8000 system2 ali_benchmark_config.sh
```

### Run Benchmarks
1. Open dashboard in browser
2. Click **"▶️ Run All Benchmarks"**
3. Watch real-time results!

---

## 📋 Features

- ✅ **Multi-Machine Support** - Run benchmarks on multiple systems simultaneously
- ✅ **Centralized Control** - Trigger all machines from one dashboard
- ✅ **Generic Framework** - Support any benchmark script (MLC, Redis, custom workloads)
- ✅ **Flexible KPI Extraction** - Regex, grep/awk, or file-based extraction
- ✅ **Real-time Visualization** - Live charts with color-coded results per machine
- ✅ **Auto-Reconnect** - Agents reconnect automatically if disconnected
- ✅ **Core Scaling** - Test with different core/thread configurations

---

## 📁 Project Structure

```
Graph_plot/
├── server.py                   # Dashboard server (FastAPI + WebSockets)
├── index.html                  # Web dashboard UI
├── generic_runner.sh           # Universal benchmark runner
├── remote_agent.py             # Remote agent (waits for commands)
├── trigger_all.sh              # CLI trigger for benchmarks
├── setup.sh                    # One-time setup script
├── start.sh                    # Start dashboard server
│
├── ali_benchmark_config.sh     # Example: ALI workload config
├── mlc_config.sh               # Example: Intel MLC config
├── example_config.sh           # Template for custom benchmarks
└── benchmark_config.sh         # Default configuration
```

---

## 🔧 Setup Instructions

### Prerequisites
- Linux (Ubuntu, RHEL, CentOS, Fedora, etc.)
- Python 3.7+
- Network connectivity between systems

### Installation

```bash
# Clone repository
git clone https://github.com/ntamraka/wls.git
cd wls/Graph_plot

# Run setup (installs dependencies)
./setup.sh
```

This installs:
- Python packages: FastAPI, Uvicorn, WebSockets
- numactl (for NUMA binding)
- Makes all scripts executable

---

## 🎯 Usage

### 1. Configure Your Benchmark

Create or edit a config file (e.g., `my_benchmark_config.sh`):

```bash
# Benchmark script to run
BENCHMARK_SCRIPT="./my_script.sh"

# Core/thread configurations
CORE_LIST=("2" "4" "8" "16" "32")

# Script arguments (use {CORES} placeholder)
SCRIPT_ARGS="--threads {CORES} --duration 10"

# KPI extraction method
EXTRACTION_METHOD="regex"
REGEX_PATTERNS=(
    "throughput:Throughput:[[:space:]]*([0-9.]+)"
    "latency:Latency:[[:space:]]*([0-9.]+)"
)

# Execution settings
TEST_DELAY=2
TEST_TIMEOUT=300
USE_NUMACTL=true
```

See `CONFIGURATION_GUIDE.md` for detailed configuration options.

### 2. Start Dashboard Server

```bash
./start.sh
# Dashboard available at: http://localhost:8000
```

### 3. Start Remote Agents

On each remote machine:

```bash
python3 remote_agent.py <server-ip>:8000 <machine-name> <config-file>

# Example:
python3 remote_agent.py 10.140.157.132:8000 server-02 ali_benchmark_config.sh
```

### 4. Run Benchmarks

**Option A: Web Dashboard**
1. Open `http://<server-ip>:8000`
2. See connected agents in control panel
3. Click "▶️ Run All Benchmarks"

**Option B: Command Line**
```bash
./trigger_all.sh <server-ip>:8000
```

---

## 📊 Supported Benchmarks

### Pre-configured Examples

1. **Intel MLC** (`mlc_config.sh`)
   - Memory latency and bandwidth
   - NUMA-aware testing

2. **ALI Workload** (`ali_benchmark_config.sh`)
   - VM scaling (1-18 cores)
   - KPI extraction from CSV files

3. **Custom Scripts** (`example_config.sh`)
   - Template for any benchmark
   - Redis, iperf3, sysbench, etc.

### Adding Your Benchmark

```bash
# 1. Copy template
cp example_config.sh my_config.sh

# 2. Edit configuration
nano my_config.sh

# 3. Test locally
./generic_runner.sh my_config.sh

# 4. Deploy to agents
python3 remote_agent.py <server>:8000 machine1 my_config.sh
```

---

## 🔍 KPI Extraction Methods

### Method 1: Regex (Most Flexible)
```bash
EXTRACTION_METHOD="regex"
REGEX_PATTERNS=(
    "ops:Operations:[[:space:]]*([0-9.]+)"
    "latency:Latency:[[:space:]]*([0-9.]+)"
)
```
Extracts from output like: `"Operations: 12345.67 ops/sec"`

### Method 2: Grep + Awk (Structured Data)
```bash
EXTRACTION_METHOD="grep"
GREP_AWK_PATTERNS=(
    "bandwidth:^RESULT:2"    # Field 2 from lines matching ^RESULT
    "latency:^RESULT:3"      # Field 3
)
```
Extracts from output like: `"RESULT 12345 67.8 90.1"`

### Method 3: File (Read from File)
```bash
EXTRACTION_METHOD="file"
KPI_FILE="results/test_{CORES}/output.csv"
```
Reads KPI value directly from file.

---

## 🏗️ Architecture

```
┌──────────────────────────────────────────┐
│         Dashboard Server (System 1)      │
│  ┌──────────┐  ┌──────────┐             │
│  │ Web UI   │  │ Control  │             │
│  │ Browser  │  │   API    │             │
│  └────┬─────┘  └────┬─────┘             │
│       │             │                    │
│       └─────┬───────┘                    │
│             │ WebSocket Broker           │
└─────────────┼────────────────────────────┘
              │
    ┌─────────┼─────────┐
    │         │         │
┌───▼───┐ ┌───▼───┐ ┌───▼───┐
│Agent 1│ │Agent 2│ │Agent 3│
│(Waits)│ │(Waits)│ │(Waits)│
└───────┘ └───────┘ └───────┘
```

**Flow:**
1. Agents connect to dashboard and wait
2. User clicks "Run All" in dashboard
3. Server sends command to all agents
4. Agents execute benchmarks
5. Results stream back to dashboard in real-time

---

## 🛠️ Troubleshooting

### Agents Not Connecting

```bash
# Check connectivity
ping <server-ip>

# Test dashboard accessibility
curl http://<server-ip>:8000

# Check firewall (on server)
sudo ufw allow 8000
```

### Benchmark Not Running

```bash
# Test benchmark script manually
./generic_runner.sh my_config.sh test

# Check script is executable
chmod +x ./my_script.sh

# Verify config file paths
cat my_config.sh
```

### No KPI Data

```bash
# Enable debug output
./generic_runner.sh my_config.sh 2>&1 | grep "RAW OUTPUT"

# Test regex pattern
echo "Throughput: 123.45" | grep -oP 'Throughput:[[:space:]]*\K[0-9.]+'

# Check file extraction path
ls -l results/
```

### Dashboard Not Loading

```bash
# Check if server is running
ps aux | grep uvicorn

# Restart server
pkill -f "uvicorn server:app"
./start.sh

# Check logs
tail -f nohup.out
```

---

## 📖 Documentation

- **CONFIGURATION_GUIDE.md** - Detailed config options, examples, patterns
- **SETUP_GUIDE.md** - Step-by-step 2-system setup walkthrough
- **README_MULTI_MACHINE.md** - Multi-machine architecture details

---

## 🔄 Workflow Example

### Scenario: Compare 3 Servers Running ALI Workload

**Step 1: Setup**
```bash
# Server 1: Dashboard + Agent
cd /root/wls/Graph_plot
./start.sh &
python3 remote_agent.py localhost:8000 server1 ali_benchmark_config.sh &

# Server 2: Agent only
cd /root/wls/Graph_plot
python3 remote_agent.py 10.140.157.132:8000 server2 ali_benchmark_config.sh &

# Server 3: Agent only
cd /root/wls/Graph_plot
python3 remote_agent.py 10.140.157.132:8000 server3 ali_benchmark_config.sh &
```

**Step 2: Run & Compare**
- Open browser: `http://10.140.157.132:8000`
- See all 3 servers connected
- Click "Run All Benchmarks"
- Watch all 3 run simultaneously
- Compare results on same charts (color-coded per server)

---

## 💡 Tips

- **Use `screen` or `tmux`** for persistent agent sessions
- **Custom core lists** - Edit `CORE_LIST` in config for specific scaling tests
- **Multiple configs** - Run different benchmarks on different machines
- **Save configs** - Version control your benchmark configurations
- **Background execution** - Agents auto-reconnect, safe to run in background

---

## 🤝 Contributing

This is a flexible, extensible framework. Add your own:
- Benchmark configurations
- KPI extraction patterns
- Visualization enhancements

---

## 📄 License

See repository license file.

---

## 🆘 Support

For issues:
1. Check agent terminal output
2. Review dashboard server logs
3. Test benchmark script manually
4. Verify network connectivity
5. Check firewall settings

**Common Issues:**
- Agents not showing → Check WebSocket connection, firewall
- No data → Verify KPI extraction patterns
- Script fails → Test manually with `./generic_runner.sh`
- Connection drops → Agents auto-reconnect, be patient

---

**Quick Commands Reference:**

| Task | Command |
|------|---------|
| Install | `./setup.sh` |
| Start Dashboard | `./start.sh` |
| Start Agent | `python3 remote_agent.py <server>:8000 <name> <config>` |
| Trigger Benchmarks | Click "Run All" in dashboard OR `./trigger_all.sh <server>:8000` |
| Test Config | `./generic_runner.sh my_config.sh test` |

---

**URLs:**
- Dashboard: `http://<server-ip>:8000`
- Repository: https://github.com/ntamraka/wls
