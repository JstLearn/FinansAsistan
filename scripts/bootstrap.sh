#!/bin/bash
# ============================================================
# FinansAsistan - Bootstrap Script
# One-command deployment and disaster recovery
# ============================================================

set -euo pipefail


# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Docker check
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # RAM check (minimum 4GB)
    RAM_GB=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$RAM_GB" -lt 4 ]; then
        log_warn "System has less than 4GB RAM. May experience issues."
    fi
    
    # Disk check (minimum 20GB free)
    DISK_GB=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$DISK_GB" -lt 20 ]; then
        log_error "Less than 20GB free disk space. Please free up space."
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Check AWS credentials
check_aws_credentials() {
    log_info "Checking AWS credentials..."
    
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        log_error "AWS credentials not found in environment variables."
        log_error "AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY must be set from GitHub Secrets."
        log_error "In GitHub Actions, these are automatically set from GitHub Secrets."
        exit 1
    fi
    
    if [ -z "${S3_BUCKET:-}" ]; then
        log_error "S3_BUCKET not found in environment variables."
        log_error "S3_BUCKET must be set from GitHub Secrets."
        exit 1
    fi
    
    if command -v aws &> /dev/null; then
        if aws sts get-caller-identity &> /dev/null; then
            log_success "AWS credentials verified"
            return 0
        fi
    fi
    
    log_warn "AWS CLI not installed or credentials invalid"
    return 1
}

# Cleanup all existing resources (full reset)
cleanup_all_resources() {
    log_warn "⚠️  FULL CLEANUP: This will remove ALL containers, pods, volumes, and Kubernetes resources!"
    log_warn "⚠️  This will cause DATA LOSS if volumes are deleted!"
    
    # Cleanup Docker containers and volumes
    log_info "Cleaning up Docker resources..."
    if command -v docker &> /dev/null; then
        # Stop and remove all FinansAsistan containers
        docker ps -a --format "{{.Names}}" 2>/dev/null | grep -E "finans-|finansasistan-" | while read -r container; do
            if [ -n "$container" ]; then
                log_info "Stopping container: $container"
                docker stop "$container" 2>/dev/null || true
                docker rm -f "$container" 2>/dev/null || true
            fi
        done
        
        # Remove Docker Compose resources
        if [ -f "docker-compose.dev.yml" ]; then
            log_info "Cleaning up docker-compose.dev.yml resources..."
            docker compose -f docker-compose.dev.yml down --remove-orphans --volumes 2>/dev/null || true
        fi
        if [ -f "docker-compose.prod.yml" ]; then
            log_info "Cleaning up docker-compose.prod.yml resources..."
            docker compose -f docker-compose.prod.yml down --remove-orphans --volumes 2>/dev/null || true
        fi
        
        # Remove FinansAsistan volumes
        docker volume ls --format "{{.Name}}" 2>/dev/null | grep -E "finans-|finansasistan-" | while read -r volume; do
            if [ -n "$volume" ]; then
                log_info "Removing volume: $volume"
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
        
        # Delete ArgoCD from default namespace
        log_info "Cleaning up ArgoCD resources..."
        kubectl delete deployment,statefulset,service,configmap,secret -n default -l app.kubernetes.io/part-of=argocd --ignore-not-found=true --timeout=60s 2>/dev/null || true
        kubectl delete deployment argocd-server argocd-repo-server argocd-applicationset-controller argocd-dex-server argocd-notifications-controller argocd-redis -n default --ignore-not-found=true --timeout=60s 2>/dev/null || true
        kubectl delete statefulset argocd-application-controller -n default --ignore-not-found=true --timeout=60s 2>/dev/null || true
        
        # Cleanup Traefik
        log_info "Cleaning up Traefik resources..."
        if kubectl get namespace traefik-system &>/dev/null 2>&1; then
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
    fi
    
    # Cleanup k3s data (optional - uncomment if you want to reset k3s completely)
    # log_warn "⚠️  Resetting k3s cluster (this will delete ALL cluster data)..."
    # if command -v k3s &> /dev/null && systemctl is-active --quiet k3s 2>/dev/null; then
    #     systemctl stop k3s 2>/dev/null || true
    #     rm -rf /var/lib/rancher/k3s 2>/dev/null || true
    #     log_success "k3s data cleaned up"
    # fi
    
    log_success "Full cleanup completed"
    log_warn "⚠️  All existing resources have been removed. Starting fresh installation..."
    sleep 3
}

# Detect recovery mode
detect_recovery_mode() {
    log_info "Detecting recovery mode..."
    
    if [ -n "${S3_BUCKET:-}" ] && check_aws_credentials; then
        # Check for any backup indicators (PostgreSQL, Redis, etc.)
        if aws s3 ls "s3://${S3_BUCKET}/postgres/" &> /dev/null || \
           aws s3 ls "s3://${S3_BUCKET}/redis/" &> /dev/null || \
           aws s3 ls "s3://${S3_BUCKET}/kafka/" &> /dev/null; then
            log_info "Backup found in S3. Recovery mode enabled."
            RECOVERY_MODE=true
            return 0
        fi
    fi
    
    RECOVERY_MODE=false
    log_info "Fresh install mode"
    return 0
}

# Download COMPLETE project from S3
download_complete_project_from_s3() {
    log_info "Downloading COMPLETE project from S3..."
    
    if [ -z "${S3_BUCKET:-}" ]; then
        log_warn "S3_BUCKET not set, skipping S3 download"
        return 1
    fi
    
    if ! check_aws_credentials; then
        log_warn "AWS credentials not available, skipping S3 download"
        return 1
    fi
    
    # Check if complete project exists in S3
    if ! aws s3 ls "s3://${S3_BUCKET}/FinansAsistan/" &>/dev/null; then
        log_warn "Complete project not found in S3 at s3://${S3_BUCKET}/FinansAsistan/"
        log_info "Trying legacy locations..."
        
        # Fallback to legacy download method
        return download_from_s3_legacy
    fi
    
    # Create working directory
    mkdir -p FinansAsistan
    cd FinansAsistan || exit 1
    
    log_info "Downloading complete project from s3://${S3_BUCKET}/FinansAsistan/..."
    log_info "This includes ALL files: source code, node_modules (env files excluded)."
    
    # Download complete project from S3
    sync_output=$(aws s3 sync "s3://${S3_BUCKET}/FinansAsistan/" . \
        --exclude ".git/*" \
        --exclude ".github/workflows/*.yml" \
        --exclude "*.log" \
        --exclude ".DS_Store" \
        --exclude "Thumbs.db" 2>&1)
    sync_exit_code=$?
    
    # Ignore .env entirely; do not fail/succeed based on it
    
    if [ $sync_exit_code -ne 0 ]; then
        log_error "Failed to download complete project from S3"
        log_error "Error output: $sync_output"
        return 1
    fi
    
    log_success "Complete project downloaded from S3"
    
    # Do not use or create .env here (secrets come from environment/GitHub Secrets)
    
    # Check if node_modules exist
    if [ -d "node_modules" ] || [ -d "back/node_modules" ] || [ -d "front/node_modules" ]; then
        log_success "node_modules found in project"
    else
        log_info "node_modules not found, will install dependencies"
    fi
    
    return 0
}

# Legacy download method (for backward compatibility)
download_from_s3_legacy() {
    log_info "Using legacy download method..."
    
    # Create working directory
    mkdir -p FinansAsistan
    cd FinansAsistan || exit 1
    
    # Download k8s manifests from S3
    if aws s3 ls "s3://${S3_BUCKET}/FinansAsistan/k8s/" &>/dev/null; then
        log_info "Downloading k8s manifests from S3..."
        mkdir -p k8s
        aws s3 sync "s3://${S3_BUCKET}/FinansAsistan/k8s/" k8s/ --exclude "*.yaml.bak" --exclude ".git/*" || {
            log_warn "Failed to download k8s manifests from S3"
            return 1
        }
        log_success "K8s manifests downloaded from S3"
    else
        log_warn "K8s manifests not found in S3"
        return 1
    fi
    
    # Download bootstrap files (init.sql, postgresql.conf, etc.)
    if aws s3 ls "s3://${S3_BUCKET}/bootstrap/" &>/dev/null; then
        log_info "Downloading bootstrap files from S3..."
        mkdir -p bootstrap
        aws s3 sync "s3://${S3_BUCKET}/bootstrap/" bootstrap/ --exclude ".git/*" || {
            log_warn "Failed to download bootstrap files from S3"
        }
        log_success "Bootstrap files downloaded from S3"
    fi
    
    return 0
}

# Download files from S3 (backward compatibility wrapper)
download_from_s3() {
    download_complete_project_from_s3
}

# Setup repository (S3-first, GitHub fallback)
setup_repository() {
    log_info "Setting up repository..."
    
    # Try S3 first (complete project)
    if download_complete_project_from_s3; then
        log_success "Complete project downloaded from S3"
        
        # Install dependencies if node_modules doesn't exist
        if [ ! -d "node_modules" ] && [ ! -d "back/node_modules" ] && [ ! -d "front/node_modules" ]; then
            log_info "Installing dependencies..."
            install_dependencies
        fi
        
        return 0
    fi
    
    # Fallback: GitHub
    log_warn "S3 download failed, trying GitHub fallback..."
    if [ ! -d "FinansAsistan" ]; then
        if git clone https://github.com/JstLearn/FinansAsistan.git 2>/dev/null; then
            cd FinansAsistan || exit 1
            log_success "Repository ready (from GitHub fallback)"
            
            # Install dependencies
            install_dependencies
            
            return 0
        else
            log_error "Failed to clone repository from both S3 and GitHub"
            exit 1
    fi
    else
    cd FinansAsistan || exit 1
        log_success "Repository ready (existing directory)"
        
        # Install dependencies if needed
        install_dependencies
        
        return 0
    fi
}

# Install dependencies
install_dependencies() {
    log_info "Installing dependencies..."
    
    # Root dependencies
    if [ -f "package.json" ]; then
        log_info "Installing root dependencies..."
        npm install --silent || log_warn "Root npm install failed"
    fi
    
    # Backend dependencies
    if [ -f "back/package.json" ]; then
        log_info "Installing backend dependencies..."
        cd back && npm install --silent && cd .. || log_warn "Backend npm install failed"
    fi
    
    # Frontend dependencies
    if [ -f "front/package.json" ]; then
        log_info "Installing frontend dependencies..."
        cd front && npm install --silent && cd .. || log_warn "Frontend npm install failed"
    fi
    
    log_success "Dependencies installation completed"
}

# Setup environment (no-op). Do not create .env or write secrets to disk.
setup_env() {
    log_info "Environment setup skipped (no .env will be created)"
}

# Get secrets from GitHub Secrets via S3 (exported by GitHub Actions)
get_github_secrets_from_s3() {
    local s3_bucket=$1
    local github_token=$2
    
    if [ -z "$s3_bucket" ]; then
        log_error "S3_BUCKET is required to fetch secrets from S3"
        return 1
    fi
    
    log_info "Fetching secrets from S3 (exported by GitHub Actions)..."
    
    local secrets_path="s3://${s3_bucket}/github-secrets/secrets.json.encrypted"
    local temp_file="/tmp/secrets.json.encrypted"
    
    # Download encrypted secrets file
    if ! aws s3 cp "$secrets_path" "$temp_file" 2>/dev/null; then
        log_warn "Encrypted secrets file not found in S3. GitHub Actions may not have exported secrets yet."
        return 1
    fi
    
    # Decrypt secrets (base64 decode)
    local encrypted_content=$(cat "$temp_file")
    local decrypted_content=$(echo "$encrypted_content" | base64 -d)
    
    # Export secrets as environment variables
    export AWS_ACCESS_KEY_ID=$(echo "$decrypted_content" | jq -r '.AWS_ACCESS_KEY_ID')
    export AWS_SECRET_ACCESS_KEY=$(echo "$decrypted_content" | jq -r '.AWS_SECRET_ACCESS_KEY')
    export S3_BUCKET=$(echo "$decrypted_content" | jq -r '.S3_BUCKET')
    export AWS_REGION=$(echo "$decrypted_content" | jq -r '.AWS_REGION')
    export JWT_SECRET=$(echo "$decrypted_content" | jq -r '.JWT_SECRET')
    export POSTGRES_DB=$(echo "$decrypted_content" | jq -r '.POSTGRES_DB')
    export POSTGRES_USER=$(echo "$decrypted_content" | jq -r '.POSTGRES_USER')
    export POSTGRES_PASSWORD=$(echo "$decrypted_content" | jq -r '.POSTGRES_PASSWORD')
    export EMAIL_USER=$(echo "$decrypted_content" | jq -r '.EMAIL_USER')
    export EMAIL_PASS=$(echo "$decrypted_content" | jq -r '.EMAIL_PASS')
    export ACCESS_TOKEN_GITHUB=$(echo "$decrypted_content" | jq -r '.ACCESS_TOKEN_GITHUB')
    export AWS_ACCOUNT_ID=$(echo "$decrypted_content" | jq -r '.AWS_ACCOUNT_ID')
    export BACKUP_INTERVAL=$(echo "$decrypted_content" | jq -r '.BACKUP_INTERVAL // "300"')
    
    rm -f "$temp_file"
    
    log_info "Secrets downloaded and decrypted from S3"
    return 0
}

# Generate Kubernetes secrets directly from environment variables, DO NOT WRITE FILES
generate_k8s_secrets() {
    log_info "Loading secrets from environment variables..."
    
    # Check if we're running in GitHub Actions
    if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
        # In GitHub Actions, secrets are available as environment variables
        log_info "Running in GitHub Actions - reading secrets from environment variables..."
        
        # Secrets are already set as environment variables in GitHub Actions workflow
        BACKUP_INTERVAL="${BACKUP_INTERVAL:-300}"
        S3_BUCKET="${S3_BUCKET:-}"
        AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
        AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
        JWT_SECRET="${JWT_SECRET:-}"
        AWS_REGION="${AWS_REGION:-eu-central-1}"
        AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
        EMAIL_PASS="${EMAIL_PASS:-}"
        EMAIL_USER="${EMAIL_USER:-}"
        ACCESS_TOKEN_GITHUB="${ACCESS_TOKEN_GITHUB:-}"
        POSTGRES_DB="${POSTGRES_DB:-}"
        POSTGRES_USER="${POSTGRES_USER:-}"
        POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
        GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"
        
        # Verify critical secrets are present
        missing_secrets=""
        if [ -z "$AWS_ACCESS_KEY_ID" ]; then
            missing_secrets="${missing_secrets} AWS_ACCESS_KEY_ID"
        fi
        if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
            missing_secrets="${missing_secrets} AWS_SECRET_ACCESS_KEY"
        fi
        if [ -z "$S3_BUCKET" ]; then
            missing_secrets="${missing_secrets} S3_BUCKET"
        fi
        if [ -z "$JWT_SECRET" ]; then
            missing_secrets="${missing_secrets} JWT_SECRET"
        fi
        if [ -z "$POSTGRES_DB" ]; then
            missing_secrets="${missing_secrets} POSTGRES_DB"
        fi
        if [ -z "$POSTGRES_USER" ]; then
            missing_secrets="${missing_secrets} POSTGRES_USER"
        fi
        if [ -z "$POSTGRES_PASSWORD" ]; then
            missing_secrets="${missing_secrets} POSTGRES_PASSWORD"
        fi
        
        if [ -n "$missing_secrets" ]; then
            log_error "Critical secrets are missing from environment variables:$missing_secrets"
            log_error "Make sure GitHub Actions workflow sets all required secrets as environment variables."
            exit 1
        fi
        
        log_info "All required secrets found (from GitHub Actions environment variables)"
    else
        # Outside GitHub Actions, try multiple sources for secrets
        log_info "Reading secrets from environment variables..."
        
        # Try to load from S3 first (if running on EC2)
        if [ -n "${S3_BUCKET:-}" ] && check_aws_credentials; then
            # Try to load QUICK_START/.env from S3
            if aws s3 cp "s3://${S3_BUCKET}/FinansAsistan/QUICK_START/.env" /tmp/.env 2>/dev/null; then
                log_info "Loading QUICK_START/.env file from S3..."
                set -a
                source /tmp/.env
                set +a
                rm -f /tmp/.env
                log_success "QUICK_START/.env file loaded from S3"
            # Fallback: Try encrypted secrets file
            elif get_github_secrets_from_s3 "${S3_BUCKET}" ""; then
                log_success "Secrets loaded from S3 (encrypted file)"
            else
                log_info "No secrets file found in S3, using environment variables"
            fi
        fi
        
        # Try to load from local .env file (if exists, for local development)
        if [ -f "QUICK_START/.env" ]; then
            log_info "Loading .env file from QUICK_START/.env..."
            set -a
            source "QUICK_START/.env"
            set +a
            log_success ".env file loaded from QUICK_START/.env"
        elif [ -f "../QUICK_START/.env" ]; then
            log_info "Loading .env file from ../QUICK_START/.env..."
            set -a
            source "../QUICK_START/.env"
            set +a
            log_success ".env file loaded from ../QUICK_START/.env"
        fi
        
        # Environment variables should already be set by the calling script or loaded above
        BACKUP_INTERVAL="${BACKUP_INTERVAL:-300}"
        S3_BUCKET="${S3_BUCKET:-}"
        AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-}"
        AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID:-}"
        JWT_SECRET="${JWT_SECRET:-}"
        AWS_REGION="${AWS_REGION:-eu-central-1}"
        AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY:-}"
        EMAIL_PASS="${EMAIL_PASS:-}"
        EMAIL_USER="${EMAIL_USER:-}"
        ACCESS_TOKEN_GITHUB="${ACCESS_TOKEN_GITHUB:-}"
        POSTGRES_DB="${POSTGRES_DB:-}"
        POSTGRES_USER="${POSTGRES_USER:-}"
        POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
        GRAFANA_PASSWORD="${GRAFANA_PASSWORD:-admin}"
        
        # Verify critical secrets are present
        missing_secrets=""
        if [ -z "$AWS_ACCESS_KEY_ID" ]; then
            missing_secrets="${missing_secrets} AWS_ACCESS_KEY_ID"
        fi
        if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
            missing_secrets="${missing_secrets} AWS_SECRET_ACCESS_KEY"
        fi
        if [ -z "$S3_BUCKET" ]; then
            missing_secrets="${missing_secrets} S3_BUCKET"
        fi
        if [ -z "$JWT_SECRET" ]; then
            missing_secrets="${missing_secrets} JWT_SECRET"
        fi
        if [ -z "$POSTGRES_DB" ]; then
            missing_secrets="${missing_secrets} POSTGRES_DB"
        fi
        if [ -z "$POSTGRES_USER" ]; then
            missing_secrets="${missing_secrets} POSTGRES_USER"
        fi
        if [ -z "$POSTGRES_PASSWORD" ]; then
            missing_secrets="${missing_secrets} POSTGRES_PASSWORD"
        fi
        
        if [ -n "$missing_secrets" ]; then
            log_error "Critical secrets are missing from environment variables:$missing_secrets"
            log_error "Make sure one of the following is available:"
            log_error "  1. S3: s3://${S3_BUCKET}/FinansAsistan/QUICK_START/.env"
            log_error "  2. S3: s3://${S3_BUCKET}/github-secrets/secrets.json.encrypted"
            log_error "  3. Local: QUICK_START/.env file"
            log_error "  4. Environment variables set by calling script"
            exit 1
        fi
        
        log_success "All required secrets found"
    fi
    
    # Add Kubernetes service URLs (these are not in GitHub Secrets, they're Kubernetes-specific)
    # Redis service name in Kubernetes: redis (from 03-redis-deployment.yaml)
    REDIS_URL="redis://redis:6379"
    # Kafka service name in Kubernetes: kafka-cluster-kafka-bootstrap (from Strimzi Kafka)
    KAFKA_BROKERS="kafka-cluster-kafka-bootstrap:9092"
    
    # Build kubectl command to create/update secret directly (idempotent)
    kubectl create secret generic app-secrets -n finans-asistan \
        --from-literal=BACKUP_INTERVAL="${BACKUP_INTERVAL:-300}" \
        ${S3_BUCKET:+--from-literal=S3_BUCKET="${S3_BUCKET}"} \
        ${AWS_ACCOUNT_ID:+--from-literal=AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID}"} \
        ${AWS_ACCESS_KEY_ID:+--from-literal=AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"} \
        ${JWT_SECRET:+--from-literal=JWT_SECRET="${JWT_SECRET}"} \
        ${JWT_SECRET:+--from-literal=jwt-secret="${JWT_SECRET}"} \
        --from-literal=AWS_REGION="${AWS_REGION:-eu-central-1}" \
        ${AWS_SECRET_ACCESS_KEY:+--from-literal=AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"} \
        ${EMAIL_PASS:+--from-literal=EMAIL_PASS="${EMAIL_PASS}"} \
        ${EMAIL_PASS:+--from-literal=email-pass="${EMAIL_PASS}"} \
        ${EMAIL_USER:+--from-literal=EMAIL_USER="${EMAIL_USER}"} \
        ${EMAIL_USER:+--from-literal=email-user="${EMAIL_USER}"} \
        ${ACCESS_TOKEN_GITHUB:+--from-literal=ACCESS_TOKEN_GITHUB="${ACCESS_TOKEN_GITHUB}"} \
        ${POSTGRES_DB:+--from-literal=POSTGRES_DB="${POSTGRES_DB}"} \
        ${POSTGRES_USER:+--from-literal=POSTGRES_USER="${POSTGRES_USER}"} \
        ${POSTGRES_PASSWORD:+--from-literal=POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"} \
        --from-literal=redis-url="${REDIS_URL}" \
        --from-literal=kafka-brokers="${KAFKA_BROKERS}" \
        --dry-run=client -o yaml | kubectl apply -f - \
        && log_success "Kubernetes secret 'app-secrets' applied" \
        || { log_error "Failed to apply 'app-secrets' via kubectl"; exit 1; }
    
    # Create Grafana admin secret from GRAFANA_PASSWORD environment variable
    log_info "Creating Grafana admin secret..."
    kubectl create secret generic grafana-admin -n finans-asistan \
        --from-literal=admin-user="admin" \
        --from-literal=admin-password="${GRAFANA_PASSWORD}" \
        --dry-run=client -o yaml | kubectl apply -f - \
        && log_success "Kubernetes secret 'grafana-admin' applied" \
        || { log_error "Failed to apply 'grafana-admin' via kubectl"; exit 1; }
}

# Install k3s
install_k3s() {
    log_info "Installing k3s..."
    
    if command -v k3s &> /dev/null; then
        log_info "k3s already installed"
        # Wait for k3s to be ready
        wait_for_k3s_ready
        return 0
    fi
    
    curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
        --disable traefik \
        --write-kubeconfig-mode 644 \
        --tls-san $(curl -s ifconfig.me 2>/dev/null || echo localhost)" sh -
    
    # Wait for k3s to be ready
    wait_for_k3s_ready
    
    # Setup kubectl
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config 2>/dev/null || true
    sudo chown $(whoami):$(whoami) ~/.kube/config 2>/dev/null || true
    
    log_success "k3s installed and ready"
}

# Wait for k3s to be ready (including token file)
wait_for_k3s_ready() {
    log_info "Waiting for k3s server to be ready..."
    MAX_WAIT=300
    ELAPSED=0
    
    while [ $ELAPSED -lt $MAX_WAIT ]; do
        # Check if k3s service is active
        if systemctl is-active --quiet k3s 2>/dev/null; then
            # Check if token file exists
            if [ -f /var/lib/rancher/k3s/server/node-token ]; then
                # Check if Kubernetes API is ready
                if kubectl get nodes &>/dev/null 2>&1; then
                    log_success "k3s server is ready (token available)"
                    return 0
                fi
            fi
        fi
        
        sleep 5
        ELAPSED=$((ELAPSED + 5))
        if [ $((ELAPSED % 15)) -eq 0 ]; then
            log_info "Still waiting for k3s server... ($ELAPSED/$MAX_WAIT seconds)"
        fi
    done
    
    log_warn "k3s server may not be fully ready yet (timeout after $MAX_WAIT seconds)"
    return 1
}

# Install operators
install_operators() {
    log_info "Installing Kubernetes operators..."
    
    # Metrics Server
    log_info "Installing Metrics Server..."
    if kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>/dev/null; then
    kubectl patch deployment metrics-server -n kube-system \
        --type='json' \
            -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' 2>/dev/null || true
        log_success "Metrics Server installed"
    else
        log_warn "Metrics Server installation failed (may already be installed)"
    fi
    
    # Strimzi (Kafka)
    log_info "Installing Strimzi (Kafka operator)..."
    kubectl create namespace kafka 2>/dev/null || true
    if kubectl create -f 'https://strimzi.io/install/latest?namespace=kafka' -n kafka 2>/dev/null; then
        log_success "Strimzi installed"
    else
        log_warn "Strimzi installation failed (may already be installed)"
    fi
    
    log_success "Operators installation completed"
}

# KEDA removed - using HPA for all services

# Deploy PostgreSQL
deploy_postgres() {
    log_info "Deploying PostgreSQL..."
    
    kubectl apply -f k8s/00-namespace.yaml
    # Ensure app-secrets exists from environment variables (no file creation)
    generate_k8s_secrets
    
    # Wait for namespace to be ready
    sleep 2
    
    # Do not create 'postgres-credentials' anymore. Postgres reads POSTGRES_* directly from app-secrets.
    log_info "Skipping 'postgres-credentials' secret creation (using app-secrets POSTGRES_* keys)"
    
    # Apply PostgreSQL StatefulSet (ignore warnings about SessionAffinity in headless services)
    local apply_output
    apply_output=$(kubectl apply -f k8s/01-postgres-statefulset.yaml 2>&1)
    local apply_exit_code=$?
    
    # Check if there are real errors (not just warnings)
    if [ $apply_exit_code -ne 0 ]; then
        # Check if it's just a warning about SessionAffinity (which is harmless for headless services)
        if echo "$apply_output" | grep -qi "SessionAffinity.*ignored.*headless"; then
            log_warn "Warning about SessionAffinity in headless service (this is harmless, continuing...)"
        else
            log_error "Failed to apply PostgreSQL StatefulSet:"
            echo "$apply_output" >&2
            exit 1
        fi
    fi
    
    log_info "Waiting for PostgreSQL to be ready..."
    log_info "This may take 1-2 minutes (initializing database)..."
    
    local max_wait=300  # 5 minutes
    local elapsed=0
    local check_interval=5
    local postgres_ready=false
    
    while [ $elapsed -lt $max_wait ]; do
        # Check if PostgreSQL pod is ready
        local pod_status=$(kubectl get pods -l app=postgres -n finans-asistan --no-headers -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
        local pod_ready=$(kubectl get pods -l app=postgres -n finans-asistan --no-headers -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
        
        if [ "$pod_ready" = "True" ] && [ "$pod_status" = "Running" ]; then
            postgres_ready=true
            break
        fi
        
        # Show progress
        printf "\r  Checking pod status... (%ds elapsed)" "$elapsed"
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    printf "\r"  # Clear progress line
    
    if [ "$postgres_ready" = true ]; then
        log_success "PostgreSQL is ready"
    else
        # Final check with kubectl wait
        if kubectl wait --for=condition=ready pod -l app=postgres -n finans-asistan --timeout=30s 2>/dev/null; then
            log_success "PostgreSQL is ready"
        else
            log_warn "PostgreSQL may take longer to start. Checking pod status..."
            kubectl get pods -l app=postgres -n finans-asistan 2>&1
        log_error "PostgreSQL failed to start"
        exit 1
        fi
    fi
    
    # Recovery mode: S3'ten restore
    if [ "$RECOVERY_MODE" = true ]; then
        log_info "Recovery mode: Restoring from S3..."
        restore_postgres_from_s3 || log_warn "PostgreSQL restore failed, continuing with fresh database"
    else
        log_info "Fresh install: Initializing database schema..."
        init_postgres_schema || log_warn "Schema initialization failed"
    fi
    
    log_success "PostgreSQL deployed"
    
}

# Restore PostgreSQL from S3
restore_postgres_from_s3() {
    log_info "Restoring PostgreSQL from S3..."
    
    if [ -z "${S3_BUCKET:-}" ]; then
        log_warn "S3_BUCKET not set, skipping restore"
        return 1
    fi
    
    # WAL-G restore komutu (PostgreSQL pod içinde çalıştırılacak)
    kubectl exec -n finans-asistan statefulset/postgres -- wal-g backup-fetch LATEST /var/lib/postgresql/data/pgdata || {
        log_warn "S3 restore failed, using fresh database"
        return 1
    }
    
    log_success "PostgreSQL restored from S3"
}

# Initialize PostgreSQL schema
init_postgres_schema() {
    log_info "Initializing PostgreSQL schema..."
    
    # Schema dosyasını bul (önce local, sonra S3'ten indir)
    INIT_SQL_PATH=""
    
    if [ -f "bootstrap/init.sql" ]; then
        INIT_SQL_PATH="bootstrap/init.sql"
    elif [ -f "FinansAsistan/bootstrap/init.sql" ]; then
        INIT_SQL_PATH="FinansAsistan/bootstrap/init.sql"
    elif [ -n "${S3_BUCKET:-}" ] && check_aws_credentials; then
        # S3'ten indir
        log_info "Downloading init.sql from S3..."
        mkdir -p bootstrap
        if aws s3 cp "s3://${S3_BUCKET}/bootstrap/init.sql" bootstrap/init.sql 2>/dev/null; then
            INIT_SQL_PATH="bootstrap/init.sql"
            log_success "init.sql downloaded from S3"
        fi
    fi
    
    # Schema dosyası varsa uygula
    if [ -n "$INIT_SQL_PATH" ] && [ -f "$INIT_SQL_PATH" ]; then
        # Get credentials from app-secrets (preferred) or env fallback
        if kubectl get secret app-secrets -n finans-asistan >/dev/null 2>&1; then
            db_user=$(kubectl get secret app-secrets -n finans-asistan -o jsonpath='{.data.POSTGRES_USER}' 2>/dev/null | base64 -d || echo "")
            db_name=$(kubectl get secret app-secrets -n finans-asistan -o jsonpath='{.data.POSTGRES_DB}' 2>/dev/null | base64 -d || echo "")
        fi
        if [ -z "$db_user" ]; then 
            db_user="$POSTGRES_USER"
            if [ -z "$db_user" ]; then
                echo "Error: POSTGRES_USER environment variable must be set"
                exit 1
            fi
        fi
        if [ -z "$db_name" ]; then 
            db_name="$POSTGRES_DB"
            if [ -z "$db_name" ]; then
                echo "Error: POSTGRES_DB environment variable must be set"
                exit 1
            fi
        fi
        
        kubectl exec -n finans-asistan statefulset/postgres -- psql -U "$db_user" -d "$db_name" -f /docker-entrypoint-initdb.d/init.sql 2>/dev/null || {
            # init.sql'i pod'a kopyala ve çalıştır
            kubectl cp "$INIT_SQL_PATH" finans-asistan/postgres-0:/tmp/init.sql 2>/dev/null || return 1
            kubectl exec -n finans-asistan statefulset/postgres -- psql -U "$db_user" -d "$db_name" -f /tmp/init.sql || {
                log_warn "Schema initialization failed"
                return 1
            }
        }
        log_success "PostgreSQL schema initialized"
    else
        log_warn "init.sql not found, skipping schema initialization"
    fi
}

# Deploy Kafka
deploy_kafka() {
    log_info "Deploying Kafka..."
    
    # Ensure Strimzi installed and CRDs ready (idempotent)
    kubectl apply -f "https://strimzi.io/install/latest?namespace=finans-asistan" -n finans-asistan >/dev/null 2>&1 || true
    for crd in "kafkas.kafka.strimzi.io" "kafkatopics.kafka.strimzi.io" "kafkausers.kafka.strimzi.io" "kafkanodepools.kafka.strimzi.io"; do
        kubectl wait --for=condition=Established "crd/${crd}" --timeout=120s >/dev/null 2>&1 || true
    done
    
    # Get active worker node count for Kafka replicas
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | grep -v "master\|control-plane" | wc -l | tr -d ' ')
    if [ -z "$node_count" ] || [ "$node_count" -eq 0 ]; then
        node_count=1
    fi
    # Kafka replicas should be at least node_count
    local kafka_controller_replicas=$node_count
    local kafka_broker_replicas=$node_count
    # For single node: use 1 controller (no quorum needed)
    # For multiple nodes: use minimum 3 controllers for KRaft quorum
    if [ "$node_count" -eq 1 ]; then
        kafka_controller_replicas=1  # Single node: no quorum needed
    else
        # Multiple nodes: ensure odd number and minimum 3 for quorum
        if [ $((kafka_controller_replicas % 2)) -eq 0 ]; then
            kafka_controller_replicas=$((kafka_controller_replicas + 1))
        fi
        if [ $kafka_controller_replicas -lt 3 ]; then
            kafka_controller_replicas=3  # Minimum 3 for KRaft quorum
        fi
    fi
    
    # Apply Kafka cluster
    kubectl apply -f k8s/02-kafka-cluster.yaml || true
    
    # Apply Kafka nodepools with updated replicas
    if [ -f k8s/02a-kafka-nodepools.yaml ]; then
        # Create temp file with updated replicas
        local temp_nodepools=$(mktemp)
        sed "s/replicas: 1/replicas: $kafka_controller_replicas/" k8s/02a-kafka-nodepools.yaml | \
            sed "s/replicas: 1/replicas: $kafka_broker_replicas/" > "$temp_nodepools" || true
        kubectl apply -f "$temp_nodepools" || kubectl apply -f k8s/02a-kafka-nodepools.yaml || true
        rm -f "$temp_nodepools"
        
        log_info "Kafka Controller replicas: $kafka_controller_replicas (ensures quorum)"
        log_info "Kafka Broker replicas: $kafka_broker_replicas (one per node)"
    fi
    
    log_info "Waiting for Kafka to be ready..."
    log_info "This may take a few minutes (Kafka cluster initialization)..."
    
    local max_wait=600  # 10 minutes
    local elapsed=0
    local check_interval=10
    local kafka_ready=false
    
    while [ $elapsed -lt $max_wait ]; do
        # Check if Kafka cluster is ready
        local kafka_status=$(kubectl get kafka kafka-cluster -n finans-asistan -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "")
        
        if [ "$kafka_status" = "True" ]; then
            kafka_ready=true
            break
        fi
        
        # Show progress
        printf "\r  Initializing cluster... (%ds elapsed)" "$elapsed"
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    printf "\r"  # Clear progress line
    
    if [ "$kafka_ready" = true ]; then
        log_success "Kafka is ready"
    else
        # Final check with kubectl wait
        if kubectl wait --for=condition=ready kafka/kafka-cluster -n finans-asistan --timeout=30s 2>/dev/null; then
            log_success "Kafka is ready"
        else
        log_warn "Kafka may take longer to start"
        fi
    fi
    
    log_info "Deploying Kafka topics..."
    kubectl apply -f k8s/03-kafka-topics.yaml || {
        log_warn "Some topics may already exist"
    }
    
    # Recovery mode: Kafka tiered storage (S3) automatically restores data
    if [ "$RECOVERY_MODE" = true ]; then
        log_info "Recovery mode: Kafka tiered storage (S3) will automatically restore topic data"
        log_info "   Kafka is configured with remote.storage.enable=true"
        log_info "   Topic data will be fetched from S3 as needed"
    fi
    
    log_success "Kafka deployed"
}

# Deploy Redis
deploy_redis() {
    log_info "Deploying Redis..."
    
    # Apply Redis manifest; tolerate immutable PVC spec errors for existing claims
    local apply_output
    if ! apply_output=$(kubectl apply -f k8s/10-redis.yaml 2>&1); then
        if echo "$apply_output" | grep -qi "spec is immutable after creation"; then
            log_warn "Redis PVC spec is immutable (already created). Continuing with existing claim."
        else
            log_warn "kubectl apply for Redis returned non-zero exit code"
            log_warn "Output: $apply_output"
        fi
    fi
    
    log_info "Waiting for Redis to be ready..."
    log_info "This usually takes 10-30 seconds..."
    
    local max_wait=300  # 5 minutes
    local elapsed=0
    local check_interval=5
    local redis_ready=false
    
    while [ $elapsed -lt $max_wait ]; do
        # Check if Redis pod is ready
        local redis_json
        redis_json=$(kubectl get pods -l app=redis -n finans-asistan -o json 2>/dev/null || echo "")
        local pod_status=""
        local pod_ready=""
        if [ -n "$redis_json" ]; then
            pod_status=$(echo "$redis_json" | jq -r '.items[0].status.phase // empty' 2>/dev/null || echo "")
            pod_ready=$(echo "$redis_json" | jq -r '.items[0].status.conditions[]?|select(.type=="Ready")|.status' 2>/dev/null | head -n1 || echo "")
        fi
        
        if [ "$pod_ready" = "True" ] && [ "$pod_status" = "Running" ]; then
            redis_ready=true
            break
        fi
        
        # Show progress
        printf "\r  Starting... (%ds elapsed)" "$elapsed"
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    printf "\r"  # Clear progress line
    
    if [ "$redis_ready" = true ]; then
        log_success "Redis is ready"
    else
        # Final check with kubectl wait
        if kubectl wait --for=condition=ready pod -l app=redis -n finans-asistan --timeout=30s 2>/dev/null; then
            log_success "Redis is ready"
        else
            log_warn "Redis may take longer to start"
            kubectl get pods -l app=redis -n finans-asistan 2>&1
        log_error "Redis failed to start"
        exit 1
        fi
    fi
    
    # Recovery mode: Restore Redis from S3 if backup exists
    if [ "$RECOVERY_MODE" = true ]; then
        log_info "Recovery mode: Attempting to restore Redis from S3..."
        restore_redis_from_s3 || log_warn "Redis restore failed or no backup found, continuing with fresh Redis"
    fi
    
    # Deploy Redis backup CronJob
    log_info "Deploying Redis backup CronJob..."
    if [ -f "k8s/10a-redis-backup-cronjob.yaml" ]; then
        kubectl apply -f k8s/10a-redis-backup-cronjob.yaml >/dev/null 2>&1 || log_warn "Redis backup CronJob deployment failed"
        if [ $? -eq 0 ]; then
            log_success "Redis backup CronJob deployed (runs every 15 minutes)"
        fi
    else
        log_warn "Redis backup CronJob manifest not found, skipping..."
    fi
    
    log_success "Redis deployed"
}

# Restore Redis from S3
restore_redis_from_s3() {
    log_info "Restoring Redis from S3..."
    
    if [ -z "${S3_BUCKET:-}" ] || ! check_aws_credentials; then
        log_warn "S3_BUCKET not set or AWS credentials missing, skipping Redis restore"
        return 1
    fi
    
    # Check if Redis backup exists in S3 (redis/backups/)
    if ! aws s3 ls "s3://${S3_BUCKET}/redis/backups/" &> /dev/null; then
        log_info "No Redis backup found in S3, skipping restore"
        return 1
    fi
    
    # Find latest Redis backup (appendonly.aof file)
    LATEST_BACKUP=$(aws s3 ls "s3://${S3_BUCKET}/redis/backups/" --recursive | grep "appendonly.aof" | sort | tail -n 1 | awk '{print $4}' || echo "")
    
    if [ -z "$LATEST_BACKUP" ]; then
        log_info "No Redis backup file found in S3, skipping restore"
        return 1
    fi
    
    log_info "Found Redis backup: $LATEST_BACKUP"
    
    # Wait for Redis pod to be fully ready
    sleep 5
    
    # Download backup to Redis pod
    TEMP_BACKUP="/tmp/redis-restore.aof"
    if aws s3 cp "s3://${S3_BUCKET}/${LATEST_BACKUP}" "$TEMP_BACKUP" 2>/dev/null; then
        # Copy backup file to Redis pod
        REDIS_POD=$(kubectl get pods -l app=redis -n finans-asistan -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
        if [ -n "$REDIS_POD" ]; then
            # Stop Redis writes temporarily
            kubectl exec -n finans-asistan "$REDIS_POD" -- redis-cli CONFIG SET appendonly no 2>/dev/null || true
            
            # Copy backup file to Redis data directory
            kubectl cp "$TEMP_BACKUP" "finans-asistan/${REDIS_POD}:/data/appendonly.aof" 2>/dev/null || {
                log_warn "Failed to copy Redis backup to pod"
                rm -f "$TEMP_BACKUP"
                return 1
            }
            
            # Restart Redis to load the backup
            log_info "Restarting Redis to load backup..."
            kubectl delete pod -n finans-asistan "$REDIS_POD" 2>/dev/null || true
            
            # Wait for Redis to restart
            sleep 10
            local max_wait=60
            local elapsed=0
            while [ $elapsed -lt $max_wait ]; do
                if kubectl wait --for=condition=ready pod -l app=redis -n finans-asistan --timeout=10s 2>/dev/null; then
                    log_success "Redis restored from S3 backup"
                    rm -f "$TEMP_BACKUP"
                    return 0
                fi
                sleep 5
                elapsed=$((elapsed + 5))
            done
            
            log_warn "Redis restore completed but pod may not be ready yet"
            rm -f "$TEMP_BACKUP"
            return 0
        else
            log_warn "Redis pod not found, cannot restore"
            rm -f "$TEMP_BACKUP"
            return 1
        fi
    else
        log_warn "Failed to download Redis backup from S3"
        return 1
    fi
}

# Deploy applications
deploy_applications() {
    log_info "Deploying applications..."
    
    # Get ECR registry URL (use exported value from create_ecr_secret if available, otherwise calculate)
    local ecr_registry="${ECR_REGISTRY:-}"
    if [ -z "$ecr_registry" ]; then
        ecr_registry=$(get_ecr_registry)
    fi
    
    # If ECR registry is available, replace placeholders in deployment files
    if [ -n "$ecr_registry" ]; then
        log_info "Using ECR registry: ${ecr_registry}"
        
        # Check if images exist in ECR repositories
        log_info "Checking if images exist in ECR repositories..."
        log_info "Using ECR registry: ${ecr_registry}"
        
        # Verify we're using the correct ECR registry (same as GitHub workflow)
        local expected_registry_from_env=""
        if [ -n "${AWS_ACCOUNT_ID:-}" ] && [ -n "${AWS_REGION:-}" ]; then
            expected_registry_from_env="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
            if [ "$ecr_registry" != "$expected_registry_from_env" ]; then
                log_warn "⚠️  ECR registry mismatch!"
                log_warn "   Environment AWS_ACCOUNT_ID would give: ${expected_registry_from_env}"
                log_warn "   But using: ${ecr_registry}"
                log_warn "   Make sure AWS_ACCOUNT_ID environment variable matches GitHub Secrets AWS_ACCOUNT_ID"
            fi
        fi
        
        local backend_repo="finans-asistan-backend-production"
        local frontend_repo="finans-asistan-frontend-production"
        local event_repo="finans-asistan-event-processor-production"
        
        local backend_exists=false
        local frontend_exists=false
        local event_exists=false
        
        if command -v aws &> /dev/null && [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
            local aws_region="${AWS_REGION:-eu-central-1}"
            
            # Check which AWS account we're authenticated as
            local current_account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
            if [ -n "$current_account_id" ]; then
                log_info "Authenticated as AWS account: $current_account_id"
                local expected_registry="${current_account_id}.dkr.ecr.${aws_region}.amazonaws.com"
                if [ "$ecr_registry" != "$expected_registry" ]; then
                    log_error "❌ ECR registry mismatch detected!"
                    log_error "   Current AWS account: $current_account_id"
                    log_error "   ECR registry being used: ${ecr_registry}"
                    log_error "   Expected registry: ${expected_registry}"
                    log_error "   This means images were pushed to a different ECR registry!"
                    log_error "   Solution: Set AWS_ACCOUNT_ID environment variable to match GitHub Secrets"
                fi
            fi
            
            if aws ecr describe-images --repository-name "$backend_repo" --region "$aws_region" --image-ids imageTag=latest --query 'imageDetails[0].imageDigest' --output text >/dev/null 2>&1; then
                backend_exists=true
                log_info "✅ Backend image found in ECR at: ${ecr_registry}/${backend_repo}:latest"
            else
                log_warn "⚠️  Backend image NOT found in ECR repository: ${ecr_registry}/${backend_repo}"
                log_warn "   Checking if repository exists in current account..."
                if aws ecr describe-repositories --repository-names "$backend_repo" --region "$aws_region" >/dev/null 2>&1; then
                    log_warn "   Repository exists but 'latest' tag not found. Checking available tags..."
                    local available_tags=$(aws ecr list-images --repository-name "$backend_repo" --region "$aws_region" --query 'imageIds[*].imageTag' --output text 2>/dev/null | head -5)
                    if [ -n "$available_tags" ]; then
                        log_warn "   Available tags: $available_tags"
                    fi
                else
                    log_error "   Repository does not exist in current AWS account!"
                fi
            fi
            
            if aws ecr describe-images --repository-name "$frontend_repo" --region "$aws_region" --image-ids imageTag=latest --query 'imageDetails[0].imageDigest' --output text >/dev/null 2>&1; then
                frontend_exists=true
                log_info "✅ Frontend image found in ECR"
            else
                log_warn "⚠️  Frontend image NOT found in ECR repository: $frontend_repo"
            fi
            
            if aws ecr describe-images --repository-name "$event_repo" --region "$aws_region" --image-ids imageTag=latest --query 'imageDetails[0].imageDigest' --output text >/dev/null 2>&1; then
                event_exists=true
                log_info "✅ Event-processor image found in ECR"
            else
                log_warn "⚠️  Event-processor image NOT found in ECR repository: $event_repo"
            fi
            
            if [ "$backend_exists" = false ] || [ "$frontend_exists" = false ] || [ "$event_exists" = false ]; then
                log_error "Some images are missing in ECR repositories!"
                log_error "Please run GitHub Actions workflow to build and push images, or build them manually."
                log_error "Repository names:"
                [ "$backend_exists" = false ] && log_error "  - $backend_repo"
                [ "$frontend_exists" = false ] && log_error "  - $frontend_repo"
                [ "$event_exists" = false ] && log_error "  - $event_repo"
            fi
        else
            log_warn "AWS CLI not available or credentials missing, skipping ECR image check"
        fi
        
        log_info "ECR registry available, will update deployment files per deployment in sequential version..."
    else
        log_warn "ECR registry not available, using deployment files as-is (may fail if images don't exist)"
    fi
    
    # Deploy applications sequentially, waiting for each to be ready before starting the next
    # Dependencies are based on init containers and service requirements:
    # - Backend depends on: PostgreSQL, Redis, Kafka (infrastructure services)
    # - Frontend depends on: Backend
    # - Event-Processor depends on: PostgreSQL, Redis, Kafka (infrastructure services)
    local apps=(
        "backend:04-backend-deployment.yaml:postgres,redis,kafka-cluster"
        "frontend:05-frontend-deployment.yaml:backend"
        "event-processor:11-event-processor.yaml:postgres,redis,kafka-cluster"
    )
    
    for app_info in "${apps[@]}"; do
        IFS=':' read -r app_name app_file app_depends <<< "$app_info"
        
        # Wait for dependencies to be ready before deploying
        if [ -n "$app_depends" ]; then
            log_info "Waiting for dependencies of $app_name to be ready..."
            IFS=',' read -ra deps <<< "$app_depends"
            for dep in "${deps[@]}"; do
                if [ -n "$dep" ]; then
                    log_info "  Waiting for $dep to be ready..."
                    local elapsed_dep=0
                    local check_interval_dep=5
                    local dependency_ready=false
                    
                    while [ "$dependency_ready" = false ]; do
                        # Try as StatefulSet first (for postgres, etc.)
                        local statefulset_json=$(kubectl get statefulset "$dep" -n finans-asistan -o json 2>/dev/null || echo "")
                        if [ -n "$statefulset_json" ]; then
                            local ready_replicas=$(echo "$statefulset_json" | jq -r '.status.readyReplicas // 0' 2>/dev/null || echo "0")
                            local desired_replicas=$(echo "$statefulset_json" | jq -r '.spec.replicas // 0' 2>/dev/null || echo "0")
                            if [ "$ready_replicas" -ge "$desired_replicas" ] && [ "$desired_replicas" -gt 0 ]; then
                                dependency_ready=true
                                log_info "  [OK] $dep (StatefulSet) is ready ($ready_replicas/$desired_replicas)"
                                break
                            else
                                if [ $((elapsed_dep % 15)) -eq 0 ] && [ $elapsed_dep -gt 0 ]; then
                                    log_info "  [DEBUG] $dep StatefulSet: readyReplicas=$ready_replicas, desiredReplicas=$desired_replicas"
                                fi
                            fi
                        fi
                        
                        # Try as Deployment (for redis, etc.)
                        if [ "$dependency_ready" = false ]; then
                            local deploy_json=$(kubectl get deployment "$dep" -n finans-asistan -o json 2>/dev/null || echo "")
                            if [ -n "$deploy_json" ]; then
                                local available_status=$(echo "$deploy_json" | jq -r '.status.conditions[]?|select(.type=="Available")|.status' 2>/dev/null | head -n1 || echo "False")
                                if [ "$available_status" = "True" ]; then
                                    local ready_replicas=$(echo "$deploy_json" | jq -r '.status.readyReplicas // 0' 2>/dev/null || echo "0")
                                    local desired_replicas=$(echo "$deploy_json" | jq -r '.spec.replicas // 0' 2>/dev/null || echo "0")
                                    if [ "$ready_replicas" -ge "$desired_replicas" ] && [ "$desired_replicas" -gt 0 ]; then
                                        dependency_ready=true
                                        log_info "  [OK] $dep (Deployment) is ready ($ready_replicas/$desired_replicas)"
                                        break
                                    fi
                                fi
                            fi
                        fi
                        
                        # Try as Kafka CRD (e.g., kafka-cluster)
                        if [ "$dependency_ready" = false ] && echo "$dep" | grep -q "kafka"; then
                            local kafka_json=$(kubectl get kafka "$dep" -n finans-asistan -o json 2>/dev/null || echo "")
                            if [ -n "$kafka_json" ]; then
                                local ready_status=$(echo "$kafka_json" | jq -r '.status.conditions[]?|select(.type=="Ready")|.status' 2>/dev/null | head -n1 || echo "False")
                                if [ "$ready_status" = "True" ]; then
                                    dependency_ready=true
                                    log_info "  [OK] $dep (Kafka) is ready"
                                    break
                                fi
                            fi
                        fi
                        
                        if [ "$dependency_ready" = false ]; then
                            sleep $check_interval_dep
                            elapsed_dep=$((elapsed_dep + check_interval_dep))
                            if [ $((elapsed_dep % 15)) -eq 0 ] && [ $elapsed_dep -gt 0 ]; then
                                log_info "  Still waiting for $dep... (${elapsed_dep}s elapsed)"
                            fi
                        fi
                    done
                fi
            done
        fi
        
        # Deploy this application
        log_info "Deploying $app_name ($app_file)..."
        
        local temp_file=""
        if [ -n "$ecr_registry" ]; then
            # Create temporary file with replaced placeholder
            temp_file=$(mktemp)
            sed "s|PLACEHOLDER_ECR_REGISTRY|${ecr_registry}|g" "k8s/$app_file" > "$temp_file"
            
            if ! kubectl apply -f "$temp_file"; then
                log_error "❌ Failed to apply $app_file. Stopping deployment process."
                [ -n "$temp_file" ] && rm -f "$temp_file"
                return 1
            fi
            
            # Verify image URL was updated (only if apply was successful)
            local app_image=$(kubectl get deployment "$app_name" -n finans-asistan -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
            if [ -n "$app_image" ]; then
                log_info "$app_name image: $app_image"
                if echo "$app_image" | grep -q "PLACEHOLDER_ECR_REGISTRY"; then
                    log_error "❌ $app_name image still contains PLACEHOLDER_ECR_REGISTRY! Stopping deployment process."
                    [ -n "$temp_file" ] && rm -f "$temp_file"
                    return 1
                fi
            fi
        else
            if ! kubectl apply -f "k8s/$app_file"; then
                log_error "❌ Failed to apply $app_file. Stopping deployment process."
                return 1
            fi
        fi
        
        # Cleanup temp file if created
        [ -n "$temp_file" ] && rm -f "$temp_file"
        
        # Wait for this deployment to be ready before proceeding to the next (no timeout - will wait indefinitely)
        log_info "Waiting for $app_name deployment to be ready (no timeout, will wait until ready)..."
        local elapsed=0
        local check_interval=5
        local deployment_ready=false
        
        while [ "$deployment_ready" = false ]; do
            local deploy_json=$(kubectl get deployment "$app_name" -n finans-asistan -o json 2>/dev/null || echo "")
            if [ -n "$deploy_json" ]; then
                local available_status=$(echo "$deploy_json" | jq -r '.status.conditions[]?|select(.type=="Available")|.status' 2>/dev/null | head -n1 || echo "False")
                if [ "$available_status" = "True" ]; then
                    local ready_replicas=$(echo "$deploy_json" | jq -r '.status.readyReplicas // 0' 2>/dev/null || echo "0")
                    local desired_replicas=$(echo "$deploy_json" | jq -r '.spec.replicas // 0' 2>/dev/null || echo "0")
                    if [ "$ready_replicas" -ge "$desired_replicas" ] && [ "$desired_replicas" -gt 0 ]; then
                        deployment_ready=true
                        log_success "$app_name is ready ($ready_replicas/$desired_replicas)"
                        break
                    fi
                fi
            fi
            
            if [ "$deployment_ready" = false ]; then
                sleep $check_interval
                elapsed=$((elapsed + check_interval))
                if [ $((elapsed % 15)) -eq 0 ] && [ $elapsed -gt 0 ]; then
                    log_info "  Still waiting for $app_name... (${elapsed}s elapsed)"
                fi
            fi
        done
        
        if [ "$deployment_ready" = false ]; then
            log_error "❌ $app_name deployment failed to become ready. Stopping deployment process."
            return 1
        fi
    done
    
    # Show final pod status
    log_info "Final pod status:"
    kubectl get pods -n finans-asistan -l 'app in (backend,frontend,event-processor)' 2>&1 || true
    
    log_success "All applications deployment completed"
}

# Update HPA minReplicas based on node count (ensure at least 1 pod per node)
update_hpa_min_replicas() {
    log_info "Updating HPA minReplicas based on node count..."
    
    # Get total node count (leader + worker nodes) for distributed services
    # This ensures at least 1 pod per node (leader node + all worker nodes)
    local node_count=$(kubectl get nodes --no-headers 2>/dev/null | wc -l | tr -d ' ')
    
    # If node count is 0, use 1 as minimum
    if [ -z "$node_count" ] || [ "$node_count" -eq 0 ]; then
        node_count=1
    fi
    
    log_info "Total nodes (leader + workers): $node_count"
    
    # Update worker node services HPA minReplicas to match worker node count (ensures at least 1 pod per worker node)
    # Leader node services (PostgreSQL, Redis, Prometheus, Grafana, AlertManager, Exporters) stay at minReplicas=1, maxReplicas=1
    # Only worker node services (Backend, Frontend, Event Processor, Kafka) scale horizontally
    
    # Backend HPA (worker node service)
    kubectl patch hpa backend-hpa -n finans-asistan -p "{\"spec\":{\"minReplicas\":$node_count}}" >/dev/null 2>&1 || {
        log_warn "Failed to update backend-hpa minReplicas"
    }
    
    # Frontend HPA (worker node service)
    kubectl patch hpa frontend-hpa -n finans-asistan -p "{\"spec\":{\"minReplicas\":$node_count}}" >/dev/null 2>&1 || {
        log_warn "Failed to update frontend-hpa minReplicas"
    }
    
    # Event Processor HPA (worker node service)
    kubectl patch hpa event-processor-hpa -n finans-asistan -p "{\"spec\":{\"minReplicas\":$node_count}}" >/dev/null 2>&1 || {
        log_warn "Failed to update event-processor-hpa minReplicas"
    }
    
    # Leader node services keep minReplicas=1, maxReplicas=1 (VPA scales vertically)
    # PostgreSQL, Redis, Prometheus, Grafana, AlertManager, Exporters, ArgoCD - not updated here
    
    log_success "Distributed services HPA minReplicas updated to $node_count (ensures at least 1 pod per node - leader + all workers)"
    log_info "Non-distributed services (PostgreSQL, Redis, Prometheus, ArgoCD Application Controller) stay at minReplicas=1, maxReplicas=1 (VPA scales vertically on leader node only)"
}

# Deploy autoscaler
deploy_autoscaler() {
    log_info "Deploying autoscalers..."
    
    # Deploy HPA for all services (backend, frontend, event-processor, postgres, redis)
    log_info "Deploying HPA for all services..."
        kubectl apply -f k8s/06-hpa.yaml >/dev/null 2>&1
        
    # Deploy Monitoring HPA (Prometheus, AlertManager, Grafana, Exporters)
    log_info "Deploying Monitoring HPA..."
    if [ -f "k8s/06c-monitoring-hpa.yaml" ]; then
        kubectl apply -f k8s/06c-monitoring-hpa.yaml >/dev/null 2>&1
        log_success "Monitoring HPA deployed"
    else
        log_warn "Monitoring HPA manifest not found, skipping..."
    fi
        
    # Remove any existing ScaledObject (KEDA no longer used)
        kubectl delete scaledobject event-processor-scaler -n finans-asistan --ignore-not-found >/dev/null 2>&1
    
    log_success "HPA deployed for all services"
    
    # Update HPA minReplicas based on node count (ensure at least 1 pod per node)
    update_hpa_min_replicas
    
    # Deploy Kafka Auto-Scaler (CronJob) - KafkaNodePool does not support HPA
    log_info "Deploying Kafka Auto-Scaler (CronJob)..."
    if [ -f "k8s/06b-kafka-autoscaler.yaml" ]; then
        kubectl apply -f k8s/06b-kafka-autoscaler.yaml >/dev/null 2>&1
        log_success "Kafka Auto-Scaler deployed (runs every 5 minutes)"
    else
        log_warn "Kafka Auto-Scaler manifest not found, skipping..."
    fi
    
    # Cluster Autoscaler removed - not needed for Docker Desktop compatibility
    # deploy_cluster_autoscaler
    
    # Deploy VPA (Vertical Pod Autoscaler) for leader and distributed services
    log_info "Deploying VPA for all services..."
    deploy_vpa
}

# Deploy VPA (Vertical Pod Autoscaler)
deploy_vpa() {
    log_info "Deploying Vertical Pod Autoscaler (VPA)..."
    
    # Check if VPA is installed
    if ! kubectl get crd verticalpodautoscalers.autoscaling.k8s.io >/dev/null 2>&1; then
        log_warn "VPA CRD not found. VPA components may not be installed."
        log_info "To install VPA, run: kubectl apply -f https://github.com/kubernetes/autoscaler/releases/download/vertical-pod-autoscaler-1.0.4/vpa-release.yaml"
        log_warn "Skipping VPA deployment. Install VPA components first."
        return
    fi
    
    # Deploy VPA for leader node services (PostgreSQL, Redis, Prometheus, Grafana, AlertManager, Exporters)
    if [ -f "k8s/06e-vpa-leader-services.yaml" ]; then
        kubectl apply -f k8s/06e-vpa-leader-services.yaml >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_success "VPA deployed for leader node services"
        else
            log_warn "VPA deployment for leader services encountered issues"
        fi
    else
        log_warn "VPA leader services manifest not found, skipping..."
    fi
    
    # Deploy VPA for ArgoCD services
    if [ -f "k8s/06f-vpa-argocd-services.yaml" ]; then
        kubectl apply -f k8s/06f-vpa-argocd-services.yaml >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_success "VPA deployed for ArgoCD services"
        else
            log_warn "VPA deployment for ArgoCD services encountered issues"
        fi
    else
        log_warn "VPA ArgoCD services manifest not found, skipping..."
    fi
    
    # Deploy VPA for distributed services (Backend, Frontend, Event Processor)
    if [ -f "k8s/06g-vpa-distributed-services.yaml" ]; then
        kubectl apply -f k8s/06g-vpa-distributed-services.yaml >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            log_success "VPA deployed for distributed services"
        else
            log_warn "VPA deployment for distributed services encountered issues"
        fi
    else
        log_warn "VPA distributed services manifest not found, skipping..."
    fi
}

# Deploy Cluster Autoscaler (EC2 node auto-scaling)
deploy_cluster_autoscaler() {
    log_info "Deploying Cluster Autoscaler (EC2 node auto-scaling)..."
    
    local autoscaler_file="k8s/07-cluster-autoscaler.yaml"
    if [ ! -f "$autoscaler_file" ]; then
        log_warn "Cluster Autoscaler manifest not found, skipping..."
        return
    fi
    
    # Check if AWS credentials are available for Cluster Autoscaler
    local aws_access_key="${AWS_ACCESS_KEY_ID}"
    local aws_secret_key="${AWS_SECRET_ACCESS_KEY}"
    local aws_region="${AWS_REGION:-eu-central-1}"
    
    if [ -z "$aws_access_key" ] || [ -z "$aws_secret_key" ]; then
        log_warn "AWS credentials not found. Cluster Autoscaler requires AWS credentials for EC2 auto-scaling."
        log_info "Cluster Autoscaler will be skipped. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to enable."
        return
    fi
    
    log_info "Creating Cluster Autoscaler secret with AWS credentials..."
    
    # Create or update secret with AWS credentials
    kubectl create secret generic cluster-autoscaler-aws-credentials \
        --from-literal=aws-access-key-id="$aws_access_key" \
        --from-literal=aws-secret-access-key="$aws_secret_key" \
        --namespace=kube-system \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
    
    # Update Cluster Autoscaler deployment with AWS region
    local temp_autoscaler_file=$(mktemp)
    sed "s/CHANGE_ME//g; s/value: \"eu-central-1\"/value: \"$aws_region\"/g" "$autoscaler_file" > "$temp_autoscaler_file"
    
    # Remove the secret section from deployment YAML (already created separately)
    sed -i '/^apiVersion: v1$/,/^---$/ {
        /^kind: Secret$/,/^---$/ d
    }' "$temp_autoscaler_file" 2>/dev/null || \
    sed -e '/^apiVersion: v1$/,/^---$/{
        /^kind: Secret$/,/^---$/d
    }' "$temp_autoscaler_file" > "${temp_autoscaler_file}.tmp" && mv "${temp_autoscaler_file}.tmp" "$temp_autoscaler_file"
    
    # Apply Cluster Autoscaler
    if kubectl apply -f "$temp_autoscaler_file" >/dev/null 2>&1; then
        log_success "Cluster Autoscaler deployed"
        log_info "Cluster Autoscaler will scale EC2 nodes based on pod resource requests"
        log_info "Ensure your AWS Auto Scaling Groups are tagged with: k8s.io/cluster-autoscaler/enabled"
    else
        log_warn "Cluster Autoscaler deployment failed"
    fi
    
    # Cleanup temp file
    rm -f "$temp_autoscaler_file"
}

# Deploy monitoring
deploy_monitoring() {
    log_info "Deploying monitoring..."
    
    # Prometheus ve Grafana için manifest dosyaları varsa deploy et
    if [ -f "k8s/09-monitoring.yaml" ]; then
        kubectl apply -f k8s/09-monitoring.yaml || log_warn "Monitoring deployment failed"
        
        # Update AlertManager ConfigMap with email credentials from .env or app-secrets
        log_info "Updating AlertManager ConfigMap with email credentials..."
        
        # Try to get email credentials from environment variables first (.env file)
        local email_user="${EMAIL_USER:-}"
        local email_pass="${EMAIL_PASS:-}"
        
        # If not found in environment, try app-secrets
        if [ -z "$email_user" ] || [ -z "$email_pass" ]; then
            if kubectl get secret app-secrets -n finans-asistan >/dev/null 2>&1; then
                email_user=$(kubectl get secret app-secrets -n finans-asistan -o jsonpath='{.data.EMAIL_USER}' 2>/dev/null | base64 -d || echo "")
                email_pass=$(kubectl get secret app-secrets -n finans-asistan -o jsonpath='{.data.EMAIL_PASS}' 2>/dev/null | base64 -d || echo "")
            fi
        fi
        
        if [ -n "$email_user" ] && [ -n "$email_pass" ]; then
                # Get current AlertManager ConfigMap
                local alertmanager_config=$(kubectl get configmap alertmanager-config -n finans-asistan -o jsonpath='{.data.alertmanager\.yml}' 2>/dev/null || echo "")
                
                if [ -n "$alertmanager_config" ]; then
                    # Replace placeholder values with actual credentials
                    local updated_config=$(echo "$alertmanager_config" | \
                        sed "s|smtp_from: 'hello@finansasistan.com'|smtp_from: '${email_user}'|g" | \
                        sed "s|smtp_auth_username: 'CHANGE_ME_IN_BOOTSTRAP'|smtp_auth_username: '${email_user}'|g" | \
                        sed "s|smtp_auth_password: 'CHANGE_ME_IN_BOOTSTRAP'|smtp_auth_password: '${email_pass}'|g")
                    
                    # Update ConfigMap
                    echo "$updated_config" | kubectl create configmap alertmanager-config \
                        --from-file=alertmanager.yml=/dev/stdin \
                        -n finans-asistan \
                        --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
                    
                    if [ $? -eq 0 ]; then
                        log_success "AlertManager ConfigMap updated with email credentials"
                        
                        # Restart AlertManager to pick up new config
                        log_info "Restarting AlertManager to apply new configuration..."
                        kubectl rollout restart deployment alertmanager -n finans-asistan >/dev/null 2>&1 || true
                    else
                        log_warn "Failed to update AlertManager ConfigMap"
                    fi
                else
                    log_warn "Could not retrieve AlertManager ConfigMap"
                fi
            else
                log_warn "EMAIL_USER or EMAIL_PASS not found in app-secrets, AlertManager email alerts will be disabled"
            fi
        else
            log_warn "app-secrets not found, AlertManager email alerts will be disabled"
        fi
    else
        log_warn "Monitoring manifest not found, skipping..."
    fi
    
    # Recovery mode: Prometheus metrics are ephemeral (not restored)
    if [ "$RECOVERY_MODE" = true ]; then
        log_info "Recovery mode: Prometheus metrics are ephemeral and will start fresh"
        log_info "   Historical metrics are not restored (this is expected behavior)"
        log_info "   Grafana dashboards and alerts will be restored from manifests"
    fi
    
    log_success "Monitoring deployed"
}

# Get ECR registry URL (shared function)
get_ecr_registry() {
    local ecr_registry=""
    
    # Try environment variables first
    if [ -n "${AWS_ACCOUNT_ID:-}" ] && [ -n "${AWS_REGION:-}" ]; then
        ecr_registry="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    # Fallback to AWS CLI
    elif command -v aws &> /dev/null && [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        local aws_region="${AWS_REGION:-eu-central-1}"
        local aws_account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
        if [ -n "$aws_account_id" ]; then
            ecr_registry="${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com"
        fi
    fi
    
    echo "$ecr_registry"
}

# Create ECR image pull secret
create_ecr_secret() {
    log_info "Creating ECR image pull secret..."
    
    if ! command -v aws &> /dev/null; then
        log_warn "AWS CLI not found, skipping ECR secret creation"
        return 0
    fi
    
    # Check if AWS credentials are available
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        log_warn "AWS credentials not found in environment variables"
        log_warn "Make sure .env file is loaded or AWS credentials are set"
        return 0
    fi
    
    if [ -z "${AWS_REGION:-}" ]; then
        AWS_REGION="eu-central-1"
    fi
    
    # Get ECR registry URL using shared function
    ECR_REGISTRY=$(get_ecr_registry)
    
    if [ -z "$ECR_REGISTRY" ]; then
        log_warn "Could not determine ECR registry URL, skipping ECR secret creation"
        log_warn "Set AWS_ACCOUNT_ID and AWS_REGION environment variables or fix AWS credentials"
        return 0
    fi
    
    log_info "ECR Registry: ${ECR_REGISTRY}"
    
    # Export for use in deploy_applications
    export ECR_REGISTRY
    
    # Get ECR login password (this generates a fresh token each time, valid for 12 hours)
    log_info "Getting ECR login password (fresh token)..."
    
    # Temporarily disable AWS credentials/config files to force use of environment variables
    # This is needed when credentials file is broken but environment variables are set
    ORIGINAL_AWS_SHARED_CREDENTIALS_FILE="${AWS_SHARED_CREDENTIALS_FILE:-}"
    ORIGINAL_AWS_CONFIG_FILE="${AWS_CONFIG_FILE:-}"
    ORIGINAL_AWS_PROFILE="${AWS_PROFILE:-}"
    
    # Set to non-existent files to force environment variable usage
    export AWS_SHARED_CREDENTIALS_FILE="/tmp/aws-credentials-nonexistent-$$"
    export AWS_CONFIG_FILE="/tmp/aws-config-nonexistent-$$"
    unset AWS_PROFILE
    
    ECR_PASSWORD=$(aws ecr get-login-password --region ${AWS_REGION} 2>/dev/null || echo "")
    
    # Restore original values
    if [ -n "$ORIGINAL_AWS_SHARED_CREDENTIALS_FILE" ]; then
        export AWS_SHARED_CREDENTIALS_FILE="$ORIGINAL_AWS_SHARED_CREDENTIALS_FILE"
    else
        unset AWS_SHARED_CREDENTIALS_FILE
    fi
    
    if [ -n "$ORIGINAL_AWS_CONFIG_FILE" ]; then
        export AWS_CONFIG_FILE="$ORIGINAL_AWS_CONFIG_FILE"
    else
        unset AWS_CONFIG_FILE
    fi
    
    if [ -n "$ORIGINAL_AWS_PROFILE" ]; then
        export AWS_PROFILE="$ORIGINAL_AWS_PROFILE"
    else
        unset AWS_PROFILE
    fi
    
    if [ -z "$ECR_PASSWORD" ] || [ ${#ECR_PASSWORD} -lt 100 ]; then
        log_warn "Could not get ECR password or password seems invalid, skipping ECR secret creation"
        return 0
    fi
    
    # Create namespace if it doesn't exist
    kubectl create namespace finans-asistan --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
    
    # Delete existing ECR secret if it exists (to force recreation with fresh token)
    log_info "Removing existing ECR secret (if any) to create fresh one..."
    kubectl delete secret ecr-registry-secret -n finans-asistan --ignore-not-found >/dev/null 2>&1
    
    # Create new ECR registry secret with fresh token
    if ! kubectl create secret docker-registry ecr-registry-secret \
      --docker-server=${ECR_REGISTRY} \
      --docker-username=AWS \
      --docker-password=${ECR_PASSWORD} \
      --namespace=finans-asistan >/dev/null 2>&1; then
        # If create fails (secret might still exist), try apply as fallback
        log_info "Create failed, trying apply instead..."
    kubectl create secret docker-registry ecr-registry-secret \
      --docker-server=${ECR_REGISTRY} \
      --docker-username=AWS \
      --docker-password=${ECR_PASSWORD} \
      --namespace=finans-asistan \
      --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
    fi
    
    if [ $? -eq 0 ]; then
    log_success "ECR image pull secret created/updated"
        log_info "Token is valid for 12 hours"
        log_info "Secret docker-server: ${ECR_REGISTRY}"
        
        # Verify secret was created correctly (wait a moment for it to be available)
        sleep 2
        if kubectl get secret ecr-registry-secret -n finans-asistan >/dev/null 2>&1; then
            log_info "ECR secret verified in namespace 'finans-asistan'"
            
            # Add secret to default service account (for Docker Desktop Kubernetes compatibility)
            log_info "Adding ECR secret to default service account..."
            if kubectl patch serviceaccount default -n finans-asistan -p '{"imagePullSecrets":[{"name":"ecr-registry-secret"}]}' >/dev/null 2>&1; then
                log_info "ECR secret added to default service account"
            else
                log_warn "Failed to add ECR secret to default service account (may not be needed)"
            fi
        else
            log_warn "ECR secret verification failed (may need a moment to propagate)"
            # Try once more after a short wait
            sleep 3
            if kubectl get secret ecr-registry-secret -n finans-asistan >/dev/null 2>&1; then
                log_info "ECR secret verified on second attempt"
                # Add to service account on second attempt too
                kubectl patch serviceaccount default -n finans-asistan -p '{"imagePullSecrets":[{"name":"ecr-registry-secret"}]}' >/dev/null 2>&1 || true
            else
                log_warn "ECR secret still not found - check manually with: kubectl get secret ecr-registry-secret -n finans-asistan"
            fi
        fi
        
        # Only restart deployments if they already exist (not first-time deployment)
        # If this is first-time deployment, pods will use the secret automatically
        log_info "Checking if deployments already exist..."
        EXISTING_DEPLOYMENTS=$(kubectl get deployments -n finans-asistan -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        
        if [ -n "$EXISTING_DEPLOYMENTS" ]; then
            NEEDS_RESTART=false
            for deployment in backend frontend event-processor; do
                if echo "$EXISTING_DEPLOYMENTS" | grep -q "$deployment"; then
                    NEEDS_RESTART=true
                    log_info "Restarting existing deployment: $deployment"
                    kubectl rollout restart deployment "$deployment" -n finans-asistan >/dev/null 2>&1
                    if [ $? -eq 0 ]; then
                        log_info "Restarted deployment: $deployment"
                    fi
                fi
            done
            if [ "$NEEDS_RESTART" = false ]; then
                log_info "No existing deployments found, new pods will use the secret automatically"
            fi
        else
            log_info "No existing deployments found, new pods will use the secret automatically"
        fi
    else
        log_warn "Failed to create ECR secret"
        return 0
    fi
}

# Deploy ArgoCD
deploy_argocd() {
    log_info "Deploying ArgoCD in finans-asistan namespace..."
    
    # Check if ArgoCD is already installed in finans-asistan namespace
    if kubectl get deployment argocd-server -n finans-asistan &>/dev/null; then
        log_success "ArgoCD is already installed in finans-asistan namespace!"
        return 0
    fi
    
    # Check if ArgoCD is incorrectly installed in default namespace
    if kubectl get deployment argocd-server -n default &>/dev/null; then
        log_warn "ArgoCD found in 'default' namespace (should be in 'finans-asistan')"
        log_info "Removing ArgoCD from default namespace..."
        kubectl delete deployment,statefulset,service,configmap,secret -n default -l app.kubernetes.io/part-of=argocd &>/dev/null || true
        kubectl delete deployment argocd-server argocd-repo-server argocd-applicationset-controller argocd-dex-server argocd-notifications-controller argocd-redis -n default &>/dev/null || true
        kubectl delete statefulset argocd-application-controller -n default &>/dev/null || true
        kubectl delete service argocd-server argocd-repo-server argocd-redis argocd-dex-server argocd-applicationset-controller argocd-metrics argocd-server-metrics argocd-notifications-controller-metrics -n default &>/dev/null || true
        kubectl delete configmap argocd-cm argocd-rbac-cm argocd-cmd-params-cm argocd-gpg-keys-cm argocd-notifications-cm argocd-ssh-known-hosts-cm argocd-tls-certs-cm -n default &>/dev/null || true
        kubectl delete secret argocd-secret argocd-initial-admin-secret argocd-notifications-secret argocd-redis -n default &>/dev/null || true
        log_info "Waiting for resources to be deleted..."
        sleep 5
        log_success "ArgoCD removed from default namespace"
    fi
    
    # Clean up any stuck ArgoCD CRDs before installation (only if needed)
    # This is a troubleshooting step - only runs if CRDs are stuck in deletion
    local stuck_crds=$(kubectl get crd -o json 2>/dev/null | grep -o '"name":"[^"]*argoproj[^"]*"' | grep -o '"[^"]*"' | tr -d '"' || true)
    if [ -n "$stuck_crds" ]; then
        local has_stuck=false
        for crd in $stuck_crds; do
            local deletion_timestamp=$(kubectl get crd "$crd" -o jsonpath='{.metadata.deletionTimestamp}' 2>/dev/null || echo "")
            if [ -n "$deletion_timestamp" ]; then
                if [ "$has_stuck" = false ]; then
                    log_warn "Found stuck ArgoCD CRDs (from previous incomplete deletion), cleaning up..."
                    has_stuck=true
                fi
                log_info "Removing finalizers from stuck CRD: $crd"
                kubectl patch crd "$crd" --type json -p '[{"op": "remove", "path": "/metadata/finalizers"}]' >/dev/null 2>&1 || true
            fi
        done
        if [ "$has_stuck" = true ]; then
            log_info "Waiting for stuck CRDs to be fully deleted..."
            sleep 3
        fi
    fi
    
    # Ensure finans-asistan namespace exists (should already exist from previous steps)
    kubectl create namespace finans-asistan --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
    
    # Only install ArgoCD if not already installed
    if [ "$argocd_already_installed" = false ]; then
        # Download ArgoCD install.yaml and modify namespace references
        log_info "Downloading ArgoCD install.yaml and configuring for finans-asistan namespace..."
        local temp_argocd_file=$(mktemp)
        
        if curl -sSL "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" -o "$temp_argocd_file" 2>/dev/null; then
        # CRITICAL: Remove Namespace resource that creates "argocd" namespace
        # This prevents creation of a new "argocd" namespace
        # Use awk to remove the Namespace resource block
        awk '
        BEGIN { in_namespace=0; skip_resource=0 }
        /^---/ { 
            if (in_namespace && skip_resource) {
                in_namespace=0
                skip_resource=0
            }
            in_namespace=0
            skip_resource=0
            print
            next
        }
        /^kind:[[:space:]]*Namespace/ { 
            in_namespace=1
            skip_resource=0
        }
        in_namespace && /^[[:space:]]*name:[[:space:]]*argocd/ {
            skip_resource=1
            next
        }
        skip_resource && in_namespace {
            next
        }
        !skip_resource {
            print
        }
        ' "$temp_argocd_file" > "${temp_argocd_file}.tmp" && mv "${temp_argocd_file}.tmp" "$temp_argocd_file"
        
        # Comprehensive namespace replacement - handle all YAML namespace formats
        # This matches the Windows script's comprehensive replacement logic
        
        # Pass 1: Replace namespace: argocd (with any whitespace variations)
        sed -i 's/namespace:[[:space:]]*argocd[[:space:]]*$/namespace: finans-asistan/g' "$temp_argocd_file" 2>/dev/null || \
        sed 's/namespace:[[:space:]]*argocd[[:space:]]*$/namespace: finans-asistan/g' "$temp_argocd_file" > "${temp_argocd_file}.tmp" && mv "${temp_argocd_file}.tmp" "$temp_argocd_file"
        
        # Pass 2: Replace indented namespace: argocd (in metadata section with any indentation)
        sed -i 's/\([[:space:]]*\)namespace:[[:space:]]*argocd[[:space:]]*$/\1namespace: finans-asistan/g' "$temp_argocd_file" 2>/dev/null || \
        sed 's/\([[:space:]]*\)namespace:[[:space:]]*argocd[[:space:]]*$/\1namespace: finans-asistan/g' "$temp_argocd_file" > "${temp_argocd_file}.tmp" && mv "${temp_argocd_file}.tmp" "$temp_argocd_file"
        
        # Pass 3: Replace namespace:argocd (without space after colon)
        sed -i 's/namespace:argocd[[:space:]]*$/namespace: finans-asistan/g' "$temp_argocd_file" 2>/dev/null || \
        sed 's/namespace:argocd[[:space:]]*$/namespace: finans-asistan/g' "$temp_argocd_file" > "${temp_argocd_file}.tmp" && mv "${temp_argocd_file}.tmp" "$temp_argocd_file"
        
        # Pass 4: Replace -n argocd in comments or commands (if any)
        sed -i 's/-n[[:space:]]*argocd[[:space:]]*/-n finans-asistan /g' "$temp_argocd_file" 2>/dev/null || \
        sed 's/-n[[:space:]]*argocd[[:space:]]*/-n finans-asistan /g' "$temp_argocd_file" > "${temp_argocd_file}.tmp" && mv "${temp_argocd_file}.tmp" "$temp_argocd_file"
        
        # Verify namespace replacement worked
        if grep -q "namespace: argocd" "$temp_argocd_file" 2>/dev/null || grep -q "namespace:argocd" "$temp_argocd_file" 2>/dev/null; then
            log_warn "Some namespace references may not have been replaced, but continuing..."
        fi
        
        # Install ArgoCD - split into namespace-scoped and cluster-scoped resources
        # This ensures namespace-scoped resources go to finans-asistan, cluster-scoped go to cluster level
        log_info "Applying ArgoCD manifests to finans-asistan namespace..."
        
        # Apply with explicit namespace - kubectl will ignore namespace flag for cluster-scoped resources
        # This ensures all namespace-scoped resources go to finans-asistan namespace
        kubectl apply -f "$temp_argocd_file" --namespace=finans-asistan --validate=false >/dev/null 2>&1 || {
            # Fallback: apply without namespace flag if it causes issues
            kubectl apply -f "$temp_argocd_file" >/dev/null 2>&1 || {
                log_warn "ArgoCD installation failed, may already be installed"
            }
        }
        
        rm -f "$temp_argocd_file"
    else
        log_warn "Failed to download ArgoCD install.yaml, trying direct install with namespace override..."
        # Fallback: try direct install with namespace override
        # Remove Namespace resource and replace namespace references
        curl -sSL "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" | \
            awk '
            BEGIN { in_namespace=0; skip_resource=0 }
            /^---/ { 
                if (in_namespace && skip_resource) {
                    in_namespace=0
                    skip_resource=0
                }
                in_namespace=0
                skip_resource=0
                print
                next
            }
            /^kind:[[:space:]]*Namespace/ { 
                in_namespace=1
                skip_resource=0
            }
            in_namespace && /^[[:space:]]*name:[[:space:]]*argocd/ {
                skip_resource=1
                next
            }
            skip_resource && in_namespace {
                next
            }
            !skip_resource {
                print
            }
            ' | \
            sed 's/namespace:[[:space:]]*argocd[[:space:]]*$/namespace: finans-asistan/g' | \
            sed 's/\([[:space:]]*\)namespace:[[:space:]]*argocd[[:space:]]*$/\1namespace: finans-asistan/g' | \
            sed 's/namespace:argocd[[:space:]]*$/namespace: finans-asistan/g' | \
            kubectl apply -f - --namespace=finans-asistan --validate=false >/dev/null 2>&1 || {
            # Fallback: apply without namespace flag
            curl -sSL "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" | \
                awk '
                BEGIN { in_namespace=0; skip_resource=0 }
                /^---/ { 
                    if (in_namespace && skip_resource) {
                        in_namespace=0
                        skip_resource=0
                    }
                    in_namespace=0
                    skip_resource=0
                    print
                    next
                }
                /^kind:[[:space:]]*Namespace/ { 
                    in_namespace=1
                    skip_resource=0
                }
                in_namespace && /^[[:space:]]*name:[[:space:]]*argocd/ {
                    skip_resource=1
                    next
                }
                skip_resource && in_namespace {
                    next
                }
                !skip_resource {
                    print
                }
                ' | \
                sed 's/namespace:[[:space:]]*argocd[[:space:]]*$/namespace: finans-asistan/g' | \
                sed 's/\([[:space:]]*\)namespace:[[:space:]]*argocd[[:space:]]*$/\1namespace: finans-asistan/g' | \
                sed 's/namespace:argocd[[:space:]]*$/namespace: finans-asistan/g' | \
                kubectl apply -f - >/dev/null 2>&1 || {
                    log_warn "ArgoCD installation failed, may already be installed"
                }
        }
    else
        # ArgoCD already installed, skip installation but continue with configuration
        log_info "Skipping ArgoCD installation (already installed), proceeding with configuration..."
    fi
    
    # Continue with configuration and Application creation regardless of installation status
    # Only wait for ArgoCD to be ready if we just installed it
    if [ "$argocd_already_installed" = false ]; then
        log_info "Waiting for ArgoCD to be ready..."
        log_info "This may take 1-3 minutes (downloading images and initializing components)..."
        echo ""
        
        # Wait for critical ArgoCD components
    local max_wait=180  # 3 minutes
    local elapsed=0
    local check_interval=5  # Check every 5 seconds
    local all_ready=false
    
    # Define components to check
    local components=(
        "deployment argocd-redis"
        "deployment argocd-repo-server"
        "deployment argocd-server"
        "statefulset argocd-application-controller"
    )
    local total_components=${#components[@]}
    
    while [ $elapsed -lt $max_wait ]; do
        local ready_components=0
        
        # Check each component
        for component in "${components[@]}"; do
            local type=$(echo "$component" | awk '{print $1}')
            local name=$(echo "$component" | awk '{print $2}')
            
            if kubectl get "$type/$name" -n finans-asistan >/dev/null 2>&1; then
                if [ "$type" = "deployment" ]; then
                    if kubectl get "$type/$name" -n finans-asistan -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null | grep -q "True"; then
                        ((ready_components++))
                    fi
                elif [ "$type" = "statefulset" ]; then
                    local replicas=$(kubectl get "$type/$name" -n finans-asistan -o jsonpath='{.status.replicas}' 2>/dev/null || echo "0")
                    local ready_replicas=$(kubectl get "$type/$name" -n finans-asistan -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
                    if [ "$replicas" = "$ready_replicas" ] && [ "$replicas" != "0" ]; then
                        ((ready_components++))
                    fi
                fi
            fi
        done
        
        # Show progress
        printf "\r  Components ready: %d/%d (%ds elapsed)" "$ready_components" "$total_components" "$elapsed"
        
        # Check if all components are ready
        if [ $ready_components -eq $total_components ]; then
            all_ready=true
            echo ""
            echo ""
            log_success "All ArgoCD components are ready!"
            break
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
    done
    
    echo ""
    
        # Final verification with kubectl wait for critical component
        if [ "$all_ready" = false ]; then
            log_info "Performing final verification..."
            kubectl wait --for=condition=available deployment/argocd-server -n finans-asistan --timeout=60s >/dev/null 2>&1 || {
                log_warn "ArgoCD may take longer to start"
            }
        fi
        
        # Show final pod status
        echo ""
        log_info "Final ArgoCD pod status:"
        kubectl get pods -n finans-asistan | grep "argocd-" || true
        echo ""
    fi
    
    # Configure ArgoCD services for distributed deployment (podAntiAffinity)
    # This runs regardless of whether ArgoCD was just installed or already existed
    log_info "Configuring ArgoCD services for distributed deployment..."
    configure_argocd_distributed
    
    # Deploy ArgoCD HPA (after ArgoCD is installed)
    log_info "Deploying ArgoCD HPA..."
    if [ -f "k8s/06d-argocd-hpa.yaml" ]; then
        kubectl apply -f k8s/06d-argocd-hpa.yaml >/dev/null 2>&1
        log_success "ArgoCD HPA deployed"
    else
        log_warn "ArgoCD HPA manifest not found, skipping..."
    fi
    
    # Create ArgoCD repository credential (for GitHub access)
    log_info "Creating ArgoCD repository credential..."
    create_argocd_repo_credential
    
    # Create ArgoCD application (always create/update, even if ArgoCD was already installed)
    if [ -f "k8s/13-argocd-application.yaml" ]; then
        log_info "Creating/updating ArgoCD application..."
        kubectl apply -f k8s/13-argocd-application.yaml || log_warn "ArgoCD application creation failed"
        if [ $? -eq 0 ]; then
            log_success "ArgoCD application created/updated"
        fi
    else
        log_warn "ArgoCD application manifest not found: k8s/13-argocd-application.yaml"
    fi
    
    log_success "ArgoCD deployed"
}

# Create ArgoCD repository credential for GitHub
create_argocd_repo_credential() {
    log_info "Creating ArgoCD repository credential for GitHub..."
    
    # Get GitHub token from environment variables or app-secrets
    local github_token="${ACCESS_TOKEN_GITHUB:-}"
    
    if [ -z "$github_token" ]; then
        # Try to get from app-secrets
        if kubectl get secret app-secrets -n finans-asistan >/dev/null 2>&1; then
            github_token=$(kubectl get secret app-secrets -n finans-asistan -o jsonpath='{.data.ACCESS_TOKEN_GITHUB}' 2>/dev/null | base64 -d || echo "")
        fi
    fi
    
    if [ -z "$github_token" ]; then
        log_warn "ACCESS_TOKEN_GITHUB not found, ArgoCD will use public repository access"
        log_warn "For private repositories, set ACCESS_TOKEN_GITHUB in .env or app-secrets"
        
        # Create repository secret without credentials (public repo)
        kubectl create secret generic argocd-repo-github \
            --from-literal=type=git \
            --from-literal=url=https://github.com/JstLearn/FinansAsistan.git \
            -n finans-asistan \
            --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1 || true
        
        # Add ArgoCD label for repository secret
        kubectl label secret argocd-repo-github \
            argocd.argoproj.io/secret-type=repository \
            -n finans-asistan \
            --overwrite >/dev/null 2>&1 || true
        
        log_info "ArgoCD repository secret created (public access)"
        return 0
    fi
    
    # Create repository secret with GitHub token
    log_info "Creating ArgoCD repository secret with GitHub token..."
    
    # Delete existing secret if exists
    kubectl delete secret argocd-repo-github -n finans-asistan --ignore-not-found >/dev/null 2>&1
    
    # Create new secret with GitHub token
    kubectl create secret generic argocd-repo-github \
        --from-literal=type=git \
        --from-literal=url=https://github.com/JstLearn/FinansAsistan.git \
        --from-literal=password="${github_token}" \
        -n finans-asistan \
        --dry-run=client -o yaml | kubectl apply -f - >/dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        # Add ArgoCD label for repository secret
        kubectl label secret argocd-repo-github \
            argocd.argoproj.io/secret-type=repository \
            -n finans-asistan \
            --overwrite >/dev/null 2>&1 || true
        
        log_success "ArgoCD repository credential created with GitHub token"
        
        # Restart ArgoCD repo-server to pick up new credential
        log_info "Restarting ArgoCD repo-server to apply new credential..."
        kubectl rollout restart deployment argocd-repo-server -n finans-asistan >/dev/null 2>&1 || true
        
        # Wait a moment for repo-server to restart
        sleep 5
    else
        log_warn "Failed to create ArgoCD repository credential"
    fi
}

# Configure ArgoCD services for distributed deployment
configure_argocd_distributed() {
    log_info "Removing affinity constraints from ArgoCD services for distributed deployment..."
    log_info "Each node will have at least 1 pod, but can have more based on load (HPA minReplicas = node count)"
    
    # Check if argocd-server exists and has affinity, then remove it
    if kubectl get deployment argocd-server -n finans-asistan >/dev/null 2>&1; then
        server_affinity=$(kubectl get deployment argocd-server -n finans-asistan -o jsonpath='{.spec.template.spec.affinity}' 2>/dev/null)
        if [ -n "$server_affinity" ] && [ "$server_affinity" != "null" ] && [ "$server_affinity" != "{}" ]; then
            # Use strategic merge patch to remove affinity field
            patch_result=$(kubectl patch deployment argocd-server -n finans-asistan --type='strategic' -p='{"spec":{"template":{"spec":{"affinity":null}}}}' 2>&1)
            if [ $? -eq 0 ]; then
                log_info "ArgoCD Server configured for distributed deployment (affinity removed)"
            else
                # Fallback: try json patch
                patch_result=$(kubectl patch deployment argocd-server -n finans-asistan --type='json' -p='[{"op":"remove","path":"/spec/template/spec/affinity"}]' 2>&1)
                if [ $? -eq 0 ]; then
                    log_info "ArgoCD Server configured for distributed deployment (affinity removed via json patch)"
            else
                log_warn "Failed to remove affinity from argocd-server: $patch_result"
                fi
            fi
        else
            log_info "ArgoCD Server has no affinity constraints (already configured)"
        fi
    else
        log_info "ArgoCD Server deployment not found (may not be deployed yet)"
    fi
    
    # Check if argocd-repo-server exists and has affinity, then remove it
    if kubectl get deployment argocd-repo-server -n finans-asistan >/dev/null 2>&1; then
        repo_affinity=$(kubectl get deployment argocd-repo-server -n finans-asistan -o jsonpath='{.spec.template.spec.affinity}' 2>/dev/null)
        if [ -n "$repo_affinity" ] && [ "$repo_affinity" != "null" ] && [ "$repo_affinity" != "{}" ]; then
            # Use strategic merge patch to remove affinity field
            patch_result=$(kubectl patch deployment argocd-repo-server -n finans-asistan --type='strategic' -p='{"spec":{"template":{"spec":{"affinity":null}}}}' 2>&1)
            if [ $? -eq 0 ]; then
                log_info "ArgoCD Repo Server configured for distributed deployment (affinity removed)"
            else
                # Fallback: try json patch
                patch_result=$(kubectl patch deployment argocd-repo-server -n finans-asistan --type='json' -p='[{"op":"remove","path":"/spec/template/spec/affinity"}]' 2>&1)
                if [ $? -eq 0 ]; then
                    log_info "ArgoCD Repo Server configured for distributed deployment (affinity removed via json patch)"
            else
                log_warn "Failed to remove affinity from argocd-repo-server: $patch_result"
                fi
            fi
        else
            log_info "ArgoCD Repo Server has no affinity constraints (already configured)"
        fi
    else
        log_info "ArgoCD Repo Server deployment not found (may not be deployed yet)"
    fi
    
    # Note: argocd-application-controller is leader-only, so we don't modify it here
    
    log_success "ArgoCD services configured for distributed deployment"
    log_info "Get admin password: kubectl -n finans-asistan get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    log_info "Port forward: kubectl port-forward svc/argocd-server -n finans-asistan 8080:443"
}

# Label leader node (physical or EC2)
label_leader_node() {
    log_info "Labeling leader node..."
    
    # Try to find node by hostname or machine ID
    NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    
    # If we have MACHINE_ID, try to match it with node
    if [ -n "${MACHINE_ID:-}" ]; then
        MATCHING_NODE=$(kubectl get nodes -o jsonpath="{.items[?(@.metadata.labels.kubernetes\.io/hostname=='${MACHINE_ID}')].metadata.name}" 2>/dev/null || echo "")
        if [ -n "$MATCHING_NODE" ]; then
            NODE_NAME="$MATCHING_NODE"
        fi
    fi
    
    if [ -z "$NODE_NAME" ]; then
        log_warn "Could not find node to label"
        return 1
    fi
    
    # Remove old leader label from all nodes (to ensure only one leader)
    kubectl get nodes -o jsonpath='{.items[*].metadata.name}' | tr ' ' '\n' | while read node; do
        kubectl label node "$node" leader- 2>/dev/null || true
    done
    
    # Add leader label to current leader node
    kubectl label node "$NODE_NAME" \
        leader="true" \
        --overwrite 2>/dev/null || {
        log_warn "Failed to label node (may not have permissions or node not found)"
        return 1
    }
    
    # Also add node-type label if physical machine
    if [ "$MACHINE_TYPE" = "physical" ]; then
        kubectl label node "$NODE_NAME" \
            node-type=physical \
            --overwrite 2>/dev/null || true
    fi
    
    log_success "Leader node labeled: ${NODE_NAME}"
    log_info "   Labels: leader=true${MACHINE_TYPE:+}, node-type=$MACHINE_TYPE}"
}

# Protect initial node
protect_initial_node() {
    log_info "Protecting initial node..."
    
    NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    
    kubectl label node "$NODE_NAME" \
        node-role.kubernetes.io/master=true \
        database=true \
        kafka=true \
        --overwrite
    
    kubectl annotate node "$NODE_NAME" \
        cluster-autoscaler.kubernetes.io/scale-down-disabled=true \
        --overwrite
    
    log_success "Initial node protected"
}

# Detect if this is a physical machine
detect_physical_machine() {
    log_info "Detecting machine type..."
    
    # Check if running on EC2 (check metadata service)
    if curl -s --max-time 1 http://169.254.169.254/latest/meta-data/instance-id &> /dev/null; then
        INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        MACHINE_TYPE="ec2"
        MACHINE_ID="${INSTANCE_ID}"
        log_info "Detected EC2 instance: ${INSTANCE_ID}"
    else
        # Physical machine (or non-AWS cloud)
        MACHINE_TYPE="physical"
        MACHINE_ID=$(hostname)
        log_info "Detected physical machine: ${MACHINE_ID}"
    fi
    
    export MACHINE_TYPE
    export MACHINE_ID
}

# Check current leader from S3
check_current_leader() {
    if [ -z "${S3_BUCKET:-}" ] || ! check_aws_credentials; then
        return 1
    fi
    
    CURRENT_LEADER=$(aws s3 cp "s3://${S3_BUCKET}/current-leader.json" - 2>/dev/null || echo "")
    if [ -n "$CURRENT_LEADER" ]; then
        echo "$CURRENT_LEADER"
        return 0
    fi
    
    return 1
}

# Check if physical machine should be leader
check_leader_eligibility() {
    log_info "Checking leader eligibility..."
    
    if [ "$MACHINE_TYPE" != "physical" ]; then
        log_info "EC2 instance detected - checking if physical machine exists..."
        
        CURRENT_LEADER=$(check_current_leader)
        if [ -n "$CURRENT_LEADER" ]; then
            LEADER_TYPE=$(echo "$CURRENT_LEADER" | jq -r '.leader_type // "unknown"' 2>/dev/null || echo "unknown")
            if [ "$LEADER_TYPE" = "physical" ]; then
                log_info "Physical machine leader exists - this EC2 will not be leader"
                return 1  # Not eligible
            fi
        fi
        
        log_info "No physical machine leader found - EC2 can be temporary leader"
        return 0  # Eligible as temporary leader
    fi
    
    # Physical machine - check if it's the most recently started
    CURRENT_LEADER=$(check_current_leader)
    if [ -n "$CURRENT_LEADER" ]; then
        CURRENT_LEADER_TYPE=$(echo "$CURRENT_LEADER" | jq -r '.leader_type // "unknown"' 2>/dev/null || echo "unknown")
        CURRENT_LEADER_ID=$(echo "$CURRENT_LEADER" | jq -r '.leader_id // ""' 2>/dev/null || echo "")
        CURRENT_REGISTERED_AT=$(echo "$CURRENT_LEADER" | jq -r '.registered_at // ""' 2>/dev/null || echo "")
        
        if [ "$CURRENT_LEADER_TYPE" = "physical" ] && [ "$CURRENT_LEADER_ID" != "$MACHINE_ID" ]; then
            # Another physical machine is leader - check timestamps
            if [ -n "$CURRENT_REGISTERED_AT" ]; then
                CURRENT_TIMESTAMP=$(date -u -d "$CURRENT_REGISTERED_AT" +%s 2>/dev/null || echo "0")
                NOW_TIMESTAMP=$(date -u +%s)
                
                # If current leader registered more than 5 minutes ago, this machine can take over
                if [ $((NOW_TIMESTAMP - CURRENT_TIMESTAMP)) -lt 300 ]; then
                    log_info "Another physical machine is leader (registered recently) - this machine will not be leader"
                    return 1  # Not eligible
                fi
            fi
        fi
    fi
    
    log_info "This physical machine is eligible to be leader"
    return 0  # Eligible
}

# Register leadership
register_leadership() {
    log_info "Registering leadership..."
    
    if [ -z "${S3_BUCKET:-}" ] || ! check_aws_credentials; then
        log_warn "S3_BUCKET not set or AWS credentials missing, skipping leadership registration"
        return 0
    fi
    
    # Detect machine type
    detect_physical_machine
    
    # Check eligibility
    if ! check_leader_eligibility; then
        log_info "This machine is not eligible to be leader - skipping registration"
        return 0
    fi
    
    NODE_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "unknown")
    
    # Get k3s token and server URL (if k3s is installed)
    K3S_TOKEN=""
    K3S_SERVER_URL=""
    if [ -f /var/lib/rancher/k3s/server/node-token ]; then
        K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token 2>/dev/null || echo "")
        K3S_SERVER_URL="https://${NODE_IP}:6443"
    fi
    
    # Create leadership info (includes k3s join info for worker nodes)
    LEADER_INFO=$(jq -n \
        --arg leader_id "$MACHINE_ID" \
        --arg leader_type "$MACHINE_TYPE" \
        --arg node_ip "$NODE_IP" \
        --arg registered_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg last_heartbeat "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg k3s_token "$K3S_TOKEN" \
        --arg k3s_server_url "$K3S_SERVER_URL" \
        '{
            leader_id: $leader_id,
            leader_type: $leader_type,
            node_ip: $node_ip,
            registered_at: $registered_at,
            last_heartbeat: $last_heartbeat,
            k3s_token: $k3s_token,
            k3s_server_url: $k3s_server_url
        }')
    
    # Upload to S3
    echo "$LEADER_INFO" | aws s3 cp - "s3://${S3_BUCKET}/current-leader.json" \
        --content-type "application/json" || {
        log_warn "Failed to register leadership in S3"
        return 1
    }
    
    log_success "Leadership registered in S3"
    log_info "   Leader ID: ${MACHINE_ID}"
    log_info "   Leader Type: ${MACHINE_TYPE}"
    log_info "   Node IP: ${NODE_IP}"
    
    # Label Kubernetes node (physical or EC2 leader)
    label_leader_node
    
    # Start heartbeat daemon (background)
    start_heartbeat_daemon &
    
    # Setup k3s snapshot cron job (only for leader)
    setup_k3s_snapshot_cron
}

# Setup k3s snapshot cron job
setup_k3s_snapshot_cron() {
    log_info "Setting up k3s snapshot cron job..."
    
    if [ -z "${S3_BUCKET:-}" ] || ! check_aws_credentials; then
        log_warn "S3_BUCKET not set or AWS credentials missing, skipping snapshot cron setup"
        return 0
    fi
    
    # Check if k3s is installed
    if ! command -v k3s &> /dev/null; then
        log_warn "k3s not found, skipping snapshot cron setup"
        return 0
    fi
    
    # Find snapshot script in project directory
    # Try multiple possible locations
    SNAPSHOT_SCRIPT=""
    
    # Option 1: In current working directory (if we're in FinansAsistan/)
    if [ -f "scripts/k3s-snapshot.sh" ]; then
        SNAPSHOT_SCRIPT="$(pwd)/scripts/k3s-snapshot.sh"
    # Option 2: In FinansAsistan/ subdirectory
    elif [ -f "FinansAsistan/scripts/k3s-snapshot.sh" ]; then
        SNAPSHOT_SCRIPT="$(pwd)/FinansAsistan/scripts/k3s-snapshot.sh"
    # Option 3: In /opt/finans-asistan (common installation path)
    elif [ -f "/opt/finans-asistan/scripts/k3s-snapshot.sh" ]; then
        SNAPSHOT_SCRIPT="/opt/finans-asistan/scripts/k3s-snapshot.sh"
    # Option 4: Try to download from S3 if available
    elif [ -n "${S3_BUCKET:-}" ] && check_aws_credentials; then
        log_info "Snapshot script not found locally, trying to download from S3..."
        mkdir -p /opt/finans-asistan/scripts
        if aws s3 cp "s3://${S3_BUCKET}/FinansAsistan/scripts/k3s-snapshot.sh" /opt/finans-asistan/scripts/k3s-snapshot.sh 2>/dev/null; then
            SNAPSHOT_SCRIPT="/opt/finans-asistan/scripts/k3s-snapshot.sh"
            log_success "Snapshot script downloaded from S3"
        fi
    fi
    
    # Check if snapshot script exists
    if [ -z "$SNAPSHOT_SCRIPT" ] || [ ! -f "$SNAPSHOT_SCRIPT" ]; then
        log_warn "Snapshot script not found. Tried locations:"
        log_warn "  - scripts/k3s-snapshot.sh"
        log_warn "  - FinansAsistan/scripts/k3s-snapshot.sh"
        log_warn "  - /opt/finans-asistan/scripts/k3s-snapshot.sh"
        log_warn "  - S3: s3://${S3_BUCKET:-N/A}/FinansAsistan/scripts/k3s-snapshot.sh"
        log_warn "Skipping snapshot cron setup. Snapshot script will be available after next project sync."
        return 0
    fi
    
    # Make script executable
    chmod +x "$SNAPSHOT_SCRIPT"
    
    # Create wrapper script that sets environment variables
    WRAPPER_SCRIPT="/usr/local/bin/k3s-snapshot-wrapper.sh"
    cat > "$WRAPPER_SCRIPT" <<EOF
#!/bin/bash
# Wrapper script for k3s snapshot with environment variables
export S3_BUCKET="${S3_BUCKET}"
export AWS_REGION="${AWS_REGION:-eu-central-1}"
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
${SNAPSHOT_SCRIPT} >> /var/log/k3s-snapshot.log 2>&1
EOF
    
    chmod +x "$WRAPPER_SCRIPT"
    
    # Setup cron job (every 6 hours)
    CRON_JOB="0 */6 * * * root ${WRAPPER_SCRIPT}"
    
    # Check if cron job already exists
    if [ -f /etc/cron.d/k3s-snapshot ]; then
        log_info "k3s snapshot cron job already exists, updating..."
        rm -f /etc/cron.d/k3s-snapshot
    fi
    
    # Create cron job file
    echo "$CRON_JOB" > /etc/cron.d/k3s-snapshot
    chmod 0644 /etc/cron.d/k3s-snapshot
    
    log_success "k3s snapshot cron job installed"
    log_info "   Schedule: Every 6 hours (0 */6 * * *)"
    log_info "   Script: ${WRAPPER_SCRIPT}"
    log_info "   Log: /var/log/k3s-snapshot.log"
    log_info "   S3 Bucket: ${S3_BUCKET}"
    log_info "   S3 Path: s3://${S3_BUCKET}/k3s/snapshots/"
}

# Start heartbeat daemon (updates heartbeat every 15 seconds)
start_heartbeat_daemon() {
    if [ -z "${S3_BUCKET:-}" ] || ! check_aws_credentials; then
        return 0
    fi
    
    log_info "Starting heartbeat daemon..."
    
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
                # Get current k3s token (if available)
                K3S_TOKEN=""
                K3S_SERVER_URL=""
                NODE_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "unknown")
                
                if [ -f /var/lib/rancher/k3s/server/node-token ]; then
                    K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token 2>/dev/null || echo "")
                    K3S_SERVER_URL="https://${NODE_IP}:6443"
                fi
                
                # Update heartbeat and k3s token (if token was empty before or changed)
                CURRENT_TOKEN=$(echo "$CURRENT_LEADER" | jq -r '.k3s_token // ""' 2>/dev/null || echo "")
                if [ -n "$K3S_TOKEN" ] && ([ -z "$CURRENT_TOKEN" ] || [ "$CURRENT_TOKEN" != "$K3S_TOKEN" ]); then
                    # Token is available and needs to be updated
                    UPDATED_LEADER=$(echo "$CURRENT_LEADER" | jq \
                        --arg last_heartbeat "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                        --arg k3s_token "$K3S_TOKEN" \
                        --arg k3s_server_url "$K3S_SERVER_URL" \
                        --arg node_ip "$NODE_IP" \
                        '.last_heartbeat = $last_heartbeat | .k3s_token = $k3s_token | .k3s_server_url = $k3s_server_url | .node_ip = $node_ip')
                else
                    # Just update heartbeat
                UPDATED_LEADER=$(echo "$CURRENT_LEADER" | jq \
                    --arg last_heartbeat "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                    '.last_heartbeat = $last_heartbeat')
                fi
                
                echo "$UPDATED_LEADER" | aws s3 cp - "s3://${S3_BUCKET}/current-leader.json" \
                    --content-type "application/json" 2>/dev/null || true
            fi
        fi
    done
}

# Health check
health_check() {
    log_info "Running health checks..."
    
    # Check pods
    FAILED_PODS=$(kubectl get pods -n finans-asistan --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
    if [ "$FAILED_PODS" -gt 0 ]; then
        log_warn "$FAILED_PODS pods are not running"
    else
        log_success "All pods are running"
    fi
    
    # Check database using configured credentials
    local db_user="$(kubectl get secret app-secrets -n finans-asistan -o jsonpath='{.data.POSTGRES_USER}' 2>/dev/null | base64 -d || echo "")"
    local db_name="$(kubectl get secret app-secrets -n finans-asistan -o jsonpath='{.data.POSTGRES_DB}' 2>/dev/null | base64 -d || echo "")"
    if [ -z "$db_user" ]; then 
        db_user="$POSTGRES_USER"
        if [ -z "$db_user" ]; then
            log_warn "POSTGRES_USER not found in secrets or environment"
            return 1
        fi
    fi
    if [ -z "$db_name" ]; then 
        db_name="$POSTGRES_DB"
        if [ -z "$db_name" ]; then
            log_warn "POSTGRES_DB not found in secrets or environment"
            return 1
        fi
    fi
    if kubectl exec -n finans-asistan statefulset/postgres -- pg_isready -U "$db_user" -d "$db_name" &> /dev/null; then
        log_success "Database is healthy"
    else
        log_error "Database health check failed"
    fi
}

# Show summary
show_summary() {
    log_success "Deployment completed!"
    echo ""
    echo "==========================================================="
    echo "  FinansAsistan Deployment Summary"
    echo "==========================================================="
    echo ""
    
    # Get node IP
    NODE_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")
    
    echo "Services Status:"
    kubectl get pods -n finans-asistan 2>/dev/null || echo "  (Unable to get pod status)"
    echo ""
    
    echo "Access Points:"
    echo "  - Backend API: http://${NODE_IP}:5000"
    echo "  - Frontend: http://${NODE_IP}:9999"
    echo "  - Health Check: http://${NODE_IP}:5000/health"
    echo ""
    
    echo "Kubernetes Commands:"
    echo "  - View pods: kubectl get pods -n finans-asistan"
    echo "  - View logs: kubectl logs -f deployment/backend -n finans-asistan"
    echo "  - View events: kubectl get events -n finans-asistan --sort-by='.lastTimestamp'"
    echo ""
    
    if [ "$RECOVERY_MODE" = true ]; then
        echo "⚠️  Recovery Mode: Database restored from S3"
    else
        echo "✅ Fresh Install: New database created"
    fi
    echo ""
    
    echo "Next Steps:"
    echo "  1. Configure DNS to point to this server (${NODE_IP})"
    echo "  2. Update k8s/08-ingress.yaml with your domain"
    echo "  3. Set up SSL certificates (cert-manager)"
    echo "  4. Secrets are created directly in cluster (not in Git files)"
    echo "     Secrets are loaded from QUICK_START/.env or GitHub Secrets"
    echo ""
    
    echo "AWS Auto-Scaling:"
    echo "  - Current AWS node count: 0 (initial node only)"
    echo "  - Auto-scaling enabled: Yes"
    echo "  - Scale trigger: CPU > 80% or Memory > 85%"
    echo ""
}

# Main execution
main() {
    log_info "Starting FinansAsistan bootstrap..."
    
    # Always cleanup existing resources first (fresh start)
    cleanup_all_resources
    
    check_prerequisites
    check_aws_credentials || true
    detect_recovery_mode
    setup_repository
    setup_env
    install_k3s
    install_operators
    protect_initial_node
    detect_physical_machine
    register_leadership
    deploy_postgres
    deploy_kafka
    deploy_redis
    create_ecr_secret
    deploy_applications
    deploy_autoscaler
    deploy_monitoring
    deploy_argocd
    # Note: register_leadership is already called earlier (after detect_physical_machine)
    # Second call was removed to prevent duplicate heartbeat daemon and cron job
    health_check
    show_summary
    
    log_success "Bootstrap completed successfully!"
}

# Run main
main "$@"

