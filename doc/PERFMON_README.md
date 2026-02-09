# Real-Time Performance Monitor v2.0

A comprehensive, real-time system monitoring tool for Linux with advanced features and beautiful terminal UI.

## Features

### Core Monitoring
- **CPU Statistics**: Real-time CPU usage with user/system/idle/iowait breakdown
- **Memory Usage**: Total, used, free, and available memory tracking
- **Disk I/O**: IOPS and throughput for read/write operations
- **Network I/O**: RX/TX rates with cumulative totals

### Advanced Features
- **Per-Core CPU Usage**: Monitor individual CPU core utilization (requires `mpstat`)
- **Temperature Monitoring**: CPU temperature from thermal sensors with color-coded warnings
- **Top Processes**: Track top CPU and memory consuming processes
- **Historical Graphs**: ASCII-based graphs showing CPU and memory trends over time
- **Detailed Disk Stats**: Per-device disk statistics with utilization percentage
- **Detailed Network Stats**: Per-interface network statistics with packet counts
- **Alert System**: Configurable thresholds for CPU, memory, and temperature
- **CSV Logging**: Log all statistics to file for later analysis

### Visual Features
- Color-coded progress bars (green/yellow/red based on usage)
- Beautiful terminal UI with borders and sections
- Real-time updates with configurable refresh interval
- Iteration counter and uptime display

## Installation

No installation required! Just make the script executable:

```bash
chmod +x perfmon.sh
```

### Dependencies

Required packages:
- `sysstat` (provides vmstat, iostat, mpstat)
- `procps` (provides ps, free)

Install on RHEL/CentOS/Rocky:
```bash
yum install sysstat procps-ng
```

Install on Ubuntu/Debian:
```bash
apt-get install sysstat procps
```

## Usage

### Basic Monitoring
```bash
./perfmon.sh
```

### Full Featured Monitoring
```bash
./perfmon.sh -i 1 -p 10 -c -t -g
```

### With Logging and Custom Thresholds
```bash
./perfmon.sh -l /tmp/perfmon.log --cpu-threshold 90 --mem-threshold 85
```

### Detailed Disk and Network View
```bash
./perfmon.sh -d -n -p 0
```

## Command-Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `-h, --help` | Show help message | - |
| `-i, --interval SECONDS` | Set refresh interval | 2 |
| `-p, --processes N` | Show top N processes (0 to disable) | 5 |
| `-c, --per-core` | Show per-core CPU usage | Off |
| `-t, --temperature` | Show CPU temperature | On |
| `-g, --graphs` | Show historical ASCII graphs | On |
| `-d, --detailed-disk` | Show per-disk statistics | Off |
| `-n, --detailed-net` | Show per-interface network statistics | Off |
| `-l, --log FILE` | Log statistics to CSV file | None |
| `--cpu-threshold N` | CPU alert threshold (%) | 80 |
| `--mem-threshold N` | Memory alert threshold (%) | 80 |
| `--temp-threshold N` | Temperature alert threshold (°C) | 80 |

## Examples

### 1. Quick System Check (1-second refresh)
```bash
./perfmon.sh -i 1
```

### 2. Monitor a Server (with all features)
```bash
./perfmon.sh -i 2 -p 10 -c -t -g -l /var/log/perfmon.log
```

### 3. Detailed Storage and Network Analysis
```bash
./perfmon.sh -d -n -i 5 -p 0
```

### 4. High-Performance System Monitoring (strict thresholds)
```bash
./perfmon.sh --cpu-threshold 70 --mem-threshold 75 --temp-threshold 70 -l alerts.log
```

### 5. Minimalist View (processes only)
```bash
./perfmon.sh -p 20 -t
```

## Output Sections

### CPU Usage
- Overall CPU usage with visual progress bar
- User, system, idle, and I/O wait percentages
- Optional per-core breakdown (with `-c`)
- Optional temperature display (with `-t`)

### Memory Usage
- Visual progress bar showing memory utilization
- Total, used, free, and available memory in MB

### Top Processes (if enabled)
- Top N CPU consumers with PID, %CPU, %MEM, and command
- Top N memory consumers with same details

### Disk I/O
- **Basic mode**: Aggregate IOPS and MB/s for reads and writes
- **Detailed mode** (`-d`): Per-device statistics with utilization

### Network I/O
- **Basic mode**: Total RX/TX rates and cumulative totals
- **Detailed mode** (`-n`): Per-interface statistics with packet counts

### Historical Graphs (if enabled)
- CPU usage trend over last 50 samples
- Memory usage trend over last 50 samples
- Color-coded bars (green < 60%, yellow < 80%, red >= 80%)

### Alerts
- Automatic alerts when thresholds are exceeded
- Color-coded warnings for CPU, memory, and temperature
- Alerts are also logged to file if logging is enabled

## Log File Format

When using `-l`, statistics are logged in CSV format:

```csv
timestamp,cpu,memory,temperature,rx_rate,tx_rate
2026-01-06 02:46:52,CPU:0%,MEM:1%,TEMP:40°C,RX:0B/s,TX:0B/s
2026-01-06 02:46:54,CPU:2%,MEM:1%,TEMP:41°C,RX:1.2MB/s,TX:850KB/s
```

Alerts are appended as:
```
[2026-01-06 02:47:10] ALERT: CPU usage: 85% (threshold: 80%)
```

## Color Coding

### Progress Bars
- 🟢 **Green**: 0-59% (Normal)
- 🟡 **Yellow**: 60-79% (Warning)
- 🔴 **Red**: 80-100% (Critical)

### Temperature
- 🟢 **Green**: < 60°C (Normal)
- 🟡 **Yellow**: 60-80°C (Warm)
- 🔴 **Red**: > 80°C (Hot)

## Tips and Best Practices

1. **Startup monitoring**: Use `-i 1 -g` for rapid assessment
2. **Long-term monitoring**: Use `-l logfile.csv` with cron or systemd
3. **Server health checks**: Enable all features with `-c -t -g -d -n`
4. **Troubleshooting**: Use `-p 20 -c` to identify problematic processes
5. **Minimal overhead**: Disable features you don't need (e.g., `-p 0` disables process tracking)

## Performance Impact

The tool has minimal performance impact:
- CPU usage: < 0.5% on most systems
- Memory: < 10MB
- Network: None
- Disk I/O: Minimal (only when logging with `-l`)

## Keyboard Controls

- **Ctrl+C**: Stop monitoring gracefully and show log file location (if logging)

## Troubleshooting

### "command not found" errors
Install missing dependencies:
```bash
yum install sysstat procps-ng
```

### Temperature shows "N/A"
- Some systems don't expose thermal zones in `/sys/class/thermal`
- Try checking if `sensors` command works
- Virtual machines may not have temperature sensors

### Per-core CPU not showing
- Install `sysstat` package for `mpstat` command
- On some minimal systems, `mpstat` may not be available

### Graphs not displaying correctly
- Ensure terminal supports Unicode characters
- Increase terminal width for better visualization
- Minimum recommended width: 80 columns

## Integration Examples

### Run in background and log to file
```bash
nohup ./perfmon.sh -l /var/log/perfmon.log > /dev/null 2>&1 &
```

### Systemd service
Create `/etc/systemd/system/perfmon.service`:
```ini
[Unit]
Description=Performance Monitor
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/perfmon.sh -l /var/log/perfmon.log
Restart=always

[Install]
WantedBy=multi-user.target
```

### Cron job (every minute)
```bash
* * * * * /usr/local/bin/perfmon.sh -i 1 >> /var/log/perfmon-snapshot.log 2>&1 &
sleep 10 && pkill -f perfmon.sh
```

## Comparison with Other Tools

| Feature | perfmon.sh | htop | top | glances |
|---------|------------|------|-----|---------|
| Real-time updates | ✅ | ✅ | ✅ | ✅ |
| Color-coded UI | ✅ | ✅ | ❌ | ✅ |
| Per-core CPU | ✅ | ✅ | ❌ | ✅ |
| Historical graphs | ✅ | ❌ | ❌ | ✅ |
| Alert thresholds | ✅ | ❌ | ❌ | ✅ |
| CSV logging | ✅ | ❌ | ❌ | ✅ |
| No installation | ✅ | ❌ | ✅ | ❌ |
| Per-device disk stats | ✅ | ❌ | ❌ | ✅ |
| Customizable | ✅ | ⚠️ | ⚠️ | ✅ |

## Version History

### v2.0 (Current)
- Added per-core CPU monitoring
- Added temperature monitoring
- Added top process tracking
- Added historical ASCII graphs
- Added alert system with thresholds
- Added detailed disk and network statistics
- Added CSV logging capability
- Enhanced visual design
- Added comprehensive command-line options

### v1.0
- Initial release
- Basic CPU, memory, disk, and network monitoring
- Simple progress bars
- Real-time updates

## License

This script is provided as-is for monitoring purposes. Feel free to modify and distribute.

## Author

Created for comprehensive Linux system monitoring and performance analysis.

## Contributing

Suggestions and improvements welcome! Areas for future enhancement:
- GPU monitoring support
- Process tree view
- Docker container monitoring
- Custom dashboard layouts
- Web-based interface
- Prometheus/Grafana integration

## See Also

- [system_information.sh](system_information.sh) - Comprehensive system info with MSR monitoring
- `htop` - Interactive process viewer
- `glances` - Cross-platform monitoring tool
- `netdata` - Real-time performance monitoring
