#!/bin/bash

# BrightBite Python Backend Stop Script

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PID_FILE="$SCRIPT_DIR/server.pid"

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "Stopping server (PID: $PID)..."
        kill "$PID" 2>/dev/null || true
        sleep 2
        # Force kill if still running
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Force stopping server..."
            kill -9 "$PID" 2>/dev/null || true
        fi
        echo "✅ Server stopped"
    else
        echo "Server is not running"
    fi
    rm -f "$PID_FILE"
else
    echo "No PID file found - server may not be running"
fi

# Also kill any python processes running app.py
pkill -f "python.*app.py" 2>/dev/null || true

echo "Done"
