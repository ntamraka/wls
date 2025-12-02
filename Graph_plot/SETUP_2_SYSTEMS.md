# 2-System Setup Guide - MLC Benchmark Dashboard

This guide shows you how to set up the benchmark dashboard on 2 systems:
- **System 1**: Dashboard Server + Runs workload
- **System 2**: Remote Agent (runs workload only)

---

## Prerequisites

Both systems need:
- Linux OS (Ubuntu, RHEL, CentOS, etc.)
- Python 3.7+
- Network connectivity between systems
- Root or sudo access

---

## System 1: Dashboard Server Setup

This system will run the dashboard web interface AND execute benchmarks locally.

### Step 1: Copy Files

```bash
# On System 1
cd /root
git clone <your-repo> wls
# OR copy the Graph_plot folder via scp
```

### Step 2: Run Quick Setup

```bash
cd /root/wls/Graph_plot
chmod +x quick_setup.sh
./quick_setup.sh
```

When prompted:
- **Select option 1**: Dashboard Server

The script will:
- Install Python dependencies
- Install numactl
- Configure everything automatically

### Step 3: Start Dashboard

```bash
./start.sh
```

Output will show:
```
Dashboard will be available at:
  http://localhost:8000
  http://10.140.157.132:8000    # Your actual IP
```

**Note the IP address - you'll need it for System 2!**

### Step 4: Access Dashboard

Open a browser and go to: `http://<system1-ip>:8000`

You should see:
- Real-time dashboard with charts
- Control panel showing "No agents connected"
- Status indicator

### Step 5: Test Local Workload

In a new terminal on System 1:

```bash
cd /root/wls/Graph_plot

# Option A: Run once manually
./generic_runner.sh benchmark_config.sh system1

# Option B: Start agent for remote control
python3 remote_agent.py localhost:8000 system1 benchmark_config.sh
```

Refresh the dashboard - you'll see System 1's results!

---

## System 2: Remote Agent Setup

This system will only run workloads when triggered from the dashboard.

### Step 1: Copy Files to System 2

```bash
# From System 1, copy to System 2
scp -r /root/wls/Graph_plot user@system2-ip:/path/to/destination/

# OR on System 2, clone the repo
cd /root
git clone <your-repo> wls
```

### Step 2: Run Quick Setup on System 2

```bash
cd /root/wls/Graph_plot
chmod +x quick_setup.sh
./quick_setup.sh
```

When prompted:
- **Select option 2**: Workload Agent Only
- **Dashboard Server IP**: Enter System 1's IP (e.g., `10.140.157.132`)
- **Port**: Press Enter for default `8000`
- **Machine Name**: Enter `system2` (or any unique name)
- **Config File**: Press Enter for default `benchmark_config.sh`

The script will:
- Install dependencies
- Test connection to System 1
- Create a startup script

### Step 3: Start Agent on System 2

```bash
./start_agent.sh
```

You should see:
```
======================================
Remote Agent - Generic Benchmark Runner
======================================
Dashboard Server: 10.140.157.132:8000
Machine ID: system2
Config File: benchmark_config.sh
Hostname: system2
======================================
Agent is running and waiting for commands...
Press Ctrl+C to stop
======================================
[AGENT] Connecting to dashboard...
[AGENT] Connected and registered as 'system2'
```

### Step 4: Verify on Dashboard

Go back to System 1's dashboard (`http://<system1-ip>:8000`)

You should now see:
- **Control Panel** showing 2 connected agents: `system1` and `system2`
- Green badges for each agent

---

## Running Benchmarks on Both Systems

### Method 1: From Web Dashboard (Recommended)

1. Open dashboard: `http://<system1-ip>:8000`
2. See both agents in the control panel
3. Click **"▶️ Run All Benchmarks"**
4. Watch real-time results from BOTH systems appear on the same dashboard!

### Method 2: From Command Line

On System 1:

```bash
cd /root/wls/Graph_plot
./trigger_all.sh localhost:8000
```

### Method 3: Run Specific Machine

On the dashboard, you can also trigger individual machines (future feature) or manually:

```bash
# On System 1 or 2, run immediately without waiting for trigger
./generic_runner.sh benchmark_config.sh machine-name
```

---

## Verification Checklist

### ✅ System 1 (Dashboard Server)

- [ ] Dashboard accessible at `http://<ip>:8000`
- [ ] Control panel visible
- [ ] Can trigger benchmarks from UI
- [ ] Charts display correctly
- [ ] Local agent (if started) appears in agent list

### ✅ System 2 (Remote Agent)

- [ ] Agent connects successfully
- [ ] Shows "Connected and registered" message
- [ ] Appears in System 1's dashboard control panel
- [ ] Executes benchmarks when triggered
- [ ] Results stream to dashboard

### ✅ Both Systems

- [ ] Network connectivity (ping works)
- [ ] Port 8000 accessible
- [ ] Python dependencies installed
- [ ] numactl installed
- [ ] MLC binary or benchmark script present

---

## Quick Reference Commands

### System 1 (Dashboard Server)

```bash
# Start dashboard
cd /root/wls/Graph_plot
./start.sh

# Stop dashboard
pkill -f "uvicorn server:app"

# Run local workload
./generic_runner.sh benchmark_config.sh system1

# Start local agent for remote control
python3 remote_agent.py localhost:8000 system1

# Trigger all agents
./trigger_all.sh localhost:8000
```

### System 2 (Remote Agent)

```bash
# Start agent
cd /root/wls/Graph_plot
./start_agent.sh

# Stop agent
Ctrl+C (or kill the process)

# Restart agent
./start_agent.sh

# Run manual test (bypasses dashboard)
./generic_runner.sh benchmark_config.sh system2
```

---

## Firewall Configuration

If agents can't connect, open port 8000 on System 1:

### Ubuntu/Debian (ufw)
```bash
sudo ufw allow 8000/tcp
sudo ufw reload
```

### RHEL/CentOS (firewalld)
```bash
sudo firewall-cmd --permanent --add-port=8000/tcp
sudo firewall-cmd --reload
```

### Check port is listening
```bash
# On System 1
netstat -tuln | grep 8000
# Should show: tcp 0.0.0.0:8000 LISTEN

# From System 2, test connectivity
telnet <system1-ip> 8000
# OR
curl http://<system1-ip>:8000
```

---

## Customizing Benchmarks

Both systems can run different benchmarks! Edit configuration files:

### System 1: Use MLC benchmark
```bash
cd /root/wls/Graph_plot
# Edit or use default
cat benchmark_config.sh
```

### System 2: Use custom benchmark
```bash
cd /root/wls/Graph_plot
# Create custom config
cp example_config.sh my_custom_config.sh
nano my_custom_config.sh

# Start agent with custom config
python3 remote_agent.py <system1-ip>:8000 system2 my_custom_config.sh
```

See `CONFIGURATION_GUIDE.md` for details on creating custom benchmark configs.

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     System 1                                │
│                  (10.140.157.132)                           │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Dashboard Server                        │  │
│  │  - FastAPI WebSocket Server                         │  │
│  │  - Web UI (http://:8000)                           │  │
│  │  - Control Panel                                    │  │
│  │  - Real-time Charts                                 │  │
│  └──────────────────────────────────────────────────────┘  │
│                          ▲                                  │
│                          │                                  │
│  ┌──────────────────────┴───────────────────────────────┐  │
│  │         Local Agent (Optional)                       │  │
│  │  python3 remote_agent.py localhost:8000 system1      │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                          ▲
                          │ WebSocket
                          │ (Port 8000)
                          │
┌─────────────────────────┴───────────────────────────────────┐
│                     System 2                                │
│                  (10.140.157.140)                           │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Remote Agent                            │  │
│  │  python3 remote_agent.py 10.140.157.132:8000        │  │
│  │  - Waits for commands                               │  │
│  │  - Executes benchmarks                              │  │
│  │  - Streams results                                  │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Troubleshooting

### Agent can't connect

**Check connectivity:**
```bash
# From System 2
ping <system1-ip>
telnet <system1-ip> 8000
```

**Check dashboard is running:**
```bash
# On System 1
ps aux | grep uvicorn
curl http://localhost:8000
```

**Check firewall:**
```bash
# On System 1
sudo ufw status
sudo firewall-cmd --list-all
```

### No data appearing on dashboard

**Check agent logs:**
- Agent should show "Connected and registered"
- When triggered, should show "Starting benchmark"

**Check benchmark script:**
```bash
# Test manually
./generic_runner.sh benchmark_config.sh test
# Should output JSON
```

**Check browser console:**
- Press F12 in browser
- Look for WebSocket connection errors
- Check for JavaScript errors

### MLC binary not found

```bash
# Download MLC from Intel
# Place in Graph_plot directory
chmod +x mlc_internal
```

---

## Summary

**2-System Setup in 5 Minutes:**

1. **System 1**: Run `./quick_setup.sh` → Select "1" → `./start.sh`
2. **System 2**: Run `./quick_setup.sh` → Select "2" → Enter System 1 IP → `./start_agent.sh`
3. **Dashboard**: Open `http://<system1-ip>:8000`
4. **Run**: Click "▶️ Run All Benchmarks"
5. **Watch**: Real-time results from both systems!

For more systems, repeat Step 2 on each additional machine.
