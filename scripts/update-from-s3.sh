#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Development Update Script (Docker Compose)
# S3'ten yeni kodu çeker ve Docker Compose servislerini restart eder
# 
# ⚠️ NOTE: This script is for DEVELOPMENT only!
# Production uses Kubernetes with ArgoCD for automatic updates.
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
echo "  FinansAsistan - Production Update from S3"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 0. Determine script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Change to project directory
log_info "Changing to project directory: $PROJECT_DIR"
cd "$PROJECT_DIR" || {
    log_error "Failed to change to project directory: $PROJECT_DIR"
    exit 1
}

# 1. Check AWS CLI
if ! command -v aws &> /dev/null; then
    log_error "AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# 2. Check AWS Credentials
# AWS CLI automatically uses credentials from:
# 1. Environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)
# 2. AWS credentials file (~/.aws/credentials)
# 3. IAM roles (if running on EC2)
# 4. AWS SSO
log_info "Checking AWS credentials..."
if ! aws sts get-caller-identity &> /dev/null; then
    log_error "AWS credentials not found or invalid!"
    log_info "Please configure AWS credentials using one of the following methods:"
    log_info "  1. Environment variables:"
    log_info "     export AWS_ACCESS_KEY_ID=your_key"
    log_info "     export AWS_SECRET_ACCESS_KEY=your_secret"
    log_info "  2. AWS credentials file: ~/.aws/credentials"
    log_info "  3. AWS IAM role (if running on EC2)"
    log_info "  4. AWS SSO: aws sso login"
    exit 1
fi
log_success "AWS credentials verified"

AWS_REGION=${AWS_REGION:-eu-central-1}
S3_BUCKET=${S3_BUCKET:-finans-asistan-backups}

# 3. Verify we're in the project directory (already changed above)
# DEVELOPMENT ONLY: This script only works with docker-compose.dev.yml
if [ ! -f "docker-compose.dev.yml" ] && [ ! -f "docker-compose.yml" ]; then
    log_error "docker-compose file not found in project directory: $PROJECT_DIR"
    log_error "This script is for DEVELOPMENT only (Docker Compose)"
    log_error "Production uses Kubernetes with ArgoCD for automatic updates"
    log_error "Current directory: $(pwd)"
    exit 1
fi

# Determine which docker-compose file to use (Development only)
# Priority: docker-compose.dev.yml > docker-compose.yml
COMPOSE_FILE="docker-compose.dev.yml"
if [ -f "docker-compose.dev.yml" ]; then
    COMPOSE_FILE="docker-compose.dev.yml"
    log_info "Using development mode (docker-compose.dev.yml)"
elif [ -f "docker-compose.yml" ]; then
    COMPOSE_FILE="docker-compose.yml"
    log_info "Using docker-compose.yml (fallback)"
else
    log_error "No suitable docker-compose file found for development"
    exit 1
fi

# Warn if production compose file exists (should use Kubernetes instead)
if [ -f "docker-compose.prod.yml" ]; then
    log_warn "docker-compose.prod.yml found but ignored"
    log_warn "Production should use Kubernetes, not Docker Compose"
fi

# 4. Download latest code from S3
log_info "Downloading latest code from S3..."
BACKUP_DIR=".backup-$(date -u +%Y%m%d-%H%M%S)"

# Create backup of current code
log_info "Creating backup of current code..."
mkdir -p "$BACKUP_DIR"
cp -r . "$BACKUP_DIR/" 2>/dev/null || true
log_success "Backup created: $BACKUP_DIR"

# Download from S3
log_info "Downloading from s3://${S3_BUCKET}/FinansAsistan/..."
sync_output=$(aws s3 sync "s3://${S3_BUCKET}/FinansAsistan/" . \
    --exclude ".git/*" \
    --exclude ".github/workflows/*.yml" \
    --exclude "*.log" \
    --exclude ".DS_Store" \
    --exclude "Thumbs.db" \
    --exclude "$BACKUP_DIR/*" 2>&1)
sync_exit_code=$?

# Check if the error is just about missing .env file (this is acceptable)
if echo "$sync_output" | grep -q "NoSuchKey.*\.env"; then
    log_warn ".env file not found in S3 (this is acceptable, will use existing .env or create from template)"
    # If only .env was missing, consider it success
    if [ $sync_exit_code -ne 0 ] && ! echo "$sync_output" | grep -v "NoSuchKey.*\.env" | grep -q "error\|Error\|ERROR"; then
        sync_exit_code=0  # Treat as success if only .env was missing
    fi
fi

if [ $sync_exit_code -ne 0 ]; then
    log_error "Failed to download project from S3"
    log_error "Error output: $sync_output"
    log_warn "Restoring from backup..."
    cp -r "$BACKUP_DIR"/* . 2>/dev/null || true
    exit 1
fi

log_success "Code downloaded from S3"

# 4.1. Also download manifest.json from root directory
log_info "Downloading manifest.json from S3..."
aws s3 cp "s3://${S3_BUCKET}/manifest.json" "manifest.json" 2>/dev/null || {
    log_warn "Could not download manifest.json from S3, will try to read from downloaded files"
}

# 5. Check for changes and determine which services to update
log_info "Determining which services need updates..."

CHANGED_SERVICES_JSON="${CHANGED_SERVICES_JSON:-[]}"

# If CHANGED_SERVICES_JSON is not set, try to read from newly downloaded manifest
if [ "$CHANGED_SERVICES_JSON" = "[]" ] || [ -z "$CHANGED_SERVICES_JSON" ]; then
    # First try to read from S3 manifest (just downloaded)
    MANIFEST_FILE="manifest.json"
    if [ ! -f "$MANIFEST_FILE" ]; then
        # Try alternative location
        MANIFEST_FILE="manifest.json"
    fi
    
    if [ -f "$MANIFEST_FILE" ]; then
        if command -v jq &> /dev/null; then
            CHANGED_SERVICES_JSON=$(jq -r '.changed_services // []' "$MANIFEST_FILE" 2>/dev/null || echo "[]")
        else
            CHANGED_SERVICES_JSON=$(grep -o '"changed_services"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$MANIFEST_FILE" | sed 's/.*\[\(.*\)\].*/[\1]/' || echo "[]")
        fi
        log_info "Read changed_services from manifest: $CHANGED_SERVICES_JSON"
    else
        # Fallback to old manifest
        MANIFEST_FILE=".s3-manifest.json"
        if [ -f "$MANIFEST_FILE" ]; then
            if command -v jq &> /dev/null; then
                CHANGED_SERVICES_JSON=$(jq -r '.changed_services // []' "$MANIFEST_FILE" 2>/dev/null || echo "[]")
            else
                CHANGED_SERVICES_JSON=$(grep -o '"changed_services"[[:space:]]*:[[:space:]]*\[[^]]*\]' "$MANIFEST_FILE" | sed 's/.*\[\(.*\)\].*/[\1]/' || echo "[]")
            fi
        fi
    fi
fi

# Parse changed services
SERVICES_TO_UPDATE=""
if command -v jq &> /dev/null; then
    # Try to parse as JSON first
    SERVICES_TO_UPDATE=$(echo "$CHANGED_SERVICES_JSON" | jq -r '.[]' 2>/dev/null || echo "")
    # If jq failed (invalid JSON like [frontend] without quotes), try manual parsing
    if [ -z "$SERVICES_TO_UPDATE" ]; then
        # Extract service names from [frontend] or ["frontend"] format
        # Remove brackets and quotes, then split by comma
        RAW_SERVICES=$(echo "$CHANGED_SERVICES_JSON" | sed 's/\[//g; s/\]//g; s/"//g' | tr -d ' ')
        if [ -n "$RAW_SERVICES" ]; then
            # Replace comma with space for word splitting
            SERVICES_TO_UPDATE=$(echo "$RAW_SERVICES" | tr ',' ' ' | xargs)
        fi
    fi
else
    # Fallback: manual parsing - handle both [frontend] and ["frontend"] formats
    # Remove brackets and quotes, then split by comma
    RAW_SERVICES=$(echo "$CHANGED_SERVICES_JSON" | sed 's/\[//g; s/\]//g; s/"//g' | tr -d ' ')
    if [ -n "$RAW_SERVICES" ]; then
        # Replace comma with space for word splitting
        SERVICES_TO_UPDATE=$(echo "$RAW_SERVICES" | tr ',' ' ' | xargs)
    fi
fi

if [ -z "$SERVICES_TO_UPDATE" ] || [ "$CHANGED_SERVICES_JSON" = "[]" ]; then
    log_info "No service changes detected. Skipping service restarts."
    log_info "Only configuration or other files were updated."
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  ${GREEN}SUCCESS!${NC} Code updated (no service restarts needed)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Backup location: $BACKUP_DIR"
    echo ""
    exit 0
fi

log_info "Services to update: $SERVICES_TO_UPDATE"

# 6. Install/Update dependencies if needed
log_info "Checking dependencies..."
if [ ! -d "back/node_modules" ] || [ ! -d "front/node_modules" ]; then
    log_info "Installing dependencies..."
    if [ -f "package.json" ]; then
        npm install || true
    fi
    if [ -f "back/package.json" ]; then
        cd back && npm install && cd .. || true
    fi
    if [ -f "front/package.json" ]; then
        cd front && npm install && cd .. || true
    fi
    log_success "Dependencies installed"
else
    log_info "Dependencies already installed"
fi

# 7. Restart only changed Docker Compose services
log_info "Restarting changed Docker Compose services..."

# Check if docker-compose or docker compose is available
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    log_error "Docker Compose not found!"
    exit 1
fi

# Pull latest images and rebuild if needed
log_info "Pulling latest images..."
$DOCKER_COMPOSE -f "$COMPOSE_FILE" pull || log_warn "Some images could not be pulled"

# Health check ile sıralı restart
log_info "Starting rolling restart with health checks for changed services..."

# Helper function: Wait for service to be healthy
wait_for_health() {
    local service_name=$1
    local max_wait=${2:-60}  # Default 60 seconds
    local elapsed=0
    
    log_info "Waiting for $service_name to be healthy (max ${max_wait}s)..."
    
    while [ $elapsed -lt $max_wait ]; do
        # Check if service is healthy using docker inspect
        local container_id=$($DOCKER_COMPOSE -f "$COMPOSE_FILE" ps -q "$service_name" 2>/dev/null)
        if [ -z "$container_id" ]; then
            log_warn "$service_name container not found"
            return 1
        fi
        
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_id" 2>/dev/null || echo "none")
        
        if [ "$health_status" = "healthy" ]; then
            log_success "$service_name is healthy"
            return 0
        elif [ "$health_status" = "unhealthy" ]; then
            log_warn "$service_name is unhealthy, continuing anyway..."
            return 1
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    log_warn "$service_name health check timeout after ${max_wait}s, continuing..."
    return 1
}

# Restart only changed services
SERVICE_COUNT=0
for SERVICE in $SERVICES_TO_UPDATE; do
    SERVICE_COUNT=$((SERVICE_COUNT + 1))
    
    # Map service names to docker-compose service names and set health check timeouts
    COMPOSE_SERVICE=""
    MAX_WAIT=60
    NEEDS_FULL_RESTART=false  # Volume mount kullanan servisler için
    
    case "$SERVICE" in
        "backend")
            COMPOSE_SERVICE="backend"
            MAX_WAIT=60
            NEEDS_FULL_RESTART=true  # Volume mount var: ./back:/app
            ;;
        "frontend")
            COMPOSE_SERVICE="frontend"
            MAX_WAIT=120  # npm install + build + start uzun sürer
            NEEDS_FULL_RESTART=true  # Volume mount var: ./front:/app
            ;;
        "event-processor")
            COMPOSE_SERVICE="event-processor"
            MAX_WAIT=60
            NEEDS_FULL_RESTART=true  # Volume mount var: ./services/event-processor:/app
            ;;
        "postgres")
            COMPOSE_SERVICE="postgres"
            MAX_WAIT=120  # Database başlatma uzun sürebilir
            NEEDS_FULL_RESTART=false
            ;;
        "kafka")
            COMPOSE_SERVICE="kafka"
            MAX_WAIT=90
            NEEDS_FULL_RESTART=false
            ;;
        "redis")
            COMPOSE_SERVICE="redis"
            MAX_WAIT=30
            NEEDS_FULL_RESTART=false
            ;;
        "postgres-backup")
            COMPOSE_SERVICE="postgres-backup"
            MAX_WAIT=60
            NEEDS_FULL_RESTART=true  # Script volume mount var: ./scripts:/scripts
            ;;
        "prometheus")
            COMPOSE_SERVICE="prometheus"
            MAX_WAIT=60
            NEEDS_FULL_RESTART=true  # Config volume mount var
            ;;
        "grafana")
            COMPOSE_SERVICE="grafana"
            MAX_WAIT=60
            NEEDS_FULL_RESTART=true  # Config volume mount var
            ;;
        "alertmanager")
            COMPOSE_SERVICE="alertmanager"
            MAX_WAIT=30
            NEEDS_FULL_RESTART=true  # Config volume mount var
            ;;
        "postgres-exporter")
            COMPOSE_SERVICE="postgres-exporter"
            MAX_WAIT=20
            NEEDS_FULL_RESTART=false
            ;;
        "redis-exporter")
            COMPOSE_SERVICE="redis-exporter"
            MAX_WAIT=20
            NEEDS_FULL_RESTART=false
            ;;
        "kafka-exporter")
            COMPOSE_SERVICE="kafka-exporter"
            MAX_WAIT=30
            NEEDS_FULL_RESTART=false
            ;;
        "loki")
            COMPOSE_SERVICE="loki"
            MAX_WAIT=60
            NEEDS_FULL_RESTART=true  # Config volume mount var
            ;;
        "promtail")
            COMPOSE_SERVICE="promtail"
            MAX_WAIT=30
            NEEDS_FULL_RESTART=true  # Config volume mount var
            ;;
        *)
            log_warn "Unknown service: $SERVICE, attempting to restart anyway..."
            # Bilinmeyen servis için varsayılan değerlerle deneme yap
            COMPOSE_SERVICE="$SERVICE"
            MAX_WAIT=60
            NEEDS_FULL_RESTART=false
            ;;
    esac
    
    # Check if service exists in compose file
    if ! $DOCKER_COMPOSE -f "$COMPOSE_FILE" config --services 2>/dev/null | grep -q "^${COMPOSE_SERVICE}$"; then
        log_warn "Service $COMPOSE_SERVICE not found in compose file, skipping..."
        continue
    fi
    
    log_info "Step ${SERVICE_COUNT}: Restarting $COMPOSE_SERVICE..."
    
    # Volume mount kullanan servisler için tam restart (kod/config değişikliklerinin yansıması için)
    if [ "$NEEDS_FULL_RESTART" = true ]; then
        log_info "$COMPOSE_SERVICE requires full restart (volume mount detected)..."
        # Container'ı durdur
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" stop "$COMPOSE_SERVICE" 2>/dev/null || true
        # Container'ı kaldır (volume mount değişikliklerini yansıtmak için)
        $DOCKER_COMPOSE -f "$COMPOSE_FILE" rm -f "$COMPOSE_SERVICE" 2>/dev/null || true
        # Container'ı yeniden başlat
        # Frontend için build yok ama npm install/build/start komutları tekrar çalışacak
        # Backend ve event-processor için build var, --build flag'i ile build edilecek
        if [ "$COMPOSE_SERVICE" = "frontend" ]; then
            $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d --no-deps "$COMPOSE_SERVICE" || {
                log_error "Failed to restart $COMPOSE_SERVICE"
                continue
            }
        else
            $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d --no-deps --build "$COMPOSE_SERVICE" || {
                log_error "Failed to restart $COMPOSE_SERVICE"
                continue
            }
        fi
    else
        # Image-based servisler için normal restart (config değişiklikleri için)
        log_info "$COMPOSE_SERVICE restarting (image-based service)..."
    $DOCKER_COMPOSE -f "$COMPOSE_FILE" up -d --no-deps --build "$COMPOSE_SERVICE" || {
        log_error "Failed to restart $COMPOSE_SERVICE"
        continue
    }
    fi
    
    wait_for_health "$COMPOSE_SERVICE" "$MAX_WAIT"
done

if [ $SERVICE_COUNT -eq 0 ]; then
    log_warn "No services were restarted"
else
    log_success "Rolling restart completed for $SERVICE_COUNT service(s)"
fi

# 8. Show status
log_info "Checking service status..."
sleep 5
$DOCKER_COMPOSE -f "$COMPOSE_FILE" ps

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ${GREEN}SUCCESS!${NC} Update completed!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Services:"
echo "  Frontend:  http://localhost:9999"
echo "  Backend:   http://localhost:5000"
echo ""
echo "Useful commands:"
echo "  View logs:     $DOCKER_COMPOSE -f $COMPOSE_FILE logs -f"
echo "  Stop services: $DOCKER_COMPOSE -f $COMPOSE_FILE down"
echo "  Restart:       $DOCKER_COMPOSE -f $COMPOSE_FILE restart"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""

