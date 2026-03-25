#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Mac Docker Compose Setup Script
# S3'ten projeyi indirir, DB'yi restore eder ve Docker Compose ile baslatir
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
echo "  FinansAsistan - macOS Docker Compose Setup"
echo "═══════════════════════════════════════════════════════════"
echo ""

# 1. Check prerequisites
log_info "Checking prerequisites..."

# Check macOS version
MACOS_VERSION=$(sw_vers -productVersion)
log_info "macOS version: $MACOS_VERSION"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    log_error "This script is for macOS only!"
    exit 1
fi

# Check Docker Desktop
log_info "Checking Docker installation..."
if ! command -v docker &> /dev/null; then
    log_error "Docker Desktop not found!"
    echo ""
    echo "Docker Desktop is required to run this project."
    echo "Download URL: https://www.docker.com/products/docker-desktop"
    echo ""
    
    # Try to open download page
    if command -v open &> /dev/null; then
        read -p "Would you like to open the download page? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open "https://www.docker.com/products/docker-desktop"
        fi
    fi
    
    echo ""
    echo "After installing Docker Desktop:"
    echo "  1. Start Docker Desktop"
    echo "  2. Wait for it to fully start"
    echo "  3. Restart terminal"
    echo "  4. Run this script again"
    exit 1
else
    log_success "Docker found: $(docker --version)"
fi

# Check if Docker is running
log_info "Checking if Docker is running..."
if ! docker ps &> /dev/null; then
    log_error "Docker Desktop is not running!"
    echo ""
    echo "Please:"
    echo "  1. Start Docker Desktop"
    echo "  2. Wait for it to fully start (Docker icon in menu bar)"
    echo "  3. Run this script again"
    exit 1
else
    log_success "Docker is running"
fi

# Check Docker Compose
log_info "Checking Docker Compose..."
if docker compose version &> /dev/null; then
    log_success "Docker Compose found (v2)"
elif docker-compose --version &> /dev/null; then
    log_success "Docker Compose found (v1)"
else
    log_error "Docker Compose not found!"
    echo "Docker Desktop includes Docker Compose. Please ensure Docker Desktop is running."
    exit 1
fi

# Check curl (required for AWS CLI installation)
if ! command -v curl &> /dev/null; then
    log_warn "curl not found. Installing via Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || log_warn "Please install Xcode Command Line Tools manually"
fi

# 2. Check/Install AWS CLI
log_info "Checking AWS CLI installation..."
if ! command -v aws &> /dev/null; then
    log_warn "AWS CLI not found. Installing..."
    
    # Check if Homebrew is available (preferred method)
    if command -v brew &> /dev/null; then
        log_info "Installing AWS CLI via Homebrew..."
        brew install awscli || {
            log_warn "Homebrew installation failed, trying direct download..."
            curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
            sudo installer -pkg AWSCLIV2.pkg -target /
            rm -f AWSCLIV2.pkg
        }
    else
        log_info "Installing AWS CLI via direct download..."
        curl "https://awscli.amazonaws.com/AWSCLIV2.pkg" -o "AWSCLIV2.pkg"
        sudo installer -pkg AWSCLIV2.pkg -target /
        rm -f AWSCLIV2.pkg
    fi
    
    # Verify installation
    if command -v aws &> /dev/null; then
        log_success "AWS CLI installed: $(aws --version)"
    else
        log_error "AWS CLI installation failed!"
        echo "Please install AWS CLI manually: https://aws.amazon.com/cli/"
        exit 1
    fi
else
    log_success "AWS CLI found: $(aws --version)"
fi

# 2.5. Check/Install ArgoCD CLI (both dev and production mode)
install_argocd_cli() {
    log_info "Installing ArgoCD CLI..."
    
    # Check if already installed (try Homebrew first)
    if command -v argocd &> /dev/null; then
        if argocd version --client >/dev/null 2>&1; then
            log_success "ArgoCD CLI already installed: $(argocd version --client 2>&1 | head -n1)"
            return 0
        fi
    fi
    
    # Try Homebrew first
    if command -v brew &> /dev/null; then
        log_info "Attempting to install ArgoCD CLI via Homebrew..."
        if brew install argocd; then
            if argocd version --client >/dev/null 2>&1; then
                log_success "ArgoCD CLI installed via Homebrew"
                return 0
            fi
        fi
    fi
    
    # Fallback to manual installation
    local version
    version=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep -oP '"tag_name": "\K[^"]*' || echo "v3.2.0")
    
    # Determine architecture
    local arch="amd64"
    if [ "$(uname -m)" = "arm64" ]; then
        arch="arm64"
    fi
    
    # Download and install
    local install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"
    
    local download_url="https://github.com/argoproj/argo-cd/releases/download/${version}/argocd-darwin-${arch}"
    local output_path="${install_dir}/argocd"
    
    log_info "Downloading ArgoCD CLI from GitHub..."
    if curl -sSL -o "$output_path" "$download_url"; then
        chmod +x "$output_path"
        
        # Add to PATH if not already there
        if [[ ":$PATH:" != *":$install_dir:"* ]]; then
            export PATH="$install_dir:$PATH"
            if [ -f "$HOME/.zshrc" ]; then
                echo "export PATH=\"$install_dir:\$PATH\"" >> "$HOME/.zshrc"
            fi
            if [ -f "$HOME/.bash_profile" ]; then
                echo "export PATH=\"$install_dir:\$PATH\"" >> "$HOME/.bash_profile"
            fi
            log_info "Added $install_dir to PATH"
        fi
        
        # Verify installation
        if "$output_path" version --client >/dev/null 2>&1; then
            log_success "ArgoCD CLI installed successfully"
            return 0
        fi
    fi
    
    log_warn "Failed to install ArgoCD CLI automatically"
    log_info "You can install it manually from: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    return 1
}

log_info "Checking ArgoCD CLI installation..."
if command -v argocd &> /dev/null; then
    if argocd version --client >/dev/null 2>&1; then
        log_success "ArgoCD CLI found: $(argocd version --client 2>&1 | head -n1)"
    else
        log_warn "ArgoCD CLI found but not working properly. Attempting to reinstall..."
        install_argocd_cli
    fi
else
    log_warn "ArgoCD CLI not found. Installing..."
    install_argocd_cli
fi

# 3. Check AWS Credentials
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

# Check if we're in production mode
IS_PRODUCTION=false
if [ "${ENVIRONMENT:-}" = "production" ] || [ "${ENV:-}" = "production" ] || [ "${MODE:-}" = "production" ]; then
    IS_PRODUCTION=true
    log_info "Production mode detected (environment variable)"
fi

# 3.5. Leadership Secret Verification
log_info "Verifying leadership secret..."

# Load .env file first to get JWT_SECRET
ENV_FILE=""
if [ -f "QUICK_START/.env" ]; then
    ENV_FILE="QUICK_START/.env"
elif [ -f "../QUICK_START/.env" ]; then
    ENV_FILE="../QUICK_START/.env"
fi

if [ -z "$ENV_FILE" ] || [ ! -f "$ENV_FILE" ]; then
    log_warn "QUICK_START/.env file not found. Skipping secret verification."
    log_warn "This might be the first setup or .env file is not configured yet."
    SKIP_SECRET_CHECK=true
else
    # Load .env file
    set -a
    source "$ENV_FILE" 2>/dev/null || true
    set +a
    
    # Get JWT_SECRET from .env file
    EXPECTED_SECRET="${JWT_SECRET:-}"
    
    if [ -z "$EXPECTED_SECRET" ]; then
        log_warn "JWT_SECRET not found in QUICK_START/.env. Skipping secret verification."
        SKIP_SECRET_CHECK=true
    else
        # Prompt for secret (hidden input)
        echo ""
        echo "🔐 Leadership Secret Required"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        read -sp "Enter leadership secret: " USER_SECRET
        echo ""
        echo ""
        
        if [ "$USER_SECRET" != "$EXPECTED_SECRET" ]; then
            log_error "Invalid leadership secret! Access denied."
            log_error "Please contact the administrator for the correct secret."
            exit 1
        fi
        
        log_success "Leadership secret verified!"
        log_info "Connecting to GitHub..."
    fi
fi

# 4. Download complete project from S3
# Check if we're in production or development mode
if [ "${ENVIRONMENT:-}" = "production" ] || [ "${MODE:-}" = "production" ]; then
    IS_PRODUCTION=true
else
    IS_PRODUCTION=false
fi

PROJECT_DIR="FinansAsistan"

# Create directory if it doesn't exist
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit 1

# Development mode: Check if files exist, skip S3 download if they do
SKIP_S3_DOWNLOAD=false
if [ "$IS_PRODUCTION" = false ]; then
    if [ -f "docker-compose.dev.yml" ] || [ -d "back" ] || [ -d "front" ]; then
        log_info "Development mode: Local project files found. Skipping S3 download..."
        log_info "Using existing local files. If you need to update, delete the project directory first."
        SKIP_S3_DOWNLOAD=true
    else
        log_info "Development mode: Local project files not found. Downloading from S3..."
    fi
else
    log_info "Production mode: Downloading from S3 (will overwrite local files)..."
fi

# Download from S3 if not skipped
if [ "$SKIP_S3_DOWNLOAD" = false ]; then
    log_info "Downloading from s3://${S3_BUCKET}/FinansAsistan/..."
    sync_output=$(aws s3 sync "s3://${S3_BUCKET}/FinansAsistan/" . \
        --exclude ".git/*" \
        --exclude ".github/workflows/*.yml" \
        --exclude "*.log" \
        --exclude ".DS_Store" \
        --exclude "Thumbs.db" 2>&1)
    sync_exit_code=$?

    # Check if the error is just about missing .env file (this is acceptable)
    if echo "$sync_output" | grep -q "NoSuchKey.*\.env"; then
        log_warn ".env file not found in S3 (this is acceptable, will create from template)"
        # If only .env was missing, consider it success
        if [ $sync_exit_code -ne 0 ] && ! echo "$sync_output" | grep -v "NoSuchKey.*\.env" | grep -q "error\|Error\|ERROR"; then
            sync_exit_code=0  # Treat as success if only .env was missing
        fi
    fi

    if [ $sync_exit_code -ne 0 ]; then
        log_error "Failed to download project from S3"
        log_error "Error output: $sync_output"
        exit 1
    fi

    log_success "Project downloaded from S3"
else
    log_success "Project ready (using local files)"
fi

# Load .env file from QUICK_START directory
ENV_FILE="../QUICK_START/.env"
if [ ! -f "$ENV_FILE" ]; then
    # Try absolute path if relative doesn't work
    if [ -f "QUICK_START/.env" ]; then
        ENV_FILE="QUICK_START/.env"
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

# 5. Restore PostgreSQL backup from S3
log_info "Checking for PostgreSQL backup in S3..."
if aws s3 ls "s3://${S3_BUCKET}/postgres/backups/" &>/dev/null; then
    log_info "PostgreSQL backup found. Will restore after containers start..."
    RESTORE_DB=true
else
    log_warn "No PostgreSQL backup found. Will use fresh database."
    RESTORE_DB=false
fi

# 6. Start Docker Compose
# Only start Docker Compose if NOT in production mode (production uses k3s/Kubernetes)
if [ "$IS_PRODUCTION" = "false" ]; then
    log_info "Starting Docker Compose services..."
    docker-compose -f docker-compose.dev.yml up -d --build || docker compose -f docker-compose.dev.yml up -d --build

    log_info "Waiting for PostgreSQL to be ready..."
    for i in {1..60}; do
        if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_DB" ]; then
            echo "Error: POSTGRES_USER and POSTGRES_DB environment variables must be set"
            exit 1
        fi
        if docker-compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" &>/dev/null || \
           docker compose exec -T postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" &>/dev/null; then
            log_success "PostgreSQL is ready"
            break
        fi
        sleep 2
    done
else
    log_info "Production mode: Skipping Docker Compose services (using Kubernetes/k3s instead)"
fi

# 7. Restore database if backup exists
if [ "$RESTORE_DB" = true ]; then
    log_info "Restoring PostgreSQL database from S3..."
    
    # Find latest backup
    LATEST_BACKUP=$(aws s3 ls "s3://${S3_BUCKET}/postgres/backups/" \
        --recursive | sort | tail -n 1 | awk '{print $4}')
    
    if [ -n "$LATEST_BACKUP" ]; then
        log_info "Found backup: $LATEST_BACKUP"
        
        # Download backup
        BACKUP_FILE="/tmp/postgres_backup.sql.gz"
        aws s3 cp "s3://${S3_BUCKET}/${LATEST_BACKUP}" "$BACKUP_FILE"
        
        # Restore database
        if [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_DB" ] || [ -z "$POSTGRES_PASSWORD" ]; then
            echo "Error: POSTGRES_USER, POSTGRES_DB, and POSTGRES_PASSWORD environment variables must be set"
            exit 1
        fi
        docker-compose exec -T postgres bash -c "dropdb -U $POSTGRES_USER $POSTGRES_DB || true" || \
        docker compose exec -T postgres bash -c "dropdb -U $POSTGRES_USER $POSTGRES_DB || true"

        docker-compose exec -T postgres bash -c "createdb -U $POSTGRES_USER $POSTGRES_DB" || \
        docker compose exec -T postgres bash -c "createdb -U $POSTGRES_USER $POSTGRES_DB"

        gunzip -c "$BACKUP_FILE" | docker-compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres psql -U $POSTGRES_USER -d $POSTGRES_DB || \
        gunzip -c "$BACKUP_FILE" | docker compose exec -T -e PGPASSWORD="$POSTGRES_PASSWORD" postgres psql -U $POSTGRES_USER -d $POSTGRES_DB
        
        rm -f "$BACKUP_FILE"
        log_success "Database restored from S3"
    else
        log_warn "No backup file found, using fresh database"
    fi
fi

# 8. Leadership Functions
# Detect machine type (EC2 vs Physical)
detect_physical_machine() {
    if curl -s --max-time 1 http://169.254.169.254/latest/meta-data/instance-id &> /dev/null; then
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        MACHINE_TYPE="ec2"
        MACHINE_ID="${INSTANCE_ID}"
        log_info "Detected EC2 instance: ${INSTANCE_ID}"
    else
        MACHINE_TYPE="physical"
        MACHINE_ID=$(hostname)
        log_info "Detected physical machine: ${MACHINE_ID}"
    fi
    export MACHINE_TYPE
    export MACHINE_ID
}

# Check current leader from S3
check_current_leader() {
    if [ -z "${S3_BUCKET:-}" ]; then
        return 1
    fi
    
    CURRENT_LEADER=$(aws s3 cp "s3://${S3_BUCKET}/current-leader.json" - 2>/dev/null || echo "")
    if [ -n "$CURRENT_LEADER" ]; then
        echo "$CURRENT_LEADER"
        return 0
    fi
    return 1
}

# Check leader eligibility
check_leader_eligibility() {
    CURRENT_LEADER=$(check_current_leader)
    if [ -n "$CURRENT_LEADER" ]; then
        CURRENT_LEADER_TYPE=$(echo "$CURRENT_LEADER" | jq -r '.leader_type // "unknown"' 2>/dev/null || echo "unknown")
        CURRENT_LEADER_ID=$(echo "$CURRENT_LEADER" | jq -r '.leader_id // ""' 2>/dev/null || echo "")
        
        # If same machine, allow takeover
        if [ "$CURRENT_LEADER_ID" = "$MACHINE_ID" ]; then
            return 0
        fi
        
        # If physical machine exists and it's not this machine, don't take over (for EC2)
        if [ "$CURRENT_LEADER_TYPE" = "physical" ] && [ "$MACHINE_TYPE" != "physical" ]; then
            log_info "Physical machine leader exists - this EC2 will not be leader"
            return 1
        fi
        
        # If another physical machine is leader, check timestamp (2 min rule)
        if [ "$CURRENT_LEADER_TYPE" = "physical" ] && [ "$CURRENT_LEADER_ID" != "$MACHINE_ID" ]; then
            CURRENT_REGISTERED_AT=$(echo "$CURRENT_LEADER" | jq -r '.registered_at // ""' 2>/dev/null || echo "")
            if [ -n "$CURRENT_REGISTERED_AT" ]; then
                # Parse UTC time correctly (force UTC, ignore local timezone)
                # Note: date -jf with Z suffix parses as UTC, and date -u +%s ensures UTC epoch time
                CURRENT_TIMESTAMP=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$CURRENT_REGISTERED_AT" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$CURRENT_REGISTERED_AT" +%s 2>/dev/null || echo "0")
                NOW_TIMESTAMP=$(date -u +%s)
                DIFF_SECONDS=$((NOW_TIMESTAMP - CURRENT_TIMESTAMP))
                DIFF_MINUTES=$((DIFF_SECONDS / 60))
                if [ $DIFF_MINUTES -lt 2 ]; then
                    log_info "Another physical machine is leader (registered $DIFF_MINUTES minutes ago, less than 2 minutes) - this machine will not be leader"
                    return 1  # Too recent, don't take over
                fi
            fi
        fi
    fi
    return 0  # Eligible
}

# Start heartbeat daemon (updates heartbeat every 15 seconds)
start_heartbeat_daemon() {
    if [ -z "${S3_BUCKET:-}" ]; then
        return 0
    fi
    
    log_info "Starting heartbeat daemon..."
    
    CONSECUTIVE_NON_LEADER_CHECKS=0
    
    while true; do
        sleep 15
        
        if [ -z "${MACHINE_ID:-}" ] || [ -z "${MACHINE_TYPE:-}" ]; then
            continue
        fi
        
        # Update heartbeat
        CURRENT_LEADER=$(check_current_leader)
        if [ -n "$CURRENT_LEADER" ]; then
            CURRENT_LEADER_ID=$(echo "$CURRENT_LEADER" | jq -r '.leader_id // ""' 2>/dev/null || echo "")
            
            if [ "$CURRENT_LEADER_ID" = "$MACHINE_ID" ]; then
                # This machine is still the leader - update heartbeat
                # CRITICAL: Re-read from S3 to prevent race condition (optimistic locking)
                # Another machine might have taken over leadership between read and write
                TEMP_VERIFY_FILE="/tmp/current-leader-heartbeat-verify-$$-$(date +%s).json"
                
                aws s3 cp "s3://${S3_BUCKET}/current-leader.json" "$TEMP_VERIFY_FILE" 2>/dev/null
                
                if [ $? -eq 0 ] && [ -f "$TEMP_VERIFY_FILE" ]; then
                    VERIFY_LEADER=$(cat "$TEMP_VERIFY_FILE" 2>/dev/null | jq -r '.' 2>/dev/null || echo "")
                    
                    if [ -n "$VERIFY_LEADER" ]; then
                        VERIFY_LEADER_ID=$(echo "$VERIFY_LEADER" | jq -r '.leader_id // ""' 2>/dev/null || echo "")
                        
                        # Verify we're still the leader before updating
                        if [ "$VERIFY_LEADER_ID" = "$MACHINE_ID" ]; then
                            # Still the leader - safe to update heartbeat
                CONSECUTIVE_NON_LEADER_CHECKS=0
                            UPDATED_LEADER=$(echo "$VERIFY_LEADER" | jq \
                    --arg last_heartbeat "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                    '.last_heartbeat = $last_heartbeat')
                
                echo "$UPDATED_LEADER" | aws s3 cp - "s3://${S3_BUCKET}/current-leader.json" \
                    --content-type "application/json" 2>/dev/null || true
                        else
                            # Leadership was taken over between read and write - don't update
                            # This will be handled in the next iteration (else branch)
                            :
                        fi
                    fi
                    
                    rm -f "$TEMP_VERIFY_FILE" 2>/dev/null || true
                fi
            else
                # Another machine is now the leader - this machine should convert to worker
                CONSECUTIVE_NON_LEADER_CHECKS=$((CONSECUTIVE_NON_LEADER_CHECKS + 1))
                if [ $CONSECUTIVE_NON_LEADER_CHECKS -eq 1 ]; then
                    # First detection: Remove leader label, log demotion, and trigger worker conversion
                    if command -v kubectl &> /dev/null && kubectl cluster-info &>/dev/null 2>&1; then
                        # Remove leader label from this node
                        NODES=$(kubectl get nodes -o json 2>/dev/null)
                        if [ $? -eq 0 ] && [ -n "$NODES" ]; then
                            NODE_NAME=$(echo "$NODES" | jq -r --arg machine_id "$MACHINE_ID" '.items[] | select(.metadata.labels."kubernetes.io/hostname" == $machine_id or .metadata.name == $machine_id) | .metadata.name' | head -n 1)
                            if [ -n "$NODE_NAME" ]; then
                                kubectl label node "$NODE_NAME" leader- 2>/dev/null || true
                            fi
                        fi
                    fi
                    
                    # Log demotion
                    LOG_FILE="/tmp/leader-demotion-$(date +%Y%m%d-%H%M%S).log"
                    LOG_MESSAGE="[$(date -u +'%Y-%m-%d %H:%M:%S') UTC] Liderlik devredildi: Yeni lider '$CURRENT_LEADER_ID' tespit edildi. Bu makine worker moduna geciriliyor..."
                    echo "$LOG_MESSAGE" > "$LOG_FILE"
                    
                    # Get script directory (try multiple methods)
                    SCRIPT_DIR=""
                    if [ -n "${BASH_SOURCE[0]:-}" ]; then
                        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
                    elif [ -n "$0" ]; then
                        SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
                    else
                        # Fallback: try to find scripts directory
                        if [ -d "scripts" ]; then
                            SCRIPT_DIR="$(pwd)/scripts"
                        elif [ -d "$(pwd)/FinansAsistan/scripts" ]; then
                            SCRIPT_DIR="$(pwd)/FinansAsistan/scripts"
                        fi
                    fi
                    
                    # Create worker conversion flag file with leader info
                    WORKER_FLAG_FILE="/tmp/convert-to-worker.flag"
                    
                    # Check if flag file already exists (script might be running or already processed)
                    SHOULD_TRIGGER_CONVERSION=true
                    if [ -f "$WORKER_FLAG_FILE" ]; then
                        if command -v jq &> /dev/null; then
                            EXISTING_LEADER_ID=$(jq -r '.new_leader_id // ""' "$WORKER_FLAG_FILE" 2>/dev/null || echo "")
                            if [ -n "$EXISTING_LEADER_ID" ] && [ "$EXISTING_LEADER_ID" = "$CURRENT_LEADER_ID" ]; then
                                # Same leader, script might be running - don't trigger again
                                SHOULD_TRIGGER_CONVERSION=false
                            else
                                # Different leader - remove old flag and create new one
                                rm -f "$WORKER_FLAG_FILE"
                            fi
                        else
                            # jq not available, remove old flag and create new one
                            rm -f "$WORKER_FLAG_FILE"
                        fi
                    fi
                    
                    if [ "$SHOULD_TRIGGER_CONVERSION" = "true" ]; then
                        # Extract leader info
                        CURRENT_LEADER_IP=$(echo "$CURRENT_LEADER" | jq -r '.node_ip // ""' 2>/dev/null || echo "")
                        CURRENT_K3S_TOKEN=$(echo "$CURRENT_LEADER" | jq -r '.k3s_token // ""' 2>/dev/null || echo "")
                        CURRENT_K3S_SERVER_URL=$(echo "$CURRENT_LEADER" | jq -r '.k3s_server_url // ""' 2>/dev/null || echo "")
                        DETECTED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                        
                        # Create worker info JSON
                        WORKER_INFO=$(jq -n \
                            --arg new_leader_id "$CURRENT_LEADER_ID" \
                            --arg new_leader_ip "$CURRENT_LEADER_IP" \
                            --arg k3s_token "$CURRENT_K3S_TOKEN" \
                            --arg k3s_server_url "$CURRENT_K3S_SERVER_URL" \
                            --arg detected_at "$DETECTED_AT" \
                            '{new_leader_id: $new_leader_id, new_leader_ip: $new_leader_ip, k3s_token: $k3s_token, k3s_server_url: $k3s_server_url, detected_at: $detected_at}')
                        
                        echo "$WORKER_INFO" > "$WORKER_FLAG_FILE"
                        
                        # Trigger worker conversion script in background
                        if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/convert-to-worker.sh" ]; then
                            chmod +x "$SCRIPT_DIR/convert-to-worker.sh" 2>/dev/null || true
                            nohup bash "$SCRIPT_DIR/convert-to-worker.sh" "$WORKER_FLAG_FILE" > /tmp/convert-to-worker.log 2>&1 &
                            LOG_MESSAGE="$LOG_MESSAGE\nWorker conversion script baslatildi: $SCRIPT_DIR/convert-to-worker.sh (PID: $!)"
                        else
                            LOG_MESSAGE="$LOG_MESSAGE\nUYARI: convert-to-worker.sh script bulunamadi ($SCRIPT_DIR/convert-to-worker.sh). Manuel olarak worker moduna gecmeniz gerekiyor."
                        fi
                        echo -e "$LOG_MESSAGE" > "$LOG_FILE"
                    else
                        LOG_MESSAGE="$LOG_MESSAGE\nWorker conversion zaten baslatilmis (flag dosyasi mevcut) - atlaniyor"
                        echo -e "$LOG_MESSAGE" > "$LOG_FILE"
                    fi
                fi
                # Don't update heartbeat - this machine is no longer the leader
                # Worker conversion process has been triggered
            fi
        fi
    done
}

# Register leadership
register_leadership() {
    local FORCE=${1:-false}  # First parameter: force takeover
    
    if [ -z "${S3_BUCKET:-}" ]; then
        log_warn "S3_BUCKET not set, skipping leadership registration"
        return 0
    fi
    
    detect_physical_machine
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        log_warn "jq not found, installing..."
        if command -v brew &> /dev/null; then
            brew install jq > /dev/null 2>&1
        else
            log_warn "Cannot install jq automatically. Please install jq manually: brew install jq"
            return 0
        fi
    fi
    
    # Force mode: Check if there's an existing leader and handle takeover
    if [ "$FORCE" = "true" ]; then
        CURRENT_LEADER=$(check_current_leader)
        if [ -n "$CURRENT_LEADER" ]; then
            CURRENT_LEADER_ID=$(echo "$CURRENT_LEADER" | jq -r '.leader_id // ""' 2>/dev/null || echo "")
            if [ -n "$CURRENT_LEADER_ID" ] && [ "$CURRENT_LEADER_ID" != "$MACHINE_ID" ]; then
                # Old leader is a different machine - convert it to worker
                log_info "Force takeover: Mevcut lider ($CURRENT_LEADER_ID) liderliginden devrediyor..."
                log_warn "Eski lider ($CURRENT_LEADER_ID) worker moduna geciriliyor..."
                
                # Remove leader label from old leader node (if Kubernetes is accessible)
                if command -v kubectl &> /dev/null && kubectl cluster-info &>/dev/null 2>&1; then
                    NODES=$(kubectl get nodes -o json 2>/dev/null)
                    if [ $? -eq 0 ] && [ -n "$NODES" ]; then
                        OLD_LEADER_NODE=$(echo "$NODES" | jq -r --arg leader_id "$CURRENT_LEADER_ID" '.items[] | select(.metadata.labels."kubernetes.io/hostname" == $leader_id or .metadata.name == $leader_id) | .metadata.name' | head -n 1)
                        if [ -n "$OLD_LEADER_NODE" ]; then
                            kubectl label node "$OLD_LEADER_NODE" leader- 2>/dev/null || true
                            log_info "Eski lider node'undan leader label kaldirildi: $OLD_LEADER_NODE"
                        fi
                    fi
                fi
            elif [ -n "$CURRENT_LEADER_ID" ] && [ "$CURRENT_LEADER_ID" = "$MACHINE_ID" ]; then
                # Old leader is this machine - needs full restart
                log_info "Bu makine zaten lider - Servisler temizlenip yeniden baslatilacak..."
                log_warn "[WARNING] Mevcut liderlik temizleniyor, tum servisler yeniden baslatilacak"
                
                # Set flag for full restart (export to make it available to parent script)
                export NEEDS_FULL_RESTART=true
            fi
        fi
    else
        # Normal mode: Check current leader and take over if older than 2 minutes
        CURRENT_LEADER=$(check_current_leader)
        if [ -n "$CURRENT_LEADER" ]; then
            CURRENT_LEADER_ID=$(echo "$CURRENT_LEADER" | jq -r '.leader_id // ""' 2>/dev/null || echo "")
            CURRENT_LEADER_TYPE=$(echo "$CURRENT_LEADER" | jq -r '.leader_type // "unknown"' 2>/dev/null || echo "unknown")
            
            # If another physical machine is leader, check if we can take over
            if [ "$CURRENT_LEADER_TYPE" = "physical" ] && [ "$CURRENT_LEADER_ID" != "$MACHINE_ID" ]; then
                CURRENT_REGISTERED_AT=$(echo "$CURRENT_LEADER" | jq -r '.registered_at // ""' 2>/dev/null || echo "")
                if [ -n "$CURRENT_REGISTERED_AT" ]; then
                    # Parse UTC time correctly (force UTC, ignore local timezone)
                    # Note: date -jf with Z suffix parses as UTC, and date -u +%s ensures UTC epoch time
                    CURRENT_TIMESTAMP=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$CURRENT_REGISTERED_AT" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$CURRENT_REGISTERED_AT" +%s 2>/dev/null || echo "0")
                    NOW=$(date -u +%s)
                    DIFF_SECONDS=$((NOW - CURRENT_TIMESTAMP))
                    DIFF_MINUTES=$((DIFF_SECONDS / 60))
                    
                    log_info "Current leader registered at: $CURRENT_REGISTERED_AT"
                    log_info "Current time: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
                    log_info "Time difference: $DIFF_MINUTES minutes"
                    
                    # If leader is older than 2 minutes, take over immediately
                    if [ $DIFF_MINUTES -ge 2 ]; then
                        log_info "Current leader is older than 2 minutes, taking over leadership..."
                        
                        NODE_IP=$(curl -s --max-time 5 https://ifconfig.me/ip 2>/dev/null || echo "unknown")
                        if [ -z "$NODE_IP" ] || echo "$NODE_IP" | grep -q '<html'; then
                            NODE_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "unknown")
                        fi
                        
                        REGISTERED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
                        LAST_HEARTBEAT=$REGISTERED_AT
                        
                        NEW_LEADER=$(jq -n \
                            --arg leader_id "$MACHINE_ID" \
                            --arg leader_type "$MACHINE_TYPE" \
                            --arg node_ip "$NODE_IP" \
                            --arg registered_at "$REGISTERED_AT" \
                            --arg last_heartbeat "$LAST_HEARTBEAT" \
                            '{leader_id: $leader_id, leader_type: $leader_type, node_ip: $node_ip, registered_at: $registered_at, last_heartbeat: $last_heartbeat}')
                        
                        echo "$NEW_LEADER" | aws s3 cp - "s3://${S3_BUCKET}/current-leader.json" \
                            --content-type "application/json" 2>/dev/null
                        
                        if [ $? -eq 0 ]; then
                            log_success "Leadership taken over successfully"
                            log_info "   Leader ID: ${MACHINE_ID}"
                            log_info "   Leader Type: ${MACHINE_TYPE}"
                            log_info "   Node IP: ${NODE_IP}"
                            
                            # Start heartbeat daemon in background
                            start_heartbeat_daemon &
                        else
                            log_warn "Failed to take over leadership in S3"
                        fi
                        return 0
                    else
                        log_info "Another physical machine is leader (registered $DIFF_MINUTES minutes ago, less than 2 minutes) - this machine will not be leader"
                        return 0
                    fi
                fi
            fi
        fi
        
        # Normal eligibility check
        if ! check_leader_eligibility; then
            log_info "This machine is not eligible to be leader - skipping registration"
            return 0
        fi
    fi
    
    NODE_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "unknown")
    
    # CRITICAL: Optimistic locking - read current leader before writing
    # If another machine took over, don't overwrite it (unless Force mode)
    SHOULD_WRITE=true
    
    if [ "$FORCE" != "true" ]; then
        # Normal mode: Check if another machine is active leader
        TEMP_CURRENT_LEADER_FILE="/tmp/current-leader-check-$$-$(date +%s).json"
        aws s3 cp "s3://${S3_BUCKET}/current-leader.json" "$TEMP_CURRENT_LEADER_FILE" 2>/dev/null
        
        if [ $? -eq 0 ] && [ -f "$TEMP_CURRENT_LEADER_FILE" ]; then
            CURRENT_LEADER_JSON=$(cat "$TEMP_CURRENT_LEADER_FILE" 2>/dev/null || echo "")
            
            if [ -n "$CURRENT_LEADER_JSON" ]; then
                CURRENT_LEADER_ID=$(echo "$CURRENT_LEADER_JSON" | jq -r '.leader_id // ""' 2>/dev/null || echo "")
                
                # Check if another machine is already the leader (and not us)
                if [ -n "$CURRENT_LEADER_ID" ] && [ "$CURRENT_LEADER_ID" != "$MACHINE_ID" ]; then
                    # Another machine is the leader - check if it's active
                    CURRENT_LAST_HEARTBEAT=$(echo "$CURRENT_LEADER_JSON" | jq -r '.last_heartbeat // ""' 2>/dev/null || echo "")
                    
                    if [ -n "$CURRENT_LAST_HEARTBEAT" ]; then
                        # Parse heartbeat timestamp (ISO 8601 format) - macOS date command
                        CURRENT_HEARTBEAT_EPOCH=$(date -jf "%Y-%m-%dT%H:%M:%SZ" "$CURRENT_LAST_HEARTBEAT" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "$CURRENT_LAST_HEARTBEAT" +%s 2>/dev/null || echo "0")
                        NOW_EPOCH=$(date -u +%s)
                        DIFF_SECONDS=$((NOW_EPOCH - CURRENT_HEARTBEAT_EPOCH))
                        # Use bash arithmetic instead of bc (no dependency)
                        DIFF_MINUTES=$((DIFF_SECONDS / 60))
                        
                        # If current leader is active (heartbeat < 1 minute = 60 seconds), don't overwrite
                        # EXCEPT if the current leader is an EC2 instance and we are a physical machine (Return Home feature)
                        if [ $DIFF_SECONDS -ge 0 ] && [ $DIFF_SECONDS -lt 60 ]; then
                            if [ "$(echo "$CURRENT_LEADER_JSON" | jq -r '.leader_type')" = "ec2" ] && [ "$MACHINE_TYPE" = "physical" ]; then
                                log_info "AWS-Cloud-Leader tespit edildi. 'Eve Donus' (Return Home) ozelligi ile liderlik devraliniyor..."
                                SHOULD_WRITE=true
                            else
                                log_warn "Baska bir makine zaten aktif lider ($CURRENT_LEADER_ID, heartbeat: ${DIFF_SECONDS} saniye once)"
                                log_warn "Leadership kaydi yapilmadi - mevcut lider korunuyor"
                                log_info "Force takeover icin -Force parametresi kullanin"
                                SHOULD_WRITE=false
                            fi
                        fi
                    fi
                fi
            fi
            
            rm -f "$TEMP_CURRENT_LEADER_FILE" 2>/dev/null || true
        fi
    else
        # Force mode: Overwrite regardless of current leader
        log_info "Force mode aktif - mevcut lider kontrolu atlaniyor"
    fi
    
    if [ "$SHOULD_WRITE" = "true" ]; then
    LEADER_INFO=$(jq -n \
        --arg leader_id "$MACHINE_ID" \
        --arg leader_type "$MACHINE_TYPE" \
        --arg node_ip "$NODE_IP" \
        --arg registered_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg last_heartbeat "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{
            leader_id: $leader_id,
            leader_type: $leader_type,
            node_ip: $node_ip,
            registered_at: $registered_at,
            last_heartbeat: $last_heartbeat
        }')
    
    echo "$LEADER_INFO" | aws s3 cp - "s3://${S3_BUCKET}/current-leader.json" \
        --content-type "application/json" || {
        log_warn "Failed to register leadership in S3"
        return 1
    }
    
        # CRITICAL: Verify write was successful by reading back (prevent race condition where another machine wrote after us)
        TEMP_VERIFY_FILE="/tmp/leader-verify-$$-$(date +%s).json"
        aws s3 cp "s3://${S3_BUCKET}/current-leader.json" "$TEMP_VERIFY_FILE" 2>/dev/null
        
        WRITE_CONFIRMED=false
        if [ $? -eq 0 ] && [ -f "$TEMP_VERIFY_FILE" ]; then
            VERIFY_JSON=$(cat "$TEMP_VERIFY_FILE" 2>/dev/null || echo "")
            
            if [ -n "$VERIFY_JSON" ]; then
                VERIFY_LEADER_ID=$(echo "$VERIFY_JSON" | jq -r '.leader_id // ""' 2>/dev/null || echo "")
                
                # Verify we're still the leader (another machine might have written after us)
                if [ "$VERIFY_LEADER_ID" = "$MACHINE_ID" ]; then
                    WRITE_CONFIRMED=true
                else
                    log_warn "Leadership write basarili ama dogrulama basarisiz - baska bir makine lider oldu ($VERIFY_LEADER_ID)"
                fi
            else
                # Verification read failed, assume success
                WRITE_CONFIRMED=true
            fi
            
            rm -f "$TEMP_VERIFY_FILE" 2>/dev/null || true
        else
            # Verification read failed, assume success
            WRITE_CONFIRMED=true
        fi
        
        if [ "$WRITE_CONFIRMED" = "true" ]; then
    log_success "Leadership registered in S3"
    log_info "   Leader ID: ${MACHINE_ID}"
    log_info "   Leader Type: ${MACHINE_TYPE}"
    log_info "   Node IP: ${NODE_IP}"
    
    # Reset AWS ASG Capacity (Return Home feature)
    if [ "$MACHINE_TYPE" = "physical" ]; then
        log_info "AWS Auto Scaling Group kapasitesi sifirlaniyor (fiziksel lider aktif)..."
        ASG_NAME="${LEADER_ASG_NAME:-finans-leader-pool}"
        aws autoscaling set-desired-capacity --auto-scaling-group-name "$ASG_NAME" --desired-capacity 0 --honor-cooldown 2>/dev/null || true
        log_success "AWS ASG kapasitesi sifirlandi."
    fi

    # Start heartbeat daemon in background
    start_heartbeat_daemon &
        else
            log_warn "Leadership registration dogrulanamadi - baska bir makine lider olmus olabilir"
        fi
    fi
}

# 9. Register leadership (only in production mode)
if [ "$IS_PRODUCTION" = true ]; then
    log_info "Registering leadership..."
    
    # Check if control-plane mode (force takeover) or normal mode
    FORCE_MODE=false
    if [ -n "${MODE_ACTION:-}" ]; then
        case "$MODE_ACTION" in
            prod-cp-a|prod-cp-b|prod-cp-c1|prod-cp-c2)
                FORCE_MODE=true
                log_info "Control-plane mode detected: Force leadership takeover enabled"
                ;;
            prod-worker)
                log_info "Worker mode: Skipping leadership registration"
                ;;
            *)
                log_info "Normal leadership registration (no force)"
                ;;
        esac
    fi
    
    if [ "$MODE_ACTION" != "prod-worker" ]; then
        register_leadership "$FORCE_MODE"
    fi
else
    log_info "Development mode - skipping leadership registration (no auto-start in AWS)"
fi

# 9.5. Cleanup existing resources (always for fresh start, or full restart after leadership takeover)
# Always cleanup for all modes except worker to ensure clean state
SHOULD_CLEANUP=false
if [ "${NEEDS_FULL_RESTART:-false}" = "true" ]; then
    SHOULD_CLEANUP=true
elif [ -n "${MODE_ACTION:-}" ]; then
    case "$MODE_ACTION" in
        prod-cp-a|prod-cp-b|prod-cp-c1|prod-cp-c2|dev)
            SHOULD_CLEANUP=true
            ;;
        prod-worker)
            SHOULD_CLEANUP=false
            ;;
        *)
            SHOULD_CLEANUP=true
            ;;
    esac
fi

if [ "$SHOULD_CLEANUP" = "true" ]; then
    log_warn "[WARNING] FULL CLEANUP: This will remove ALL containers, pods, volumes, and Kubernetes resources!"
    log_warn "[WARNING] This will cause DATA LOSS if volumes are deleted!"
    log_info "Performing full cleanup of existing resources..."
    
    # Cleanup Docker resources
    if command -v docker &> /dev/null; then
        log_info "Cleaning up Docker resources..."
        
        # Stop containers using compose files
        if [ -f "docker-compose.dev.yml" ]; then
            docker compose -f docker-compose.dev.yml down --remove-orphans --volumes 2>/dev/null || true
        fi
        if [ -f "docker-compose.prod.yml" ]; then
            docker compose -f docker-compose.prod.yml down --remove-orphans --volumes 2>/dev/null || true
        fi
        
        # Stop and remove all FinansAsistan containers
        docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "finans-|finansasistan-" | while read -r container; do
            if [ -n "$container" ]; then
                docker stop "$container" 2>/dev/null || true
                docker rm -f "$container" 2>/dev/null || true
            fi
        done
        
        # Remove FinansAsistan volumes
        docker volume ls --format "{{.Name}}" 2>/dev/null | grep -E "finans-|finansasistan-" | while read -r volume; do
            if [ -n "$volume" ]; then
                docker volume rm "$volume" 2>/dev/null || true
            fi
        done
        
        log_success "Docker resources cleaned up"
    fi
    
    # Cleanup Kubernetes resources
    log_info "Cleaning up Kubernetes resources..."
    if command -v kubectl &> /dev/null && kubectl cluster-info &>/dev/null 2>&1; then
        # Delete all resources in finans-asistan namespace
        if kubectl get namespace finans-asistan &>/dev/null 2>&1; then
            log_info "Deleting all resources in finans-asistan namespace..."
            kubectl delete all --all -n finans-asistan --ignore-not-found=true --timeout=60s 2>/dev/null || true
            kubectl delete pvc --all -n finans-asistan --ignore-not-found=true --timeout=60s 2>/dev/null || true
            kubectl delete configmap,secret --all -n finans-asistan --ignore-not-found=true --timeout=60s 2>/dev/null || true
            kubectl delete ingress --all -n finans-asistan --ignore-not-found=true --timeout=60s 2>/dev/null || true
            kubectl delete namespace finans-asistan --ignore-not-found=true --timeout=120s 2>/dev/null || true
        fi
        
        # Delete ArgoCD resources (if any)
        log_info "Cleaning up ArgoCD resources..."
        kubectl delete deployment,statefulset,service,configmap,secret -n default -l app.kubernetes.io/part-of=argocd --ignore-not-found=true --timeout=60s 2>/dev/null || true
        kubectl delete deployment argocd-server argocd-repo-server argocd-applicationset-controller argocd-dex-server argocd-notifications-controller argocd-redis -n default --ignore-not-found=true --timeout=60s 2>/dev/null || true
        kubectl delete statefulset argocd-application-controller -n default --ignore-not-found=true --timeout=60s 2>/dev/null || true
        
        # Cleanup Traefik
        if kubectl get namespace traefik-system &>/dev/null 2>&1; then
            log_info "Cleaning up Traefik resources..."
            kubectl delete all --all -n traefik-system --ignore-not-found=true --timeout=60s 2>/dev/null || true
            kubectl delete namespace traefik-system --ignore-not-found=true --timeout=120s 2>/dev/null || true
        fi
        
        # Cleanup monitoring namespace
        if kubectl get namespace monitoring &>/dev/null 2>&1; then
            log_info "Cleaning up monitoring resources..."
            kubectl delete all --all -n monitoring --ignore-not-found=true --timeout=60s 2>/dev/null || true
            kubectl delete pvc --all -n monitoring --ignore-not-found=true --timeout=60s 2>/dev/null || true
            kubectl delete namespace monitoring --ignore-not-found=true --timeout=120s 2>/dev/null || true
        fi
        
        log_success "Kubernetes resources cleaned up"
    else
        log_info "kubectl not found, skipping Kubernetes cleanup"
    fi
    
    # Remove networks
    docker network ls --format "{{.Name}}" 2>/dev/null | grep -E "finans-|finansasistan-" | while read -r network; do
        if [ -n "$network" ]; then
            docker network rm "$network" 2>/dev/null || true
        fi
    done
    
    log_success "Full cleanup completed"
    log_warn "[WARNING] All existing resources have been removed. Starting fresh installation..."
    sleep 3
else
    log_info "Skipping cleanup (worker mode or no restart needed)"
fi

# 9.5. Start update trigger watcher (for automatic updates on GitHub push)
WATCH_SCRIPT="$SCRIPT_DIR/watch-update-trigger.sh"
if [ -f "$WATCH_SCRIPT" ]; then
    chmod +x "$WATCH_SCRIPT"
    log_info "Setting up automatic update watcher..."
    
    # Check if watcher is already running
    if pgrep -f "watch-update-trigger.sh" > /dev/null; then
        log_warn "Update trigger watcher is already running"
    else
        log_info "Starting update trigger watcher in background..."
        nohup bash "$WATCH_SCRIPT" >> "$PROJECT_DIR/.update-trigger.log" 2>&1 &
        WATCHER_PID=$!
        echo "$WATCHER_PID" > "$PROJECT_DIR/.update-trigger.pid"
        log_success "Update trigger watcher started (PID: $WATCHER_PID)"
        log_info "Watcher checks S3 every 10 seconds for instant updates from GitHub"
        log_info "Logs: tail -f $PROJECT_DIR/.update-trigger.log"
    fi
else
    log_warn "watch-update-trigger.sh not found, skipping automatic update setup"
fi

# 10. Setup Kubernetes (Production only)
if [ "$IS_PRODUCTION" = "true" ]; then
    log_info "Setting up Kubernetes for production..."
    
    BOOTSTRAP_SCRIPT="$PROJECT_DIR/scripts/bootstrap.sh"
    if [ -f "$BOOTSTRAP_SCRIPT" ]; then
        log_info "Found bootstrap script, setting up Kubernetes cluster..."
        chmod +x "$BOOTSTRAP_SCRIPT"
        
        # Set environment variables for bootstrap script
        export S3_BUCKET="$S3_BUCKET"
        export AWS_REGION="$AWS_REGION"
        export ENVIRONMENT="production"
        export MODE="production"
        
        # Run bootstrap script in background (non-blocking)
        log_info "Starting Kubernetes bootstrap in background..."
        cd "$PROJECT_DIR"
        nohup bash "$BOOTSTRAP_SCRIPT" >> "$PROJECT_DIR/.bootstrap.log" 2>&1 &
        BOOTSTRAP_PID=$!
        log_success "Kubernetes bootstrap started (PID: $BOOTSTRAP_PID)"
        log_info "This will install k3s, ArgoCD, and deploy Kubernetes resources"
        log_info "Logs: tail -f $PROJECT_DIR/.bootstrap.log"
        log_info "Check status: kubectl get nodes"
    else
        log_warn "Bootstrap script not found at: $BOOTSTRAP_SCRIPT"
        log_info "Kubernetes setup will be skipped"
    fi
else
    log_info "Development mode - skipping Kubernetes setup"
fi

# 11. Show status
echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  ${GREEN}SUCCESS!${NC} FinansAsistan is running!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Services:"
echo "  Frontend:  http://localhost:9999"
echo "  Backend:   http://localhost:5000"
echo "  PostgreSQL: localhost:5432"
echo "  Kafka:     localhost:9092"
echo "  Redis:     localhost:6379"
echo ""
echo "Useful commands:"
echo "  View logs:     docker-compose logs -f"
echo "  Stop services: docker-compose down"
echo "  Restart:       docker-compose restart"
echo ""

