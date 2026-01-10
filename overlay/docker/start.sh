#!/bin/bash
set -e

DATA_DIR="${DATA_DIR:-/data}"
UPLOAD_DIR="${UPLOAD_DIR:-/uploads}"
PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                     FACET DEMO                            ║"
echo "║                                                           ║"
echo "║  Login: demo@example.com / demo123                        ║"
echo "║  Data resets daily at midnight UTC                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if [ -z "$ENCRYPTION_KEY" ]; then
    echo "Generating demo ENCRYPTION_KEY..."
    export ENCRYPTION_KEY=$(openssl rand -hex 32)
fi

mkdir -p "$DATA_DIR" "$UPLOAD_DIR"

if [ -d "/app/seed-data/data" ] && [ ! -f "$DATA_DIR/data.db" ]; then
    echo "First run detected - restoring seed data..."
    cp -r /app/seed-data/data/* "$DATA_DIR/" 2>/dev/null || true
    cp -r /app/seed-data/uploads/* "$UPLOAD_DIR/" 2>/dev/null || true
    echo "Seed data restored."
fi

if [ -n "$PUID" ] && [ -n "$PGID" ]; then
    if getent group "$PGID" > /dev/null 2>&1; then
        GROUP_NAME=$(getent group "$PGID" | cut -d: -f1)
    else
        groupadd -g "$PGID" facet 2>/dev/null || true
        GROUP_NAME="facet"
    fi
    
    if id -u "$PUID" > /dev/null 2>&1; then
        USER_NAME=$(id -un "$PUID")
    else
        useradd -u "$PUID" -g "$GROUP_NAME" -s /bin/bash -m facet 2>/dev/null || true
        USER_NAME="facet"
    fi
    
    chown -R "$PUID:$PGID" "$DATA_DIR" "$UPLOAD_DIR" /app 2>/dev/null || true
fi

setup_cron() {
    if command -v cron &> /dev/null; then
        echo "0 0 * * * root /app/reset-demo.sh >> /var/log/demo-reset.log 2>&1" > /etc/cron.d/demo-reset
        chmod 0644 /etc/cron.d/demo-reset
        cron
        echo "Daily reset cron configured (midnight UTC)"
    fi
}

setup_cron &

cd /app

echo "Starting Caddy..."
caddy start --config Caddyfile
echo "Successfully started Caddy (pid=$!) - Caddy is running in the background"

echo "Starting backend (PocketBase)..."
./facet serve --http=0.0.0.0:8090 --dir="$DATA_DIR" &
BACKEND_PID=$!

sleep 3

echo "Starting frontend (SvelteKit)..."
cd frontend
node build/index.js &
FRONTEND_PID=$!

cd /app

cleanup() {
    echo "Shutting down..."
    kill $BACKEND_PID $FRONTEND_PID 2>/dev/null || true
    caddy stop 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT

wait $BACKEND_PID $FRONTEND_PID
