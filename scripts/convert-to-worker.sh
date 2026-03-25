#!/bin/bash
# FinansAsistan - Convert Leader to Worker Script
# Bu script eski lider makineyi worker moduna gecirir
# Windows: Docker Desktop Kubernetes kullanılır (worker join desteklenmez, servisler durdurulur)
# Linux/Mac: k3s agent kurulur ve yeni liderin cluster'ına bağlanır

set -euo pipefail

WORKER_FLAG_FILE="${1:-/tmp/convert-to-worker.flag}"

# Source logging functions if available
if [ -f "$(dirname "$0")/../scripts/setup-linux-docker.sh" ]; then
    # Try to source logging functions from setup script
    source "$(dirname "$0")/../scripts/setup-linux-docker.sh" 2>/dev/null || true
fi

# Fallback logging functions
log_info() {
    echo "[INFO] $1" >&2
}

log_success() {
    echo "[SUCCESS] $1" >&2
}

log_warn() {
    echo "[WARN] $1" >&2
}

log_error() {
    echo "[ERROR] $1" >&2
}

# Check if flag file exists
if [ ! -f "$WORKER_FLAG_FILE" ]; then
    log_error "Worker flag file not found: $WORKER_FLAG_FILE"
    exit 1
fi

# Detect OS
if [ "$(uname)" = "Darwin" ]; then
    RUNNING_ON_MACOS=true
    RUNNING_ON_LINUX=false
elif [ "$(uname)" = "Linux" ]; then
    RUNNING_ON_MACOS=false
    RUNNING_ON_LINUX=true
else
    RUNNING_ON_MACOS=false
    RUNNING_ON_LINUX=false
fi

# Read worker info from flag file
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed"
    exit 1
fi

NEW_LEADER_ID=$(jq -r '.new_leader_id // ""' "$WORKER_FLAG_FILE")
NEW_LEADER_IP=$(jq -r '.new_leader_ip // ""' "$WORKER_FLAG_FILE")
K3S_TOKEN=$(jq -r '.k3s_token // ""' "$WORKER_FLAG_FILE")
K3S_SERVER_URL=$(jq -r '.k3s_server_url // ""' "$WORKER_FLAG_FILE")
DETECTED_AT=$(jq -r '.detected_at // ""' "$WORKER_FLAG_FILE")

if [ -z "$NEW_LEADER_ID" ]; then
    log_error "Worker flag file is invalid: new_leader_id is missing"
    exit 1
fi

log_info "Worker conversion başlatılıyor..."
log_info "  Yeni lider: $NEW_LEADER_ID"
log_info "  Lider IP: $NEW_LEADER_IP"
log_info "  Tespit zamanı: $DETECTED_AT"
log_info "  İşletim Sistemi: $(if [ "$RUNNING_ON_MACOS" = "true" ]; then echo "macOS"; elif [ "$RUNNING_ON_LINUX" = "true" ]; then echo "Linux"; else echo "Unknown"; fi)"

# Stop Docker Compose services if running (before k3s agent join)
# This is similar to Windows behavior - clean up Docker Compose services
if command -v docker &> /dev/null; then
    # Try to find docker-compose files in common locations
    PROJECT_DIR=""
    if [ -f "docker-compose.yml" ]; then
        PROJECT_DIR="$(pwd)"
    elif [ -f "docker-compose.prod.yml" ]; then
        PROJECT_DIR="$(pwd)"
    elif [ -f "FinansAsistan/docker-compose.yml" ]; then
        PROJECT_DIR="$(pwd)/FinansAsistan"
    elif [ -f "FinansAsistan/docker-compose.prod.yml" ]; then
        PROJECT_DIR="$(pwd)/FinansAsistan"
    fi
    
    if [ -n "$PROJECT_DIR" ]; then
        COMPOSE_FILE=""
        if [ -f "$PROJECT_DIR/docker-compose.prod.yml" ]; then
            COMPOSE_FILE="$PROJECT_DIR/docker-compose.prod.yml"
        elif [ -f "$PROJECT_DIR/docker-compose.yml" ]; then
            COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
        fi
        
        if [ -n "$COMPOSE_FILE" ]; then
            log_info "Docker Compose servisleri durduruluyor ($COMPOSE_FILE)..."
            if docker compose -f "$COMPOSE_FILE" down --remove-orphans --volumes --timeout 60 2>/dev/null; then
                log_success "Docker Compose servisleri durduruldu"
            elif docker-compose -f "$COMPOSE_FILE" down --remove-orphans --volumes --timeout 60 2>/dev/null; then
                log_success "Docker Compose servisleri durduruldu"
            else
                log_warn "Docker Compose servisleri durdurulamadı veya hata oluştu"
            fi
        fi
    fi
fi

# Check if k3s token and server URL are available
if [ -z "$K3S_TOKEN" ] || [ -z "$K3S_SERVER_URL" ]; then
    log_error "k3s_token veya k3s_server_url bulunamadı. Worker join yapılamıyor."
    log_info "Manuel olarak worker moduna geçmek için setup script'ini 'prod-worker' modu ile çalıştırın."
    exit 1
fi

# Check if k3s server is running (need to stop it first)
if [ "$RUNNING_ON_LINUX" = "true" ]; then
    if systemctl is-active k3s >/dev/null 2>&1; then
        log_info "k3s server durduruluyor..."
        sudo systemctl stop k3s || true
        log_success "k3s server durduruldu"
    fi
elif [ "$RUNNING_ON_MACOS" = "true" ]; then
    # macOS: Check if k3s is running via launchd or as process
    if pgrep -f k3s >/dev/null 2>&1; then
        log_info "k3s server durduruluyor..."
        # Try to stop via launchctl or kill process
        launchctl unload ~/Library/LaunchAgents/k3s.plist 2>/dev/null || true
        pkill -f k3s 2>/dev/null || true
        log_success "k3s server durduruldu"
    fi
fi

# Install k3s agent
log_info "k3s agent kuruluyor..."
INSTALL_CMD="curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=\"agent --token $K3S_TOKEN --server $K3S_SERVER_URL\" sh -"

if eval "$INSTALL_CMD"; then
    log_success "k3s agent kuruldu ve cluster'a bağlandı"
    
    # Wait a bit for agent to stabilize
    sleep 5
    
    # Verify connection
    log_info "Cluster bağlantısı doğrulanıyor..."
    if sudo kubectl get nodes >/dev/null 2>&1; then
        log_success "Cluster bağlantısı başarılı!"
        log_info "Bu makine artık worker node olarak çalışıyor"
    else
        log_warn "Cluster bağlantısı doğrulanamadı, ancak agent kuruldu"
    fi
else
    log_error "k3s agent kurulumu başarısız"
    exit 1
fi

# Remove flag file after successful conversion
if [ -f "$WORKER_FLAG_FILE" ]; then
    rm -f "$WORKER_FLAG_FILE"
    log_info "Worker flag dosyası temizlendi"
fi

log_success "Worker conversion işlemi tamamlandı"

