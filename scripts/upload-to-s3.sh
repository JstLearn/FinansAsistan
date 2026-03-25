#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - Complete Project S3 Upload Script
# TÜM projeyi S3'e yükler (.env, node_modules dahil)
# ════════════════════════════════════════════════════════════

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

# Check AWS CLI
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI is not installed. Please install it first."
        exit 1
    fi
    log_success "AWS CLI found"
}

# Check AWS credentials
check_aws_credentials() {
    if [ -z "${AWS_ACCESS_KEY_ID:-}" ] || [ -z "${AWS_SECRET_ACCESS_KEY:-}" ]; then
        log_error "AWS credentials not set. Please set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        exit 1
    fi
    
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials are invalid"
        exit 1
    fi
    
    log_success "AWS credentials verified"
}

# Get S3 bucket name
get_s3_bucket() {
    if [ -n "${S3_BUCKET:-}" ]; then
        echo "$S3_BUCKET"
        return 0
    fi
    
    # Try to get from terraform output
    if [ -f "terraform/aws/terraform.tfstate" ]; then
        BUCKET=$(terraform -chdir=terraform/aws output -raw s3_backup_bucket 2>/dev/null || echo "")
        if [ -n "$BUCKET" ]; then
            echo "$BUCKET"
            return 0
        fi
    fi
    
    # Prompt user
    read -p "Enter S3 bucket name: " BUCKET
    if [ -z "$BUCKET" ]; then
        log_error "S3 bucket name is required"
        exit 1
    fi
    
    echo "$BUCKET"
}

# Upload bootstrap script
upload_bootstrap_script() {
    local bucket=$1
    
    log_info "Uploading bootstrap script..."
    
    if [ ! -f "scripts/bootstrap.sh" ]; then
        log_error "bootstrap.sh not found at scripts/bootstrap.sh"
        return 1
    fi
    
    aws s3 cp scripts/bootstrap.sh "s3://${bucket}/scripts/bootstrap.sh" \
        --content-type "text/x-shellscript" \
        --metadata "uploaded=$(date -u +%Y-%m-%dT%H:%M:%SZ)" || {
        log_error "Failed to upload bootstrap script"
        return 1
    }
    
    log_success "Bootstrap script uploaded"
}

# Upload k8s manifests
upload_k8s_manifests() {
    local bucket=$1
    
    log_info "Uploading k8s manifests..."
    
    if [ ! -d "k8s" ]; then
        log_error "k8s directory not found"
        return 1
    fi
    
    # Count YAML files
    YAML_COUNT=$(find k8s -name "*.yaml" -type f | wc -l)
    if [ "$YAML_COUNT" -eq 0 ]; then
        log_warn "No YAML files found in k8s directory"
        return 1
    fi
    
    aws s3 sync k8s/ "s3://${bucket}/FinansAsistan/k8s/" \
        --exclude "*.yaml.bak" \
        --exclude ".git/*" \
        --content-type "application/x-yaml" \
        --metadata "uploaded=$(date -u +%Y-%m-%dT%H:%M:%SZ)" || {
        log_error "Failed to upload k8s manifests"
        return 1
    }
    
    log_success "K8s manifests uploaded ($YAML_COUNT files)"
}

# Upload bootstrap files
upload_bootstrap_files() {
    local bucket=$1
    
    log_info "Uploading bootstrap files..."
    
    if [ ! -d "bootstrap" ]; then
        log_warn "bootstrap directory not found, skipping"
        return 0
    fi
    
    FILE_COUNT=$(find bootstrap -type f | wc -l)
    if [ "$FILE_COUNT" -eq 0 ]; then
        log_warn "No files found in bootstrap directory"
        return 0
    fi
    
    aws s3 sync bootstrap/ "s3://${bucket}/bootstrap/" \
        --exclude ".git/*" \
        --metadata "uploaded=$(date -u +%Y-%m-%dT%H:%M:%SZ)" || {
        log_error "Failed to upload bootstrap files"
        return 1
    }
    
    log_success "Bootstrap files uploaded ($FILE_COUNT files)"
}

# Upload COMPLETE project to S3 (including gitignore files)
upload_complete_project() {
    local bucket=$1
    
    log_info "═══════════════════════════════════════════════════════════"
    log_info "Uploading COMPLETE project to S3"
    log_info "═══════════════════════════════════════════════════════════"
    echo ""
    log_info "This includes ALL files, even those in .gitignore:"
    echo "  - .env files"
    echo "  - node_modules/"
    echo "  - All source code"
    echo "  - All configuration files"
    echo ""
    
    # Check if versioning is enabled
    VERSIONING_STATUS=$(aws s3api get-bucket-versioning --bucket "${bucket}" --query 'Status' --output text 2>/dev/null || echo "NotSet")
    if [ "$VERSIONING_STATUS" != "Enabled" ]; then
        log_warn "S3 versioning is not enabled for bucket ${bucket}"
        log_warn "Old file versions will be overwritten (not deleted, but replaced)"
        log_info "Consider enabling versioning: aws s3api put-bucket-versioning --bucket ${bucket} --versioning-configuration Status=Enabled"
    else
        log_success "S3 versioning is enabled - old versions will be preserved"
    fi
    
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    
    # Tüm projeyi S3'e sync et (gitignore'daki dosyalar dahil)
    # --delete flag'i YOK - silinen dosyalar S3'te kalır (eski versiyonlar korunur)
    # Eğer dosya silinmişse, S3'te kalır ama yeni commit'te olmaz
    # Versioning aktifse eski versiyonlar korunur
    aws s3 sync . "s3://${bucket}/FinansAsistan/" \
        --exclude ".git/*" \
        --exclude ".github/workflows/*.yml" \
        --exclude "*.log" \
        --exclude ".DS_Store" \
        --exclude "Thumbs.db" \
        --metadata "uploaded=${TIMESTAMP}" \
        --metadata-directive REPLACE || {
        log_error "Failed to sync complete project to S3"
        return 1
    }
    
    log_success "Complete project uploaded to S3"
    echo "   Location: s3://${bucket}/FinansAsistan/"
    echo ""
    log_info "Note: If files were deleted from repo, they remain in S3 (old versions preserved)"
    
    # CRITICAL: QUICK_START/.env dosyasını ayrıca yükle (güvenlik için encryption ile)
    # Bu dosya Lambda'nın EC2 instance'ları başlatabilmesi için ZORUNLUDUR
    if [ -f "QUICK_START/.env" ]; then
        log_info "Uploading QUICK_START/.env file with encryption (REQUIRED for Lambda)..."
        if aws s3 cp "QUICK_START/.env" "s3://${bucket}/FinansAsistan/QUICK_START/.env" \
            --metadata "uploaded=${TIMESTAMP}" \
            --server-side-encryption AES256; then
            log_success "QUICK_START/.env uploaded with encryption"
            echo "   Location: s3://${bucket}/FinansAsistan/QUICK_START/.env"
        else
            log_error "CRITICAL: Failed to upload QUICK_START/.env file"
            log_error "Without this file, Lambda cannot start EC2 instances and services will fail"
            return 1
        fi
    else
        log_error "CRITICAL: QUICK_START/.env file not found"
        log_error "This file is REQUIRED for Lambda to start EC2 instances"
        log_error "Please create QUICK_START/.env file with all required environment variables"
        return 1
    fi
    
    # Create project manifest
    log_info "Creating project manifest..."
    cat > /tmp/project-manifest.json <<EOF
{
  "uploaded": "${TIMESTAMP}",
  "location": "s3://${bucket}/FinansAsistan/",
  "includes": [
    "All source code",
    "node_modules (if exists)",
    ".env files",
    "Configuration files",
    "All project files (except .git)"
  ]
}
EOF
    
    aws s3 cp /tmp/project-manifest.json "s3://${bucket}/manifest.json" \
        --content-type "application/json" \
        --metadata "uploaded=${TIMESTAMP}"
    
    log_success "Project manifest created"
}

# Main function
main() {
    log_info "Starting S3 upload process..."
    
    check_aws_cli
    check_aws_credentials
    
    S3_BUCKET=$(get_s3_bucket)
    log_info "Using S3 bucket: ${S3_BUCKET}"
    
    # Verify bucket exists
    if ! aws s3 ls "s3://${S3_BUCKET}" &>/dev/null; then
        log_error "S3 bucket does not exist or is not accessible: ${S3_BUCKET}"
        exit 1
    fi
    
    # Ask user what to upload
    echo ""
    echo "What would you like to upload?"
    echo "  1) Complete project (ALL files including .env, node_modules)"
    echo "  2) Legacy files only (bootstrap.sh, k8s/, bootstrap/)"
    echo "  3) Both"
    read -p "Enter choice [1-3] (default: 1): " CHOICE
    CHOICE=${CHOICE:-1}
    
    case $CHOICE in
        1)
            upload_complete_project "${S3_BUCKET}" || {
                log_error "Failed to upload complete project"
                exit 1
            }
            ;;
        2)
    # Create scripts directory in S3 if it doesn't exist
    aws s3api put-object --bucket "${S3_BUCKET}" --key "scripts/" --content-length 0 2>/dev/null || true
    
            # Upload legacy files
            upload_bootstrap_script "${S3_BUCKET}"
            upload_k8s_manifests "${S3_BUCKET}"
            upload_bootstrap_files "${S3_BUCKET}"
            ;;
        3)
            upload_complete_project "${S3_BUCKET}" || {
                log_error "Failed to upload complete project"
                exit 1
            }
            
            # Also upload legacy files for backward compatibility
            aws s3api put-object --bucket "${S3_BUCKET}" --key "scripts/" --content-length 0 2>/dev/null || true
    upload_bootstrap_script "${S3_BUCKET}"
    upload_k8s_manifests "${S3_BUCKET}"
    upload_bootstrap_files "${S3_BUCKET}"
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
    
    log_success "Upload completed successfully!"
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Upload Summary"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "S3 Bucket: ${S3_BUCKET}"
    if [ "$CHOICE" = "1" ] || [ "$CHOICE" = "3" ]; then
        echo "Complete Project: s3://${S3_BUCKET}/FinansAsistan/"
        echo ""
        echo "To download and deploy:"
        echo "  aws s3 sync s3://${S3_BUCKET}/FinansAsistan/ ./FinansAsistan/"
    fi
    if [ "$CHOICE" = "2" ] || [ "$CHOICE" = "3" ]; then
        echo "Legacy Files:"
    echo "  - s3://${S3_BUCKET}/scripts/bootstrap.sh"
        echo "  - s3://${S3_BUCKET}/FinansAsistan/k8s/*.yaml"
    echo "  - s3://${S3_BUCKET}/bootstrap/*"
    fi
    echo ""
}

# Run main
main "$@"

