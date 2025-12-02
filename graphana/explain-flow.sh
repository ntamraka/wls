#!/bin/bash

# Complete Data Flow Explanation and Verification

cat <<'EOF'

╔══════════════════════════════════════════════════════════════════════╗
║                      DATA FLOW ARCHITECTURE                          ║
╚══════════════════════════════════════════════════════════════════════╝

┌─────────────────┐
│  1. BENCHMARK   │  ./cpu-benchmark.sh --cores 4 --duration 20
│     SCRIPT      │  Runs stress-ng to generate CPU load
└────────┬────────┘
         │
         │ Pushes metrics via HTTP POST
         ▼
┌─────────────────┐
│  2. PUSHGATEWAY │  http://localhost:9091
│   (Port 9091)   │  Temporarily stores custom metrics
└────────┬────────┘  Acts as intermediary for batch jobs
         │
         │ Scraped every 15 seconds
         ▼
┌─────────────────┐
│  3. PROMETHEUS  │  http://localhost:9090
│   (Port 9090)   │  Time-series database
└────────┬────────┘  Stores metrics with timestamps
         │           Retention: 30 days
         │
         │ Queried via PromQL
         ▼
┌─────────────────┐
│  4. GRAFANA     │  http://localhost:3000
│   (Port 3000)   │  Visualization & Dashboards
└─────────────────┘  Login: admin / dcso@123


╔══════════════════════════════════════════════════════════════════════╗
║                         METRICS FLOW                                 ║
╚══════════════════════════════════════════════════════════════════════╝

Benchmark Run → Metrics Created:
  • cpu_benchmark_ops_per_second{cores="4", test="example_test_4core"}
  • cpu_benchmark_operations_total{cores="4", test="example_test_4core"}
  • cpu_benchmark_cpu_usage_percent{cores="4", test="example_test_4core"}
  • cpu_benchmark_duration_seconds{cores="4", test="example_test_4core"}

These metrics flow through:
  Benchmark → Pushgateway → Prometheus → Grafana Dashboard


╔══════════════════════════════════════════════════════════════════════╗
║                      CURRENT STATUS CHECK                            ║
╚══════════════════════════════════════════════════════════════════════╝

EOF

echo "Checking each component..."
echo ""

# 1. Check Pushgateway
echo "1️⃣  PUSHGATEWAY (localhost:9091)"
if curl -s http://localhost:9091/metrics | grep -q "cpu_benchmark"; then
    METRIC_COUNT=$(curl -s http://localhost:9091/metrics | grep "cpu_benchmark_ops_per_second{" | wc -l)
    echo "   ✅ Running - Has $METRIC_COUNT benchmark metrics"
else
    echo "   ❌ No metrics found"
fi
echo ""

# 2. Check Prometheus
echo "2️⃣  PROMETHEUS (localhost:9090)"
PROM_METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second' | \
    python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data['data']['result']))" 2>/dev/null)
if [ "$PROM_METRICS" -gt 0 ]; then
    echo "   ✅ Running - Has $PROM_METRICS metric series"
else
    echo "   ❌ No metrics scraped"
fi
echo ""

# 3. Check Grafana
echo "3️⃣  GRAFANA (localhost:3000)"
GRAFANA_STATUS=$(curl -s http://localhost:3000/api/health | python3 -c "import sys, json; print(json.load(sys.stdin)['database'])" 2>/dev/null)
if [ "$GRAFANA_STATUS" = "ok" ]; then
    echo "   ✅ Running - Database: $GRAFANA_STATUS"
    
    # Check datasource
    DS_NAME=$(curl -s -u admin:dcso@123 http://localhost:3000/api/datasources 2>/dev/null | \
        python3 -c "import sys, json; print(json.load(sys.stdin)[0]['name'])" 2>/dev/null)
    echo "   ✅ Datasource: $DS_NAME"
    
    # Check dashboards
    DASH_COUNT=$(curl -s -u admin:dcso@123 http://localhost:3000/api/search?type=dash-db 2>/dev/null | \
        python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null)
    echo "   ✅ Dashboards: $DASH_COUNT available"
else
    echo "   ❌ Not responding properly"
fi
echo ""

# 4. Test Grafana can query Prometheus
echo "4️⃣  GRAFANA → PROMETHEUS CONNECTION"
QUERY_TEST=$(curl -s -u admin:dcso@123 'http://localhost:3000/api/datasources/proxy/1/api/v1/query?query=up' 2>&1 | \
    python3 -c "import sys, json; print(json.load(sys.stdin)['status'])" 2>/dev/null)
if [ "$QUERY_TEST" = "success" ]; then
    echo "   ✅ Grafana can query Prometheus successfully"
else
    echo "   ❌ Query failed"
fi
echo ""

cat <<'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║                      YOUR BENCHMARK DATA                             ║
╚══════════════════════════════════════════════════════════════════════╝

EOF

curl -s 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second' | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
if data['data']['result']:
    results = sorted(data['data']['result'], key=lambda x: int(x['metric']['cores']))
    for m in results:
        cores = m['metric']['cores']
        ops = float(m['value'][1])
        test = m['metric']['test']
        print(f'  {cores:>3} cores: {ops:>10.2f} ops/sec  ({test})')
else:
    print('  No data found - run a benchmark first!')
" 2>/dev/null

cat <<'EOF'


╔══════════════════════════════════════════════════════════════════════╗
║                   HOW TO VIEW IN GRAFANA                             ║
╚══════════════════════════════════════════════════════════════════════╝

Step 1: Open Browser
   URL: http://10.140.157.132:3000
   
Step 2: Login
   Username: admin
   Password: dcso@123

Step 3: Navigate to Dashboard
   • Click ☰ (hamburger menu, top-left)
   • Click "Dashboards"
   • Click "CPU Core Scaling Benchmark"
   
   OR use direct link:
   http://10.140.157.132:3000/d/cpu-benchmark

Step 4: Verify Data is Showing
   • Check time range (top-right) - set to "Last 1 hour"
   • Main graph should show line with points
   • Hover over points to see values

Step 5: If "No Data" appears:
   a) Check time range includes your benchmark run time
   b) Click the refresh icon (circular arrow)
   c) Check panel edit → Query to see if it returns data


╔══════════════════════════════════════════════════════════════════════╗
║                     TROUBLESHOOTING                                  ║
╚══════════════════════════════════════════════════════════════════════╝

If you see "No Data" in Grafana panels:

1. Verify Prometheus has data:
   curl 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second'

2. Test datasource in Grafana:
   • Go to Connections → Data sources → Prometheus
   • Click "Test" button
   • Should show green "Data source is working"

3. Check panel query:
   • Open dashboard
   • Click panel title → Edit
   • Look at query: cpu_benchmark_ops_per_second
   • Click "Run queries" button
   • Should see data in table below

4. Check time range:
   • Your metrics have timestamps
   • Grafana time range must include those times
   • Try "Last 6 hours" or "Last 24 hours"

5. Refresh metrics:
   • Run a new benchmark: ./example-benchmark.sh
   • Wait 30 seconds for Prometheus to scrape
   • Refresh Grafana dashboard


╔══════════════════════════════════════════════════════════════════════╗
║                      RUN NEW BENCHMARK                               ║
╚══════════════════════════════════════════════════════════════════════╝

To generate fresh data right now:

   cd /root/wls/graphana
   ./cpu-benchmark.sh --cores 8 --duration 15 --test-name live_test

Then immediately refresh your Grafana dashboard!


EOF

echo "=============================================="
echo "Data flow verification complete!"
echo "=============================================="
echo ""

