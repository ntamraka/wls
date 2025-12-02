#!/bin/bash

# Complete Data Flow Verification for CPU Benchmark → Grafana

echo "=========================================="
echo "DATA FLOW VERIFICATION"
echo "=========================================="
echo ""

echo "STEP 1: Run Benchmark → Push to Pushgateway"
echo "--------------------------------------------"
echo "Command: ./cpu-benchmark.sh --cores 2 --duration 10 --test-name flow_test"
echo ""

# Run a quick test
cd /root/wls/graphana
./cpu-benchmark.sh --cores 2 --duration 10 --test-name flow_test 2>&1 | tail -5

echo ""
echo "STEP 2: Check Pushgateway (Port 9091)"
echo "--------------------------------------------"
echo "Pushgateway stores metrics from benchmark script"
echo ""
PUSH_METRICS=$(curl -s http://localhost:9091/metrics | grep "cpu_benchmark_ops_per_second{" | wc -l)
echo "✓ Pushgateway has $PUSH_METRICS metric entries"
echo ""
echo "Sample metrics in Pushgateway:"
curl -s http://localhost:9091/metrics | grep "cpu_benchmark_ops_per_second{" | head -3
echo ""

echo "STEP 3: Prometheus Scrapes Pushgateway (Port 9090)"
echo "--------------------------------------------"
echo "Prometheus scrapes Pushgateway every 15 seconds"
echo ""

# Check if Prometheus target is up
PROM_TARGET=$(curl -s http://localhost:9090/api/v1/targets | python3 -c "
import sys, json
data = json.load(sys.stdin)
for target in data['data']['activeTargets']:
    if 'pushgateway' in target['labels'].get('job', ''):
        print(f\"Target: {target['labels']['job']}  Health: {target['health']}  Last Scrape: {target.get('lastScrape', 'N/A')}\")
" 2>/dev/null)
echo "$PROM_TARGET"
echo ""

# Check Prometheus has the data
PROM_METRICS=$(curl -s 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second' | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f\"✓ Prometheus has {len(data['data']['result'])} data points\")
" 2>/dev/null)
echo "$PROM_METRICS"
echo ""

echo "Sample data in Prometheus:"
curl -s 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second' | python3 -c "
import sys, json
data = json.load(sys.stdin)
for i, m in enumerate(data['data']['result'][:3]):
    cores = m['metric']['cores']
    ops = m['value'][1]
    test = m['metric']['test']
    print(f\"  - {cores} cores: {ops} ops/sec (test: {test})\")
" 2>/dev/null
echo ""

echo "STEP 4: Grafana Datasource (Port 3000)"
echo "--------------------------------------------"
echo "Grafana queries Prometheus via datasource"
echo ""

# Check Grafana datasource
GRAFANA_DS=$(curl -s -u admin:admin http://localhost:3000/api/datasources 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data:
        for ds in data:
            print(f\"✓ Datasource: {ds['name']}  Type: {ds['type']}  URL: {ds['url']}\")
    else:
        print('✗ No datasources configured')
except:
    print('✗ Cannot connect to Grafana API')
" 2>/dev/null)

if [ -z "$GRAFANA_DS" ]; then
    echo "⚠ Grafana requires authentication"
    echo "  You need to log in via web browser first"
else
    echo "$GRAFANA_DS"
fi
echo ""

echo "STEP 5: Test Grafana Query"
echo "--------------------------------------------"
echo "Testing if Grafana can query Prometheus..."
echo ""

# Try to query through Grafana (this requires auth)
GRAFANA_QUERY=$(curl -s -u admin:admin \
  -H "Content-Type: application/json" \
  -d '{"queries":[{"refId":"A","datasource":{"type":"prometheus","uid":"prometheus"},"expr":"cpu_benchmark_ops_per_second","instant":true}]}' \
  http://localhost:3000/api/ds/query 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'results' in data:
        print('✓ Grafana can query Prometheus successfully')
        if 'A' in data['results'] and 'frames' in data['results']['A']:
            frame_count = len(data['results']['A']['frames'])
            print(f'  Found {frame_count} data frames')
    else:
        print('✗ Query failed')
        print(json.dumps(data, indent=2))
except Exception as e:
    print(f'✗ Error: {e}')
" 2>/dev/null)

if [ -z "$GRAFANA_QUERY" ]; then
    echo "⚠ Cannot test query (authentication required)"
else
    echo "$GRAFANA_QUERY"
fi
echo ""

echo "=========================================="
echo "DASHBOARD ACCESS"
echo "=========================================="
echo ""
echo "URL: http://10.140.157.132:3000"
echo "Login: admin / admin"
echo ""
echo "Navigation:"
echo "  1. Click ☰ menu (top left)"
echo "  2. Click 'Dashboards'"
echo "  3. Click 'CPU Core Scaling Benchmark'"
echo ""
echo "Dashboard location:"
ls -lh /root/wls/graphana/grafana/dashboards/cpu-benchmark.json
echo ""

echo "=========================================="
echo "TROUBLESHOOTING"
echo "=========================================="
echo ""
echo "If you still don't see data in Grafana:"
echo ""
echo "1. TIME RANGE: Set to 'Last 1 hour' in top-right"
echo "2. REFRESH: Click the refresh icon or press F5"
echo "3. QUERY: Open panel, click 'Edit' and check query"
echo "4. DATASOURCE: Verify Prometheus datasource is selected"
echo ""
echo "Manual test in Grafana:"
echo "  - Go to Explore (compass icon in left menu)"
echo "  - Select 'Prometheus' datasource"
echo "  - Enter query: cpu_benchmark_ops_per_second"
echo "  - Click 'Run query'"
echo "  - You should see data!"
echo ""
echo "=========================================="
echo ""

