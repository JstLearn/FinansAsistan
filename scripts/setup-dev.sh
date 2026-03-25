#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Development Mode Quick Start
# GitHub'dan klonlar ve development modunda başlatır
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

# Try SSH first (recommended for private repos), fallback to HTTPS
REPO_URL_SSH="git@github.com:JstLearn/FinansAsistan.git"
REPO_URL_HTTPS="https://github.com/JstLearn/FinansAsistan.git"
PROJECT_DIR="FinansAsistan"

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  FinansAsistan - Development Mode Quick Start"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Check if Git is installed
if ! command -v git &> /dev/null; then
    log_error "Git not found. Please install Git first."
    exit 1
fi

# Check if project directory exists
if [ -d "$PROJECT_DIR" ]; then
    log_warn "Project directory exists. Updating..."
    cd "$PROJECT_DIR"
    
    # Try to pull from master first, then main
    if git pull origin master 2>/dev/null || git pull origin main 2>/dev/null; then
        log_success "Project updated"
    else
        log_warn "Could not pull updates. Using existing code."
    fi
else
    log_info "Cloning repository..."
    # Try SSH first (recommended for private repos)
    if git clone "$REPO_URL_SSH" "$PROJECT_DIR" 2>/dev/null; then
        log_success "Repository cloned via SSH"
        cd "$PROJECT_DIR"
    elif git clone "$REPO_URL_HTTPS" "$PROJECT_DIR" 2>/dev/null; then
        log_warn "Repository cloned via HTTPS"
        log_info "Note: For private repositories, SSH is recommended. Set up SSH keys:"
        log_info "  ssh-keygen -t ed25519 -C 'your_email@example.com'"
        log_info "  cat ~/.ssh/id_ed25519.pub"
        log_info "  # Add to GitHub → Settings → SSH and GPG keys"
        cd "$PROJECT_DIR"
    else
        log_error "Failed to clone repository"
        log_error "This is a private repository. Please ensure:"
        log_error "  1. SSH keys are set up (recommended)"
        log_error "  2. Or use HTTPS with Personal Access Token"
        log_error "  3. Or clone manually: git clone git@github.com:JstLearn/FinansAsistan.git"
        exit 1
    fi
fi

# Check if dev-start.sh exists
if [ ! -f "scripts/dev-start.sh" ]; then
    log_error "dev-start.sh not found in scripts directory!"
    exit 1
fi

# Make script executable
chmod +x scripts/dev-start.sh

# Run dev-start.sh
log_info "Starting development environment..."
./scripts/dev-start.sh

