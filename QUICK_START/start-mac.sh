#!/bin/bash
# ============================================================
# FinansAsistan - macOS Başlatma (Unified)
# 
# Production: Kubernetes (k3s) + ArgoCD
# Development: Docker Compose (production ortamından izole)
# ============================================================

set -euo pipefail

CYAN='\033[0;36m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  FinansAsistan - Ortam ve İşlem Seçimi (macOS)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

echo -e "${BLUE}1) Ortam Seçimi:${NC}"
echo "   [1] Production (Prod)"
echo "   [2] Development (Dev)"
echo ""
read -p "Ortam seçiniz [1-2] (varsayılan: 1): " ENV_CHOICE
ENV_CHOICE=${ENV_CHOICE:-1}

if [ "$ENV_CHOICE" = "2" ]; then
    export MODE_ACTION="dev"
    export ENVIRONMENT="development"
    export MODE="development"
    echo -e "${GREEN}✓ Development ortamı seçildi${NC}"
    echo ""
else
    echo -e "${BLUE}2) Production İşlemi:${NC}"
    echo "   [1] Control-plane işlemleri"
    echo "   [2] Mevcut kümeye worker olarak katıl"
    echo ""
    read -p "Seçiminiz [1-2] (varsayılan: 1): " PROD_CHOICE
    PROD_CHOICE=${PROD_CHOICE:-1}
    
    if [ "$PROD_CHOICE" = "2" ]; then
        export MODE_ACTION="prod-worker"
        echo -e "${GREEN}✓ Worker join seçildi${NC}"
        echo ""
    else
        export MODE_ACTION="prod-cp-auto"
        echo -e "${BLUE}[INFO]${NC} Control-plane durumu otomatik tespit edilecek"
        echo ""
    fi
    
    export ENVIRONMENT="production"
    export MODE="production"
fi

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  FinansAsistan - macOS Başlatma${NC}"
echo -e "${CYAN}  ModeAction: ${MODE_ACTION:-prod-cp-a}${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} .env file not found: $ENV_FILE"
    exit 1
fi

while IFS='=' read -r key value || [ -n "$key" ]; do
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    case "$key" in
        AWS_ACCESS_KEY_ID) AWS_ACCESS_KEY_ID="$value" ;;
        AWS_SECRET_ACCESS_KEY) AWS_SECRET_ACCESS_KEY="$value" ;;
        AWS_REGION) AWS_REGION="$value" ;;
        AWS_ACCOUNT_ID) AWS_ACCOUNT_ID="$value" ;;
        S3_BUCKET) S3_BUCKET="$value" ;;
        JWT_SECRET) JWT_SECRET="$value" ;;
        EMAIL_USER) EMAIL_USER="$value" ;;
        EMAIL_PASS) EMAIL_PASS="$value" ;;
        POSTGRES_DB) POSTGRES_DB="$value" ;;
        POSTGRES_USER) POSTGRES_USER="$value" ;;
        POSTGRES_PASSWORD) POSTGRES_PASSWORD="$value" ;;
        ACCESS_TOKEN_GITHUB) ACCESS_TOKEN_GITHUB="$value" ;;
        BACKUP_INTERVAL) BACKUP_INTERVAL="$value" ;;
    esac
done < "$ENV_FILE"

GITHUB_TOKEN="$ACCESS_TOKEN_GITHUB"
AWS_REGION="${AWS_REGION:-eu-central-1}"

export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_REGION
export AWS_ACCOUNT_ID
export S3_BUCKET
export JWT_SECRET
export EMAIL_USER
export EMAIL_PASS
export POSTGRES_DB
export POSTGRES_USER
export POSTGRES_PASSWORD
export ACCESS_TOKEN_GITHUB
export BACKUP_INTERVAL
export ENVIRONMENT
export MODE
export MODE_ACTION

echo -e "${GREEN}[SUCCESS]${NC} Configuration loaded from .env file"

if [ -n "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY:-}" ]; then
    AWS_TOKEN_BASE64=$(echo -n "{\"accessKeyId\":\"$AWS_ACCESS_KEY_ID\",\"secretAccessKey\":\"$AWS_SECRET_ACCESS_KEY\",\"region\":\"$AWS_REGION\"}" | base64)
else
    AWS_TOKEN_BASE64=""
fi

echo -e "${BLUE}[INFO]${NC} Downloading installer script from GitHub..."
if [ -n "$AWS_TOKEN_BASE64" ] && [ -n "${S3_BUCKET:-}" ]; then
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-mac.sh | \
      grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -D | \
      bash -s "$GITHUB_TOKEN" "$AWS_TOKEN_BASE64" "$S3_BUCKET"
else
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" \
      https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-mac.sh | \
      grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -D | \
      bash -s "$GITHUB_TOKEN" "" ""
fi
