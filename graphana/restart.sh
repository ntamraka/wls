#!/bin/bash

# Restart Grafana and Prometheus services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}[INFO]${NC} Restarting Grafana and Prometheus services..."

if docker compose version &> /dev/null; then
    docker compose restart
else
    docker-compose restart
fi

echo -e "${GREEN}[INFO]${NC} Services restarted successfully"
