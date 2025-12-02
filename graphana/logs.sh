#!/bin/bash

# View logs for Grafana and Prometheus services

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

SERVICE=${1:-}

if [ -z "$SERVICE" ]; then
    echo "Usage: $0 [grafana|prometheus|node-exporter|redis-exporter|mongodb-exporter|all]"
    echo "Showing all logs by default..."
    SERVICE="all"
fi

if [ "$SERVICE" = "all" ]; then
    if docker compose version &> /dev/null; then
        docker compose logs -f
    else
        docker-compose logs -f
    fi
else
    if docker compose version &> /dev/null; then
        docker compose logs -f "$SERVICE"
    else
        docker-compose logs -f "$SERVICE"
    fi
fi
