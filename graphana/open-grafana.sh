#!/bin/bash

# Open Grafana in browser helper

HOST_IP=$(hostname -I | awk '{print $1}')

cat <<EOF

========================================
🚀 Open Grafana Dashboard
========================================

Access Grafana in your browser:

Option 1 (Local):
  http://localhost:3000

Option 2 (Remote):
  http://${HOST_IP}:3000
  http://10.140.157.132:3000

Login:
  Username: admin
  Password: admin

========================================
📊 View CPU Benchmark Dashboard
========================================

1. After login, click the menu icon (☰) in top left
2. Click "Dashboards"
3. Look for "CPU Core Scaling Benchmark"
4. Click it to open

Or use direct link:
  http://localhost:3000/d/cpu-benchmark

If no dashboards appear:
- Wait 10-15 seconds for provisioning
- Press F5 to refresh
- Click "Dashboards" → "Browse" → "General" folder

========================================
📈 Current Benchmark Data
========================================

EOF

# Show current metrics
curl -s 'http://localhost:9090/api/v1/query?query=cpu_benchmark_ops_per_second' | \
    python3 -c "
import sys, json
data = json.load(sys.stdin)
if data['data']['result']:
    print('Available test results:')
    for m in sorted(data['data']['result'], key=lambda x: int(x['metric']['cores'])):
        cores = m['metric']['cores']
        ops = float(m['value'][1])
        test = m['metric']['test']
        print(f'  {cores:>3} cores: {ops:>8.2f} ops/sec ({test})')
else:
    print('No benchmark data yet. Run: ./example-benchmark.sh')
" 2>/dev/null

echo ""
echo "========================================"
echo ""

EOF
