#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Development Mode Startup Script
# Lokal geliştirme için hot reload ile Docker Compose başlatır
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
echo "  FinansAsistan - Development Mode"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. Check Docker
if ! command -v docker &> /dev/null; then
    log_error "Docker not found. Please install Docker first."
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
    log_error "Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

# Determine docker-compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
else
    DOCKER_COMPOSE="docker compose"
fi

# 2. Check if docker-compose.dev.yml exists
if [ ! -f "docker-compose.dev.yml" ]; then
    log_error "docker-compose.dev.yml not found!"
    exit 1
fi

# 3. Load .env file from QUICK_START directory
ENV_FILE="QUICK_START/.env"
if [ ! -f "$ENV_FILE" ]; then
    # Try relative path if absolute doesn't work
    if [ -f "../QUICK_START/.env" ]; then
        ENV_FILE="../QUICK_START/.env"
    elif [ -f "$(dirname "$0")/../QUICK_START/.env" ]; then
        ENV_FILE="$(dirname "$0")/../QUICK_START/.env"
    else
        log_error ".env file not found at QUICK_START/.env"
        log_error "Please create QUICK_START/.env file with required environment variables"
        log_error "Required variables: POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, JWT_SECRET, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, S3_BUCKET"
        exit 1
    fi
fi

log_info "Loading .env file from: $ENV_FILE"
set -a
source "$ENV_FILE"
set +a

# 4. Install dependencies if needed
log_info "Checking dependencies..."
if [ ! -d "back/node_modules" ]; then
    log_info "Installing backend dependencies..."
    cd back && npm install && cd ..
fi
if [ ! -d "front/node_modules" ]; then
    log_info "Installing frontend dependencies..."
    cd front && npm install && cd ..
fi

# 5. Start Docker Compose in development mode
log_info "Starting Docker Compose services in development mode..."
log_info "Hot reload enabled - code changes will be reflected automatically"

$DOCKER_COMPOSE -f docker-compose.dev.yml up -d --build

log_info "Waiting for services to be ready..."
sleep 10

# 6. Show status
log_info "Checking service status..."
$DOCKER_COMPOSE -f docker-compose.dev.yml ps

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ${GREEN}SUCCESS!${NC} Development environment is running!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Services:"
echo "  Frontend:  http://localhost:9999 (Hot reload enabled)"
echo "  Backend:   http://localhost:5000 (Hot reload enabled)"
echo "  PostgreSQL: localhost:5432"
echo "  Kafka:     localhost:9092"
echo "  Redis:     localhost:6379"
echo ""
echo "Development features:"
echo "  ✅ Hot reload - Code changes are reflected automatically"
echo "  ✅ Volume mounts - Edit code locally, see changes instantly"
echo "  ✅ Development tools - Nodemon, Webpack Dev Server"
echo ""
echo "Useful commands:"
echo "  View logs:     $DOCKER_COMPOSE -f docker-compose.dev.yml logs -f"
echo "  View backend:  $DOCKER_COMPOSE -f docker-compose.dev.yml logs -f backend"
echo "  View frontend: $DOCKER_COMPOSE -f docker-compose.dev.yml logs -f frontend"
echo "  Stop services: $DOCKER_COMPOSE -f docker-compose.dev.yml down"
echo "  Restart:       $DOCKER_COMPOSE -f docker-compose.dev.yml restart"
echo ""
echo "💡 Tip: Edit code in back/ or front/ directories and see changes instantly!"
echo ""

