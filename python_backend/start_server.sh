#!/bin/bash

# BrightBite Python Backend Auto-Start Script
# This script is called by the iOS app to start the Python server

set -e  # Exit on error

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Log file
LOG_FILE="$SCRIPT_DIR/server.log"
PID_FILE="$SCRIPT_DIR/server.pid"

# Function to check if server is already running
is_server_running() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            return 0  # Server is running
        fi
    fi
    return 1  # Server is not running
}

# Function to stop existing server
stop_server() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            echo "Stopping existing server (PID: $PID)..."
            kill "$PID" 2>/dev/null || true
            sleep 2
            # Force kill if still running
            if ps -p "$PID" > /dev/null 2>&1; then
                kill -9 "$PID" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi
}

# Check if server is already running
if is_server_running; then
    echo "Server is already running (PID: $(cat $PID_FILE))"
    exit 0
fi

# Stop any existing server
stop_server

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo "ERROR: Python 3 is not installed"
    echo "Please install Python 3: brew install python3"
    exit 1
fi

# Check if virtualenv exists, create if not
if [ ! -d "venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv venv
fi

# Activate virtual environment
source venv/bin/activate

# Install/update dependencies
echo "Installing dependencies..."
pip3 install -q --upgrade pip
pip3 install -q -r requirements.txt

# Get local IP address
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "127.0.0.1")

# Start the server in background
echo "Starting BrightBite Python Backend on $LOCAL_IP:8000..."
nohup python3 app.py > "$LOG_FILE" 2>&1 &
SERVER_PID=$!

# Save PID
echo "$SERVER_PID" > "$PID_FILE"

# Wait a bit for server to start
sleep 3

# Check if server started successfully
if ps -p "$SERVER_PID" > /dev/null 2>&1; then
    echo "✅ Server started successfully (PID: $SERVER_PID)"
    echo "📍 Server running at: http://$LOCAL_IP:8000"
    echo "📋 Logs: $LOG_FILE"
    exit 0
else
    echo "❌ Server failed to start"
    cat "$LOG_FILE"
    exit 1
fi
