#!/bin/bash

# Complete check and fix for Grafana dashboard

echo "======================================"
echo "Grafana Dashboard Final Check"
echo "======================================"
echo ""

# 1. Check services
echo "1. Checking services..."
docker compose ps | grep -E "grafana|prometheus|pushgateway"
echo ""

# 2. Check Prometheus has data
echo "2. Checking Prometheus metrics..."
METRIC_COUNT=$(curl -s 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second' | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data['data']['result']))" 2>/dev/null)
echo "   Found $METRIC_COUNT benchmark results"
echo ""

# 3. Check Grafana datasource
echo "3. Checking Grafana datasource..."
DS_COUNT=$(curl -s -u admin:admin http://localhost:3000/api/datasources 2>/dev/null | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null)
if [ "$DS_COUNT" -gt 0 ]; then
    echo "   ✓ Datasource configured"
else
    echo "   ✗ No datasource found"
fi
echo ""

# 4. Instructions
echo "======================================"
echo "TO VIEW YOUR DASHBOARD:"
echo "======================================"
echo ""
echo "1. Open: http://10.140.157.132:3000"
echo "   Login: admin / admin"
echo ""
echo "2. Click ☰ menu → Dashboards"
echo "3. Click 'CPU Core Scaling Benchmark'"
echo ""
echo "4. Set time range to 'Last 1 hour'"
echo "5. You should see graphs with your benchmark data!"
echo ""
echo "Your current metrics:"
curl -s 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second' | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
for m in sorted(data['data']['result'], key=lambda x: int(x['metric']['cores']))[:10]:
    print(f\"   {m['metric']['cores']:>3} cores: {float(m['value'][1]):>8.2f} ops/sec\")
" 2>/dev/null
echo ""
echo "======================================"
echo ""

