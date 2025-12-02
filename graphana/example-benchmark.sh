#!/bin/bash

# Quick Example: Run CPU Benchmark with multiple core counts

cd "$(dirname "$0")"

echo "========================================"
echo "CPU Core Scaling Example"
echo "Testing with 1, 2, 4, and 8 cores"
echo "Duration: 20 seconds each"
echo "========================================"
echo ""

# Run tests with different core counts
for cores in 1 2 4 8; do
    echo "Testing with $cores cores..."
    ./cpu-benchmark.sh --cores $cores --duration 20 --test-name scaling_example
    sleep 5
    echo ""
done

echo "========================================"
echo "Tests complete!"
echo ""
echo "View results:"
echo "  Grafana: http://localhost:3000"
echo "  Dashboard: CPU Core Scaling Benchmark"
echo "  CSV: $(pwd)/benchmark_results.csv"
echo "========================================"
