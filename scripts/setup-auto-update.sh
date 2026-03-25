#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Auto Update Setup Script
# Cron job kurulumu için otomatik güncelleme script'ini yapılandırır
# ════════════════════════════════════════════════════════════

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  FinansAsistan - Auto Update Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
AUTO_UPDATE_SCRIPT="$SCRIPT_DIR/auto-update-from-s3.sh"

# Check if auto-update script exists
if [ ! -f "$AUTO_UPDATE_SCRIPT" ]; then
    log_error "auto-update-from-s3.sh not found!"
    exit 1
fi

# Make script executable
chmod +x "$AUTO_UPDATE_SCRIPT"
log_success "Auto update script is executable"

# Get current user
CURRENT_USER=${SUDO_USER:-$USER}
if [ "$CURRENT_USER" = "root" ]; then
    CURRENT_USER=$(whoami)
fi

# Ask for update interval
echo ""
log_info "Select update check interval:"
echo "  1) Every 5 minutes (recommended for production)"
echo "  2) Every 10 minutes (balanced)"
echo "  3) Every 15 minutes (conservative)"
echo "  4) Every 30 minutes (low frequency)"
echo "  5) Custom interval"
echo ""
read -p "Enter choice [1-5] (default: 2): " INTERVAL_CHOICE
INTERVAL_CHOICE=${INTERVAL_CHOICE:-2}

case $INTERVAL_CHOICE in
    1)
        CRON_INTERVAL="*/5"
        INTERVAL_TEXT="every 5 minutes"
        ;;
    2)
        CRON_INTERVAL="*/10"
        INTERVAL_TEXT="every 10 minutes"
        ;;
    3)
        CRON_INTERVAL="*/15"
        INTERVAL_TEXT="every 15 minutes"
        ;;
    4)
        CRON_INTERVAL="*/30"
        INTERVAL_TEXT="every 30 minutes"
        ;;
    5)
        read -p "Enter cron interval (e.g., */10 for every 10 minutes): " CRON_INTERVAL
        INTERVAL_TEXT="custom interval ($CRON_INTERVAL)"
        ;;
    *)
        CRON_INTERVAL="*/10"
        INTERVAL_TEXT="every 10 minutes"
        ;;
esac

# Create cron job
CRON_JOB="$CRON_INTERVAL * * * * cd $PROJECT_DIR && $AUTO_UPDATE_SCRIPT >> $PROJECT_DIR/.auto-update.log 2>&1"

# Check if cron job already exists
if crontab -u "$CURRENT_USER" -l 2>/dev/null | grep -q "$AUTO_UPDATE_SCRIPT"; then
    log_warn "Cron job already exists. Updating..."
    # Remove old cron job
    crontab -u "$CURRENT_USER" -l 2>/dev/null | grep -v "$AUTO_UPDATE_SCRIPT" | crontab -u "$CURRENT_USER" -
fi

# Add new cron job
(crontab -u "$CURRENT_USER" -l 2>/dev/null; echo "$CRON_JOB") | crontab -u "$CURRENT_USER" -

log_success "Cron job installed successfully!"

# Setup instant update trigger watcher
WATCH_SCRIPT="$SCRIPT_DIR/watch-update-trigger.sh"
if [ -f "$WATCH_SCRIPT" ]; then
    chmod +x "$WATCH_SCRIPT"
    log_info "Setting up instant update trigger watcher..."
    
    # Check if watcher is already running
    if pgrep -f "watch-update-trigger.sh" > /dev/null; then
        log_warn "Update trigger watcher is already running"
    else
        log_info "Starting update trigger watcher in background..."
        nohup bash "$WATCH_SCRIPT" >> "$PROJECT_DIR/.update-trigger.log" 2>&1 &
        WATCHER_PID=$!
        echo "$WATCHER_PID" > "$PROJECT_DIR/.update-trigger.pid"
        log_success "Update trigger watcher started (PID: $WATCHER_PID)"
        log_info "Watcher checks S3 every 10 seconds for instant updates"
    fi
else
    log_warn "watch-update-trigger.sh not found, skipping instant update setup"
fi

echo ""
echo "Configuration:"
echo "  User: $CURRENT_USER"
echo "  Interval: $INTERVAL_TEXT"
echo "  Script: $AUTO_UPDATE_SCRIPT"
echo "  Log file: $PROJECT_DIR/.auto-update.log"
if [ -f "$WATCH_SCRIPT" ]; then
    echo "  Instant Update Watcher: Running (checks every 10s)"
    echo "  Watcher log: $PROJECT_DIR/.update-trigger.log"
fi
echo ""
echo "Cron job:"
echo "  $CRON_JOB"
echo ""
log_info "To view cron jobs: crontab -l"
log_info "To remove cron job: crontab -e (then delete the line)"
log_info "To view update logs: tail -f $PROJECT_DIR/.auto-update.log"
if [ -f "$WATCH_SCRIPT" ]; then
    log_info "To view watcher logs: tail -f $PROJECT_DIR/.update-trigger.log"
    log_info "To stop watcher: kill \$(cat $PROJECT_DIR/.update-trigger.pid)"
fi
echo ""

