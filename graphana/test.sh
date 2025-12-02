#!/bin/bash

# Test script to verify Grafana and Prometheus setup

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "Grafana & Prometheus Health Check"
echo "=========================================="
echo ""

# Check Prometheus
echo -n "Prometheus (http://localhost:9090): "
if curl -s http://localhost:9090/-/healthy > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
fi

# Check Grafana
echo -n "Grafana (http://localhost:3000): "
if curl -s http://localhost:3000/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
fi

# Check Node Exporter
echo -n "Node Exporter (http://localhost:9100): "
if curl -s http://localhost:9100/metrics | grep -q "node_cpu"; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
fi

# Check Redis Exporter
echo -n "Redis Exporter (http://localhost:9121): "
if curl -s http://localhost:9121/metrics | grep -q "redis"; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${YELLOW}⚠ Running but Redis may not be connected${NC}"
fi

# Check MongoDB Exporter
echo -n "MongoDB Exporter (http://localhost:9216): "
if curl -s http://localhost:9216/metrics | grep -q "mongodb"; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${YELLOW}⚠ Running but MongoDB may not be connected${NC}"
fi

echo ""
echo "=========================================="
echo "Sample Prometheus Queries"
echo "=========================================="
echo ""

# CPU Usage
echo "CPU Usage:"
CPU=$(curl -s 'http://localhost:9090/api/v1/query?query=100-(avg(irate(node_cpu_seconds_total{mode="idle"}[5m]))*100)' | \
    python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"{float(data['data']['result'][0]['value'][1]):.2f}%\" if data['data']['result'] else 'N/A')" 2>/dev/null)
echo "  $CPU"

# Memory Usage
echo ""
echo "Memory Usage:"
MEM=$(curl -s 'http://localhost:9090/api/v1/query?query=(1-(node_memory_MemAvailable_bytes/node_memory_MemTotal_bytes))*100' | \
    python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"{float(data['data']['result'][0]['value'][1]):.2f}%\" if data['data']['result'] else 'N/A')" 2>/dev/null)
echo "  $MEM"

# Total Memory
TOTAL_MEM=$(curl -s 'http://localhost:9090/api/v1/query?query=node_memory_MemTotal_bytes' | \
    python3 -c "import sys, json; data=json.load(sys.stdin); print(f\"{float(data['data']['result'][0]['value'][1])/1024/1024/1024:.1f} GB\" if data['data']['result'] else 'N/A')" 2>/dev/null)
echo "  Total: $TOTAL_MEM"

echo ""
echo "=========================================="
echo "Access Information"
echo "=========================================="
echo ""
echo "Grafana Web UI: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin"
echo ""
echo "Prometheus Web UI: http://localhost:9090"
echo ""
echo "Available Dashboards in Grafana:"
echo "  1. System Metrics Dashboard"
echo "  2. Redis Performance Dashboard"
echo "  3. MongoDB Performance Dashboard"
echo ""
echo "Or import community dashboards:"
echo "  - Node Exporter Full: Dashboard ID 1860"
echo "  - Redis Dashboard: Dashboard ID 763"
echo "  - MongoDB Dashboard: Dashboard ID 2583"
echo ""
