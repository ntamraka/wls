#!/usr/bin/env bash
#
# MongoDB Benchmark Client Runner
# Usage:
#   ./mongo-bench-runner.sh start <num_clients> [threads] [docs]
#   ./mongo-bench-runner.sh stop
#   ./mongo-bench-runner.sh summary
#


# ===== CONFIG =====
MONGO_BENCH_BIN="./mongo-bench"   # Path to your mongo-bench binary
URI_BASE="mongodb://localhost"
BASE_PORT=27017
rm -rf "./mongo-bench-*-logs/"
PID_FILE="/tmp/mongo_bench_client_pids.txt"

# ===== FUNCTIONS =====

start_clients() {
    local num_clients=${1:-288}
    local threads=${2:-1}
    local docs=${3:-1000000}

    if [[ -z "$num_clients" || "$num_clients" -lt 1 ]]; then
        echo "❌ Please specify a valid number of clients to start."
        exit 1
    fi
    for ops in insert delete update; do
    LOG_DIR="./mongo-bench-${ops}-logs/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$LOG_DIR"
    echo "" > "$PID_FILE"

    echo "🚀 Starting $num_clients mongo-bench clients..."
    for ((i=0; i<num_clients; i++)); do
    
        port=$((BASE_PORT + i))
        logfile="$LOG_DIR/client_${i}_$(date +%Y%m%d_%H%M%S).log"

        echo "➡️  Launching client $i targeting $URI_BASE:$port"
        nohup numactl --physcpubind=$i -m 0 "$MONGO_BENCH_BIN" \
            -threads "$threads" \
            -docs "$docs" \
            -duration 60 \
            -uri "$URI_BASE:$port" \
            -type $ops > "$logfile" 2>&1 &

        pid=$!
        echo "$pid" >> "$PID_FILE"
        echo "   ↳ PID: $pid | Log: $logfile"
    done

    sleep 100;
    ./parser.sh $LOG_DIR
    done

    echo "✅ All client processes started. Logs saved in $LOG_DIR"
    
}

stop_clients() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "⚠️  No PID file found. Attempting to find running mongo-bench processes..."
        pids=$(pgrep -f "mongo-bench")
    else
        pids=$(cat "$PID_FILE")
    fi

    if [[ -z "$pids" ]]; then
        echo "ℹ️  No running mongo-bench clients found."
        return
    fi

    echo "🛑 Stopping mongo-bench clients..."
    for pid in $pids; do
        if kill "$pid" 2>/dev/null; then
            echo "✅ Stopped client PID $pid"
        else
            echo "⚠️  Could not stop PID $pid (may already be dead)"
        fi
    done

    rm -f "$PID_FILE"
    echo "🧹 Cleanup complete."
}



# ===== MAIN =====
case "$1" in
    start)
        start_clients "$2" "$3" "$4"
        ;;
    stop)
        stop_clients
        ;;
    *)
        echo "Usage:"
        echo "  $0 start <num_clients> [threads] [docs]"
        echo "  $0 stop"
        exit 1
        ;;
esac

