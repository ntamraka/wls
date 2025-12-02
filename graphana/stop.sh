#!/bin/bash

# Stop Grafana and Prometheus services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN}[INFO]${NC} Stopping Grafana and Prometheus services..."

if docker compose version &> /dev/null; then
    docker compose down
else
    docker-compose down
fi

echo -e "${GREEN}[INFO]${NC} Services stopped successfully"
