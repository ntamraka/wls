# Grafana and Prometheus Setup for Workload Benchmark Suite

Real-time monitoring and visualization for MongoDB, Redis, Cassandra, and system metrics.

## 🚀 Quick Start

```bash
cd graphana
chmod +x setup.sh
./setup.sh
```

## 📊 What's Included

### Services
- **Grafana** (Port 3000) - Visualization and dashboarding
- **Prometheus** (Port 9090) - Metrics collection and storage
- **Node Exporter** (Port 9100) - System metrics (CPU, memory, disk, network)
- **Redis Exporter** (Port 9121) - Redis metrics
- **MongoDB Exporter** (Port 9216) - MongoDB metrics

## 🔧 Prerequisites

- Docker and Docker Compose will be installed automatically by the setup script
- Supported OS: CentOS 9, RHEL 9, Rocky, AlmaLinux, Ubuntu 24.04

## 📖 Usage

### Initial Setup
```bash
./setup.sh
```

### Access Dashboards
- **Grafana**: http://localhost:3000
  - Username: `admin`
  - Password: `admin` (you'll be prompted to change this on first login)

- **Prometheus**: http://localhost:9090

### Manage Services
```bash
# Stop services
./stop.sh

# Restart services
./restart.sh

# View logs
./logs.sh [service-name]
# Examples:
./logs.sh grafana
./logs.sh prometheus
./logs.sh all
```

## 📈 Creating Dashboards

### 1. Access Grafana
Navigate to http://localhost:3000 and log in.

### 2. Create a New Dashboard
- Click the "+" icon → "Dashboard"
- Add a new panel
- Select "Prometheus" as the data source

### 3. Sample Queries

#### System Metrics (Node Exporter)
```promql
# CPU Usage
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory Usage (%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk I/O Read
rate(node_disk_read_bytes_total[5m])

# Disk I/O Write
rate(node_disk_written_bytes_total[5m])

# Network Receive
rate(node_network_receive_bytes_total[5m])

# Network Transmit
rate(node_network_transmit_bytes_total[5m])
```

#### Redis Metrics
```promql
# Operations per second
rate(redis_commands_processed_total[1m])

# Connected clients
redis_connected_clients

# Memory usage
redis_memory_used_bytes

# Hit rate
rate(redis_keyspace_hits_total[1m]) / (rate(redis_keyspace_hits_total[1m]) + rate(redis_keyspace_misses_total[1m]))

# Keys in database
redis_db_keys
```

#### MongoDB Metrics
```promql
# Operations per second
rate(mongodb_opcounters_total[1m])

# Connections
mongodb_connections{state="current"}

# Memory usage
mongodb_memory{type="resident"}

# Query execution time
mongodb_mongod_metrics_query_executor_total

# Active operations
mongodb_mongod_global_lock_current_queue
```

## 🎨 Pre-built Dashboard Templates

You can import community dashboards:

1. Go to Grafana → Dashboards → Import
2. Enter dashboard ID:
   - **Node Exporter Full**: 1860
   - **Redis Dashboard**: 763
   - **MongoDB Dashboard**: 2583

## 🔌 Connecting to Your Services

The exporters are configured to connect to services on the host machine:
- Redis: `localhost:6379`
- MongoDB: `localhost:27017`
- Cassandra: `localhost:7070` (requires JMX exporter)

### Setting up Cassandra JMX Exporter

1. Download JMX Exporter:
```bash
cd /opt/cassandra
wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.19.0/jmx_prometheus_javaagent-0.19.0.jar
```

2. Create config file `cassandra-jmx.yml`:
```yaml
lowercaseOutputName: true
lowercaseOutputLabelNames: true
whitelistObjectNames: ["org.apache.cassandra.metrics:*"]
```

3. Add to Cassandra startup (in `cassandra-env.sh`):
```bash
JVM_OPTS="$JVM_OPTS -javaagent:/opt/cassandra/jmx_prometheus_javaagent-0.19.0.jar=7070:/opt/cassandra/cassandra-jmx.yml"
```

## 📁 Directory Structure

```
graphana/
├── docker-compose.yml          # Docker services configuration
├── prometheus.yml              # Prometheus scrape configuration
├── setup.sh                    # Automated setup script
├── stop.sh                     # Stop all services
├── restart.sh                  # Restart all services
├── logs.sh                     # View service logs
├── prometheus_data/            # Prometheus time-series data
├── grafana_data/               # Grafana database and settings
└── grafana/
    ├── provisioning/
    │   ├── datasources/        # Auto-configured data sources
    │   └── dashboards/         # Dashboard provisioning
    └── dashboards/             # Custom dashboard JSON files
```

## 🛠️ Customization

### Change Prometheus Retention Period
Edit `docker-compose.yml` and modify:
```yaml
--storage.tsdb.retention.time=30d  # Change to desired retention
```

### Add Custom Metrics Endpoints
Edit `prometheus.yml` and add your endpoints:
```yaml
scrape_configs:
  - job_name: 'my-custom-app'
    static_configs:
      - targets: ['host.docker.internal:8080']
```

### Change Grafana Admin Password
Set environment variables in `docker-compose.yml`:
```yaml
environment:
  - GF_SECURITY_ADMIN_PASSWORD=your-secure-password
```

## 🐛 Troubleshooting

### Services won't start
```bash
# Check logs
./logs.sh

# Check Docker is running
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker
```

### Can't connect to databases
- Ensure Redis/MongoDB/Cassandra are running on the host
- Check firewall rules
- Verify connection strings in `docker-compose.yml`

### Permission issues
```bash
# Fix Grafana data directory permissions
sudo chown -R 472:472 grafana_data/

# Or use your user
sudo chown -R $USER:$USER grafana_data/
```

### Exporters showing "DOWN" in Prometheus
- Check if the databases are accessible from within containers
- Test connectivity: `docker exec -it redis-exporter ping host.docker.internal`

## 📚 Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Node Exporter](https://github.com/prometheus/node_exporter)
- [Redis Exporter](https://github.com/oliver006/redis_exporter)
- [MongoDB Exporter](https://github.com/percona/mongodb_exporter)

## 🔄 Data Retention

- Prometheus: 30 days (configurable)
- Grafana: Persistent storage in `grafana_data/`

## 🗑️ Cleanup

To remove all data and services:
```bash
./stop.sh
sudo rm -rf prometheus_data/ grafana_data/
```

## 📝 Notes

- First login to Grafana will prompt you to change the default password
- All data is persisted in local volumes
- Exporters automatically discover and monitor running services
- Prometheus scrapes metrics every 15 seconds by default
