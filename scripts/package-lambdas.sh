#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Lambda Package Builder
# Lambda fonksiyonlarını paketler ve Terraform için hazırlar
# ════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LAMBDA_DIR="$PROJECT_ROOT/lambda"
TERRAFORM_DIR="$PROJECT_ROOT/terraform/aws"

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

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed"
        exit 1
    fi
    
    if ! command -v zip &> /dev/null; then
        log_error "zip is not installed"
        exit 1
    fi
    
    log_success "Prerequisites check passed"
}

# Package Lambda function
package_lambda() {
    local lambda_name=$1
    local lambda_path="$LAMBDA_DIR/$lambda_name"
    local output_zip="$TERRAFORM_DIR/lambda-$lambda_name.zip"
    
    if [ ! -d "$lambda_path" ]; then
        log_error "Lambda function not found: $lambda_path"
        return 1
    fi
    
    log_info "Packaging Lambda function: $lambda_name"
    
    # Create temporary directory
    local temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    # Copy Lambda function files
    cp -r "$lambda_path"/* "$temp_dir/"
    
    # Install dependencies if requirements.txt exists
    if [ -f "$lambda_path/requirements.txt" ]; then
        log_info "Installing dependencies from requirements.txt..."
        cd "$temp_dir"
        python3 -m pip install -r requirements.txt -t . --quiet --no-cache-dir
        cd "$PROJECT_ROOT"
    fi
    
    # Create zip file
    cd "$temp_dir"
    zip -r "$output_zip" . -q
    cd "$PROJECT_ROOT"
    
    log_success "Lambda function packaged: $output_zip"
}

# Package all Lambda functions
package_all() {
    log_info "Packaging all Lambda functions..."
    
    # Create terraform/aws directory if it doesn't exist
    mkdir -p "$TERRAFORM_DIR"
    
    # Package each Lambda function
    for lambda_dir in "$LAMBDA_DIR"/*; do
        if [ -d "$lambda_dir" ]; then
            lambda_name=$(basename "$lambda_dir")
            package_lambda "$lambda_name"
        fi
    done
    
    log_success "All Lambda functions packaged"
}

# Main execution
main() {
    log_info "Starting Lambda package builder..."
    
    check_prerequisites
    package_all
    
    log_success "Lambda package builder completed!"
    echo ""
    echo "Packaged Lambda functions:"
    ls -lh "$TERRAFORM_DIR"/lambda-*.zip 2>/dev/null || echo "  (No packages found)"
}

main "$@"

