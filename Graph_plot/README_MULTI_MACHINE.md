# Multi-Machine MLC Dashboard

This dashboard supports running MLC benchmarks on multiple machines simultaneously with **centralized control** - trigger benchmarks on all remote machines from the dashboard!

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    Dashboard Server                          │
│  ┌────────────────┐  ┌──────────────┐  ┌─────────────────┐ │
│  │  Web Dashboard │  │  WebSocket   │  │  Control API    │ │
│  │   (Browser)    │  │   Broker     │  │  /ws/control    │ │
│  └────────┬───────┘  └──────┬───────┘  └────────┬────────┘ │
└───────────┼──────────────────┼──────────────────┼──────────┘
            │                  │                  │
            │ View Results     │ Stream Data      │ Send Commands
            │                  │                  │
     ┌──────▼──────────────────▼──────────────────▼──────┐
     │                                                     │
┌────▼─────┐         ┌────────────┐         ┌───────────▼┐
│ Machine 1│         │ Machine 2  │         │ Machine 3  │
│  Agent   │         │   Agent    │         │   Agent    │
│ (Waits)  │         │  (Waits)   │         │  (Waits)   │
└──────────┘         └────────────┘         └────────────┘
     │                     │                       │
     └─────────────────────┴───────────────────────┘
              Run Benchmarks When Triggered
```

## Setup

### 1. Dashboard Server (Central Machine)

Run the dashboard server that will collect and display all results:

```bash
cd /root/wls/Graph_plot
./setup.sh          # One-time setup
./start.sh          # Start the dashboard server
```

The dashboard will be available at: `http://<server-ip>:8000`

### 2. Remote Machines (Agent Mode - Recommended)

On each machine you want to run benchmarks, start the agent that waits for commands:

```bash
# Copy the Graph_plot directory to the remote machine
scp -r /root/wls/Graph_plot user@remote-machine:/path/to/

# On the remote machine
cd /path/to/Graph_plot
./setup.sh  # One-time setup

# Start the agent (it will wait for commands from dashboard)
python3 remote_agent.py <dashboard-ip>:8000 <machine-name>

# Example:
python3 remote_agent.py 10.140.157.132:8000 server-02
```

The agent will:
- ✅ Connect to dashboard server
- ✅ Wait for benchmark execution commands
- ✅ Run benchmarks when triggered
- ✅ Stream results back to dashboard in real-time
- ✅ Automatically reconnect if connection drops

### 3. Trigger Benchmarks

#### Option A: From Dashboard Web UI (Easiest)

1. Open the dashboard in your browser: `http://<server-ip>:8000`
2. See the "Remote Control Panel" showing all connected agents
3. Click **"▶️ Run All Benchmarks"** button
4. Watch as all machines execute benchmarks simultaneously!

#### Option B: From Command Line

```bash
# Trigger all connected agents
./trigger_all.sh <dashboard-ip>:8000

# Example:
./trigger_all.sh 10.140.157.132:8000
```

#### Option C: Manual Push (Old Method)

Run the benchmark and stream to dashboard:
```bash
python3 remote_client.py <dashboard-ip>:8000 <machine-name>
```

## Features

### Centralized Control 🎮

- **One-Click Execution**: Trigger benchmarks on all machines from the dashboard
- **Agent Management**: See all connected remote machines in real-time
- **Persistent Connections**: Agents maintain connection and wait for commands
- **Auto-Reconnect**: Agents automatically reconnect if connection is lost

### Multi-Machine Visualization

- **Color-coded Lines**: Each machine gets a unique color
- **Machine Tracking**: Stats show number of active machines
- **Separate Datasets**: Each machine's data is plotted as a separate line
- **Real-time Updates**: All machines update the dashboard live

### Dashboard Features

- **Active Machines Counter**: Shows how many machines are reporting
- **Agent Status Panel**: See all connected agents with live status
- **Run All Button**: Execute benchmarks on all agents simultaneously
- **Combined Charts**: All machines' data on the same graph for comparison
- **Individual Metrics**: Bandwidth, Latency, and CPU utilization per machine
- **Test Progress**: Total number of tests completed across all machines

## Example Usage

### Scenario: Compare 3 Different Servers with Centralized Control

**Step 1: Dashboard Server (10.140.157.132):**
```bash
cd /root/wls/Graph_plot
./start.sh
```

**Step 2: Start Agents on Remote Machines**

**Server 1 (10.140.157.140):**
```bash
python3 remote_agent.py 10.140.157.132:8000 server-01
```

**Server 2 (10.140.157.150):**
```bash
python3 remote_agent.py 10.140.157.132:8000 server-02
```

**Server 3 (10.140.157.160):**
```bash
python3 remote_agent.py 10.140.157.132:8000 server-03
```

**Step 3: Open Dashboard & Trigger**
1. Open browser to `http://10.140.157.132:8000`
2. You'll see 3 agents connected in the control panel
3. Click "▶️ Run All Benchmarks"
4. Watch all three servers run benchmarks simultaneously!
5. Results appear in real-time on the same dashboard

**Alternative:** Use CLI to trigger:
```bash
./trigger_all.sh 10.140.157.132:8000
```

## WebSocket Endpoints

- `/ws` - Dashboard viewer connection (browser)
- `/ws/agent` - Remote agent persistent connection
- `/ws/control` - Control commands to trigger benchmarks
- `/ws/push` - Legacy: Direct data push endpoint (for remote_client.py)

## Troubleshooting

### Agents Not Showing Up

- Check agent is running: Should show "Agent is running and waiting for commands..."
- Verify connectivity: `ping <dashboard-ip>`
- Check dashboard logs for agent registration
- Click "🔄 Refresh Agents" button in dashboard

### Can't Trigger Benchmarks

- Ensure agents are connected (visible in control panel)
- Check browser console for errors (F12)
- Verify dashboard server is running
- Try refreshing the page

### Remote Client/Agent Can't Connect

- Verify dashboard server is running: `curl http://<server-ip>:8000`
- Check firewall: `sudo ufw allow 8000` (if using ufw)
- Ensure network connectivity: `ping <server-ip>`
- Check for typos in IP:port

### No Data Appearing

- Check MLC binary exists: `ls -l mlc_internal`
- Verify numactl installed: `which numactl`
- Check server logs for errors
- Verify JSON output: `./mlc.sh test | grep '{'`

### Machine Names Colliding

Pass unique names when starting agents:
```bash
python3 remote_agent.py <server>:8000 unique-name-$(hostname)
```

## Performance Tips

- Run one benchmark per machine at a time
- Ensure stable network connection for smooth streaming
- Monitor dashboard server resources if running many machines
- Use descriptive machine names for easy identification

## Dependencies

- Python 3.7+
- websockets (`pip3 install websockets`)
- FastAPI, Uvicorn (on dashboard server)
- numactl
- Intel MLC binary

## Security Note

This setup is designed for trusted networks. For production use:
- Enable authentication on WebSocket endpoints
- Use WSS (secure WebSocket) instead of WS
- Implement rate limiting
- Validate all incoming data
