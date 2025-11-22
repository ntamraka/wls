#!/usr/bin/env bash
#
# MongoDB Multi-Instance Manager
# Usage:
#   ./mongodb-multi.sh start <N>
#   ./mongodb-multi.sh stop
#   ./mongodb-multi.sh restart <N>
#

# ===== CONFIG =====
BASE_PORT=27017
DATA_DIR="/home/data/mongodb"
LOG_DIR="/home/log/mongodb"
MONGO_BIN="$(command -v mongod || echo /usr/bin/mongod)"
PID_FILE="/tmp/mongodb_multi_pids.txt"

# ===== FUNCTIONS =====

start_instances() {
    local num_instances=$1

    if [[ -z "$num_instances" || "$num_instances" -lt 1 ]]; then
        echo "❌ Please specify a valid number of instances."
        exit 1
    fi

    mkdir -p "$DATA_DIR" "$LOG_DIR"
    echo "" > "$PID_FILE"

    echo "🚀 Starting $num_instances MongoDB instances..."
    for ((i=0; i<num_instances; i++)); do
        port=$((BASE_PORT + i))
        dbpath="$DATA_DIR/instance$i"
        logfile="$LOG_DIR/instance$i.log"

        mkdir -p "$dbpath" "$(dirname "$logfile")"

        echo "➡️  Starting instance $i on port $port"
        "$MONGO_BIN" --port "$port" \
                     --dbpath "$dbpath" \
                     --logpath "$logfile" \
                     --fork \
                     --logappend \
                     --bind_ip localhost

        # Record PID for later shutdown
        pid=$(pgrep -f "mongod.*--port $port")
        echo "$pid" >> "$PID_FILE"
    done
    echo "✅ All instances started. PIDs stored in $PID_FILE"
}

stop_instances() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "⚠️  No PID file found. Trying to find mongod processes..."
        pids=$(pgrep -f "mongod.*--port")
    else
        pids=$(cat "$PID_FILE")
    fi

    if [[ -z "$pids" ]]; then
        echo "ℹ️  No MongoDB instances found to stop."
        return
    fi

    echo "🛑 Stopping MongoDB instances..."
    for pid in $pids; do
        if kill "$pid" 2>/dev/null; then
            echo "✅ Killed PID $pid"
        else
            echo "⚠️  Failed to kill PID $pid (might already be stopped)"
        fi
    done

    rm -f "$PID_FILE"
    echo "🧹 Cleanup complete."
}

restart_instances() {
    local num_instances=$1
    stop_instances
    sleep 2
    start_instances "$num_instances"
}

# ===== MAIN =====
case "$1" in
    start)
        start_instances "$2"
        ;;
    stop)
        stop_instances
        ;;
    restart)
        restart_instances "$2"
        ;;
    *)
        echo "Usage: $0 {start <N>|stop|restart <N>}"
        exit 1
        ;;
esac

