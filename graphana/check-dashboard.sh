#!/bin/bash

# Grafana Dashboard Access Test

echo "=========================================="
echo "Grafana Dashboard Verification"
echo "=========================================="
echo ""

# Check if Grafana is running
if ! curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo "❌ Grafana is not responding"
    exit 1
fi
echo "✓ Grafana is running"

# Check dashboards
echo ""
echo "Checking dashboard files..."
docker exec grafana ls -la /var/lib/grafana/dashboards/ 2>&1 | grep ".json"

echo ""
echo "=========================================="
echo "Access Instructions:"
echo "=========================================="
echo ""
echo "1. Open your browser to: http://localhost:3000"
echo "   (Or external IP: http://10.140.157.132:3000)"
echo ""
echo "2. Login with:"
echo "   Username: admin"
echo "   Password: admin"
echo ""
echo "3. Navigate to dashboards:"
echo "   Click the ☰ menu (top left)"
echo "   → Click 'Dashboards'"
echo "   → You should see:"
echo "      • CPU Core Scaling Benchmark"
echo "      • MongoDB Performance Dashboard"
echo "      • Redis Performance Dashboard"
echo "      • System Metrics Dashboard"
echo ""
echo "4. Click 'CPU Core Scaling Benchmark' to view"
echo ""
echo "If you don't see the dashboards:"
echo "   a) Wait 10 seconds for provisioning"
echo "   b) Refresh the page (F5)"
echo "   c) Check the 'General' folder"
echo "   d) Click 'Dashboards' → 'Browse'"
echo ""
echo "=========================================="
echo "Available Metrics in Prometheus:"
echo "=========================================="
curl -s 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second' | \
    python3 -c "import sys, json; data=json.load(sys.stdin); print('\n'.join([f\"  {m['metric']['cores']} cores: {float(m['value'][1]):.2f} ops/sec\" for m in data['data']['result']]))" 2>/dev/null || echo "No data yet - run a benchmark first"

echo ""
