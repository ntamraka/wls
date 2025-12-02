# ALI Workload Setup - 2 Systems

Quick setup guide for running ALI workload benchmarks on 2 systems with centralized dashboard.

---

## 🎯 Overview

- **System 1**: Dashboard + Workload (your main server)
- **System 2**: Workload only (remote server)
- **Result**: Both systems run ALI workload (1-18 VMs), results visualized on one dashboard

---

## 📋 Prerequisites

Both systems need:
- Linux OS
- Python 3.7+
- Network connectivity (can ping each other)
- ALI workload scripts at: `/home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/`

---

## 🚀 Setup Steps

### **System 1: Dashboard + Workload**

#### 1. Clone Repository
```bash
cd /root
git clone https://github.com/ntamraka/wls.git
cd wls/Graph_plot
```

#### 2. Install Dependencies
```bash
./setup.sh
```

This installs:
- FastAPI, Uvicorn, WebSockets (Python packages)
- numactl (if not already installed)

#### 3. Start Dashboard Server
```bash
./start.sh
```

Output should show:
```
Dashboard started at http://0.0.0.0:8000
Running in background (PID: xxxxx)
```

#### 4. Verify Dashboard is Running
```bash
# Check if server is running
ps aux | grep uvicorn

# Test web access
curl http://localhost:8000
```

#### 5. Open Dashboard in Browser
```
http://<system1-ip>:8000
```

You should see the dashboard with an empty chart.

#### 6. Start Local Agent (System 1)
```bash
cd /root/wls/Graph_plot
python3 remote_agent.py localhost:8000 system1 ali_benchmark_config.sh
```

Output should show:
```
🔌 Connecting to ws://localhost:8000/ws/agent...
✅ Connected to server as 'system1'
⏳ Waiting for commands from dashboard...
```

**Keep this terminal open!** The agent waits for commands.

---

### **System 2: Workload Only**

#### 1. Clone Repository
```bash
cd /root
git clone https://github.com/ntamraka/wls.git
cd wls/Graph_plot
```

#### 2. Install Dependencies
```bash
./setup.sh
```

#### 3. Test Connection to System 1
```bash
# Replace <system1-ip> with actual IP
ping <system1-ip>
curl http://<system1-ip>:8000
```

#### 4. Start Remote Agent
```bash
cd /root/wls/Graph_plot
python3 remote_agent.py <system1-ip>:8000 system2 ali_benchmark_config.sh
```

Example:
```bash
python3 remote_agent.py 10.140.157.132:8000 system2 ali_benchmark_config.sh
```

Output should show:
```
🔌 Connecting to ws://10.140.157.132:8000/ws/agent...
✅ Connected to server as 'system2'
⏳ Waiting for commands from dashboard...
```

**Keep this terminal open!** The agent waits for commands.

---

## ▶️ Run Benchmarks

### Method 1: Web Dashboard (Recommended)

1. Open dashboard: `http://<system1-ip>:8000`
2. Check "Connected Agents" panel shows both systems:
   - `system1`
   - `system2`
3. Click **"▶️ Run All Benchmarks"** button
4. Watch real-time results!

Both systems will:
- Run ALI workload with 1-18 VMs sequentially
- Stream results back to dashboard
- Display results on same chart (color-coded by system)

### Method 2: Command Line

From System 1:
```bash
cd /root/wls/Graph_plot
./trigger_all.sh localhost:8000
```

---

## 📊 What Happens During Benchmark

For each VM count (1-18), each system will:

1. **Clean up previous results**
   ```bash
   rm -rf /home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/results/SRF_*
   ```

2. **Run ALI workload**
   ```bash
   /home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/start_ali_clients.sh 1 SRF_C0288c_1 1
   ```

3. **Extract KPI from CSV**
   ```bash
   cat /home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/results/SRF_C0288c_1/data_wrk_1.out.csv
   ```

4. **Send results to dashboard**
   ```json
   {"host": "system1", "cores": 1, "requests": 12345}
   ```

Total time: ~10-15 minutes per system (18 VMs × ~30-60 seconds each)

---

## 🔍 Troubleshooting

### Issue: Agent Not Connecting

**Symptom**: Agent shows connection refused or timeout

**Solutions**:
```bash
# On System 1: Check firewall
sudo ufw status
sudo ufw allow 8000

# On System 2: Test connectivity
ping <system1-ip>
telnet <system1-ip> 8000
curl http://<system1-ip>:8000
```

### Issue: Dashboard Not Showing Agents

**Symptom**: Agent terminal shows connected, but dashboard doesn't list it

**Solutions**:
```bash
# Refresh browser page
# Check agent terminal for errors
# Restart dashboard:
pkill -f "uvicorn server:app"
./start.sh
```

### Issue: Benchmark Not Running

**Symptom**: Agent connected, but nothing happens after clicking "Run All"

**Solutions**:
```bash
# Check ALI script exists and is executable
ls -la /home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/start_ali_clients.sh
chmod +x /home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/start_ali_clients.sh

# Test manually
cd /home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali
./start_ali_clients.sh 1 test 1

# Check results directory
ls -la results/
```

### Issue: No KPI Data Showing

**Symptom**: Benchmark runs but charts show 0 or no data

**Solutions**:
```bash
# Check if CSV file is created
ls -la /home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/results/SRF_C0288c_*/

# Check CSV content
cat /home/sr/gtkachuk.libvirt-vm-scaling-scripts-16vCPU/version2.0/ali/results/SRF_C0288c_1/data_wrk_1.out.csv

# Should contain a number like: 12345
```

### Issue: Agent Disconnects

**Symptom**: Agent loses connection during benchmark

**Solution**: Agents auto-reconnect! Just wait 5 seconds, it will reconnect and continue.

---

## 💡 Tips

### Use Screen/Tmux for Persistent Sessions

Instead of keeping terminals open:

**System 1:**
```bash
# Dashboard
screen -S dashboard
cd /root/wls/Graph_plot && ./start.sh
# Detach: Ctrl+A then D

# Agent
screen -S agent1
cd /root/wls/Graph_plot && python3 remote_agent.py localhost:8000 system1 ali_benchmark_config.sh
# Detach: Ctrl+A then D
```

**System 2:**
```bash
screen -S agent2
cd /root/wls/Graph_plot && python3 remote_agent.py <system1-ip>:8000 system2 ali_benchmark_config.sh
# Detach: Ctrl+A then D
```

Reattach later:
```bash
screen -r dashboard  # or agent1, agent2
```

### Customize VM Range

Edit `ali_benchmark_config.sh` to test specific VMs:

```bash
nano /root/wls/Graph_plot/ali_benchmark_config.sh

# Change this line:
CORE_LIST=("1" "2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12" "13" "14" "15" "16" "17" "18")

# To test only specific VMs:
CORE_LIST=("1" "4" "8" "16")
```

Restart agent after changing config.

### Add More Systems

Just repeat System 2 steps on additional machines:
```bash
python3 remote_agent.py <system1-ip>:8000 system3 ali_benchmark_config.sh
python3 remote_agent.py <system1-ip>:8000 system4 ali_benchmark_config.sh
```

All will appear in dashboard and run simultaneously!

---

## 📝 Summary Commands

### System 1 (One-time Setup)
```bash
git clone https://github.com/ntamraka/wls.git
cd wls/Graph_plot
./setup.sh
./start.sh
python3 remote_agent.py localhost:8000 system1 ali_benchmark_config.sh
```

### System 2 (One-time Setup)
```bash
git clone https://github.com/ntamraka/wls.git
cd wls/Graph_plot
./setup.sh
python3 remote_agent.py <system1-ip>:8000 system2 ali_benchmark_config.sh
```

### Run Benchmarks
Open browser: `http://<system1-ip>:8000` → Click "▶️ Run All Benchmarks"

---

## 🎉 Expected Results

After benchmark completes, you'll see:
- **Single Chart**: KPI/Requests per VM count
- **2 Lines**: One for system1 (color 1), one for system2 (color 2)
- **18 Data Points**: VM counts 1-18 on X-axis
- **Request Counts**: Y-axis shows KPI values from CSV files

Compare performance between systems visually!

---

## 🔗 Related Documentation

- **README.md** - Full system documentation
- **ali_benchmark_config.sh** - Configuration file for ALI workload
- **example_config.sh** - Template for custom benchmarks

---

## 📞 Quick Reference

| What | Command |
|------|---------|
| Start Dashboard | `./start.sh` |
| Start Agent (System 1) | `python3 remote_agent.py localhost:8000 system1 ali_benchmark_config.sh` |
| Start Agent (System 2) | `python3 remote_agent.py <system1-ip>:8000 system2 ali_benchmark_config.sh` |
| Dashboard URL | `http://<system1-ip>:8000` |
| Stop Dashboard | `pkill -f "uvicorn server:app"` |
| View Logs | `tail -f nohup.out` |
| Check Running | `ps aux \| grep uvicorn` |

---

**That's it! You're ready to benchmark ALI workload across multiple systems! 🚀**
