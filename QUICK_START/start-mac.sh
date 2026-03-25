#!/bin/bash
# ============================================================
# FinansAsistan - macOS Başlatma (Unified)
# 
# Production: Kubernetes (k3s) + ArgoCD
# Development: Docker Compose (production ortamından izole)
# ============================================================

set -euo pipefail

# Renkler
CYAN='\033[0;36m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Mode selection menu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}  FinansAsistan - Ortam ve İşlem Seçimi (macOS)${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
echo ""

# Ortam seçimi
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
    # Production alt menü: Control-plane / Worker
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
        # Control-plane işlemleri: Otomatik tespit (daha sonra .env okunduktan sonra yapılacak)
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

# .env dosyasından bilgileri al
echo -e "${BLUE}[INFO]${NC} Loading configuration from .env file..."

# Script'in bulunduğu dizini bul
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}[ERROR]${NC} .env file not found: $ENV_FILE"
    echo -e "${RED}[ERROR]${NC} Please create .env file in QUICK_START directory with all required configuration."
    exit 1
fi

# .env dosyasını oku ve parse et
echo -e "${BLUE}[INFO]${NC} Reading .env file: $ENV_FILE"

# .env dosyasındaki değerleri parse et
while IFS='=' read -r key value || [ -n "$key" ]; do
    # Boş satırları ve yorumları atla
    [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
    
    # KEY=VALUE formatını parse et
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)
    
    # Değişkenleri export et
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

# Default değerler
AWS_REGION="${AWS_REGION:-eu-central-1}"
BACKUP_INTERVAL="${BACKUP_INTERVAL:-300}"  # Default: 5 minutes (300 seconds)

# Kritik değişkenleri kontrol et (production için)
if [ "$MODE_ACTION" != "dev" ]; then
    MISSING_VARS=""
    [ -z "$AWS_ACCESS_KEY_ID" ] && MISSING_VARS="${MISSING_VARS} AWS_ACCESS_KEY_ID"
    [ -z "$AWS_SECRET_ACCESS_KEY" ] && MISSING_VARS="${MISSING_VARS} AWS_SECRET_ACCESS_KEY"
    [ -z "$S3_BUCKET" ] && MISSING_VARS="${MISSING_VARS} S3_BUCKET"
    [ -z "$JWT_SECRET" ] && MISSING_VARS="${MISSING_VARS} JWT_SECRET"
    [ -z "$POSTGRES_DB" ] && MISSING_VARS="${MISSING_VARS} POSTGRES_DB"
    [ -z "$POSTGRES_USER" ] && MISSING_VARS="${MISSING_VARS} POSTGRES_USER"
    [ -z "$POSTGRES_PASSWORD" ] && MISSING_VARS="${MISSING_VARS} POSTGRES_PASSWORD"
    
    if [ -n "$MISSING_VARS" ]; then
        echo -e "${RED}[ERROR]${NC} Missing required variables in .env file:$MISSING_VARS"
        exit 1
    fi
fi

echo -e "${GREEN}[SUCCESS]${NC} Configuration loaded from .env file"

# Control-plane otomatik tespit (prod-cp-auto ise)
if [ "$MODE_ACTION" = "prod-cp-auto" ]; then
    echo ""
    echo -e "${BLUE}[INFO]${NC} Control-plane durumu tespit ediliyor..."
    
    if [ -z "$S3_BUCKET" ]; then
        echo -e "${YELLOW}[WARN]${NC} S3_BUCKET bulunamadi. Yeni kurulum yapilacak (prod-cp-a)"
        export MODE_ACTION="prod-cp-a"
    elif ! command -v aws &> /dev/null; then
        echo -e "${YELLOW}[WARN]${NC} AWS CLI bulunamadi. Yeni kurulum yapilacak (prod-cp-a)"
        export MODE_ACTION="prod-cp-a"
    elif ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}[WARN]${NC} jq bulunamadi. Yeni kurulum yapilacak (prod-cp-a)"
        export MODE_ACTION="prod-cp-a"
    else
        # Kume var mi kontrol et
        CLUSTER_EXISTS=false
        LEADER_EXISTS=false
        SNAPSHOT_EXISTS=false
        
        # Leader info kontrolu
        LEADER_INFO=$(aws s3 cp "s3://${S3_BUCKET}/current-leader.json" - 2>/dev/null || echo "")
        if [ -n "$LEADER_INFO" ]; then
            CLUSTER_EXISTS=true
            LEADER_ID=$(echo "$LEADER_INFO" | jq -r '.leader_id // ""' 2>/dev/null || echo "")
            LAST_HEARTBEAT=$(echo "$LEADER_INFO" | jq -r '.last_heartbeat // ""' 2>/dev/null || echo "")
            
            if [ -n "$LAST_HEARTBEAT" ]; then
                # Heartbeat kontrolu (son 5 dakika icinde) - macOS icin date komutu farkli
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    HEARTBEAT_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_HEARTBEAT" +%s 2>/dev/null || echo "0")
                else
                    HEARTBEAT_EPOCH=$(date -d "$LAST_HEARTBEAT" +%s 2>/dev/null || echo "0")
                fi
                NOW_EPOCH=$(date +%s)
                TIME_DIFF=$((NOW_EPOCH - HEARTBEAT_EPOCH))
                TIME_DIFF_MIN=$((TIME_DIFF / 60))
                
                if [ $TIME_DIFF_MIN -lt 5 ]; then
                    LEADER_EXISTS=true
                    echo -e "${GREEN}[INFO]${NC} Kume mevcut ve lider aktif (heartbeat: ${TIME_DIFF_MIN} dakika once)"
                else
                    echo -e "${YELLOW}[INFO]${NC} Kume mevcut ama lider aktif degil (heartbeat: ${TIME_DIFF_MIN} dakika once)"
                fi
            else
                echo -e "${YELLOW}[INFO]${NC} Kume mevcut ama lider heartbeat bilgisi yok"
            fi
        else
            echo -e "${CYAN}[INFO]${NC} Kume bulunamadi (current-leader.json yok)"
        fi
        
        # Snapshot kontrolu
        SNAPSHOT_COUNT=$(aws s3 ls "s3://${S3_BUCKET}/k3s/snapshots/" --recursive 2>/dev/null | grep "\.db$" | wc -l || echo "0")
        if [ "$SNAPSHOT_COUNT" -gt 0 ]; then
            SNAPSHOT_EXISTS=true
            echo -e "${GREEN}[INFO]${NC} Snapshot bulundu ($SNAPSHOT_COUNT adet)"
        else
            echo -e "${YELLOW}[INFO]${NC} Snapshot bulunamadi"
        fi
        
        # Otomatik aksiyon secimi
        if [ "$CLUSTER_EXISTS" = false ]; then
            # a. Kume yoksa: yeni control-plane kur
            echo ""
            echo -e "${GREEN}[AUTO]${NC} Secilen aksiyon: Yeni control-plane kurulumu (prod-cp-a)"
            echo "  - Kume bulunamadi"
            echo "  - Tum servisler baslatilacak (leader+worker bu makine)"
            export MODE_ACTION="prod-cp-a"
        elif [ "$CLUSTER_EXISTS" = true ] && [ "$LEADER_EXISTS" = false ]; then
            # b. Kume varsa ama lider yoksa: snapshot'tan restore (yoksa yeni kur)
            if [ "$SNAPSHOT_EXISTS" = true ]; then
                echo ""
                echo -e "${GREEN}[AUTO]${NC} Secilen aksiyon: Snapshot'tan restore (prod-cp-c1)"
                echo "  - Kume mevcut ama lider aktif degil"
                echo "  - Snapshot bulundu, state korunarak restore edilecek"
                export MODE_ACTION="prod-cp-c1"
            else
                echo ""
                echo -e "${YELLOW}[AUTO]${NC} Secilen aksiyon: Yeni control-plane kurulumu (prod-cp-c2)"
                echo "  - Kume mevcut ama lider aktif degil"
                echo "  - Snapshot bulunamadi, yeni kurulum yapilacak (veri kaybi riski)"
                export MODE_ACTION="prod-cp-c2"
            fi
        elif [ "$CLUSTER_EXISTS" = true ] && [ "$LEADER_EXISTS" = true ]; then
            # c. Kume varsa ve lider varsa: state tasi, restore et, node'lari bagla
            echo ""
            echo -e "${GREEN}[AUTO]${NC} Secilen aksiyon: State tasima ve restore (prod-cp-b)"
            echo "  - Kume mevcut ve lider aktif"
            echo "  - State S3'ten tasinacak, snapshot'tan restore edilecek"
            echo "  - Mevcut node'lar yeni control-plane'e baglanacak (state korunur)"
            export MODE_ACTION="prod-cp-b"
        fi
        
        echo ""
        echo -e "${CYAN}Devam etmek icin Enter'a basin...${NC}"
        read -r
    fi
fi

# Development mode: Docker Compose
if [ "$MODE_ACTION" = "dev" ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
    PROJECT_DIR="$PROJECT_ROOT/FinansAsistan"
    
    if [ -d "$PROJECT_DIR" ]; then
        COMPOSE_FILE="$PROJECT_DIR/docker-compose.dev.yml"
        if [ -f "$COMPOSE_FILE" ]; then
            echo -e "${BLUE}[INFO]${NC} Local project found. Starting development environment..."
            cd "$PROJECT_DIR"
            
            docker compose -f docker-compose.dev.yml up -d --build
            
            if [ $? -eq 0 ]; then
                echo ""
                echo -e "${BLUE}[INFO]${NC} Waiting for PostgreSQL to be ready..."
                sleep 5
                
                # Production veritabanının son yedeğini restore et (izole database ile)
                if [ -n "$S3_BUCKET" ] && [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ] && command -v aws &> /dev/null && aws s3 ls "s3://${S3_BUCKET}/postgres/backups/" &>/dev/null 2>&1; then
                    echo -e "${BLUE}[INFO]${NC} Restoring production database backup (isolated dev database)..."
                    LATEST_BACKUP=$(aws s3 ls "s3://${S3_BUCKET}/postgres/backups/" --recursive | sort | tail -n 1 | awk '{print $4}')
                    
                    if [ -n "$LATEST_BACKUP" ]; then
                        echo -e "${BLUE}[INFO]${NC} Found backup: $LATEST_BACKUP"
                        for i in {1..30}; do
                            if docker compose -f docker-compose.dev.yml exec -T postgres pg_isready -U finans &>/dev/null 2>&1; then
                                break
                            fi
                            sleep 2
                        done
                        
                        BACKUP_FILE="/tmp/postgres_backup_dev.sql.gz"
                        aws s3 cp "s3://${S3_BUCKET}/${LATEST_BACKUP}" "$BACKUP_FILE"
                        docker compose -f docker-compose.dev.yml exec -T postgres bash -c "dropdb -U finans FinansAsistan || true" 2>/dev/null
                        docker compose -f docker-compose.dev.yml exec -T postgres bash -c "createdb -U finans FinansAsistan" 2>/dev/null
                        gunzip -c "$BACKUP_FILE" | docker compose -f docker-compose.dev.yml exec -T postgres psql -U finans -d FinansAsistan 2>/dev/null || true
                        rm -f "$BACKUP_FILE"
                        echo -e "${GREEN}[SUCCESS]${NC} Production database backup restored"
                    fi
                else
                    echo -e "${YELLOW}[WARN]${NC} AWS CLI not available or no backup found, using fresh database"
                fi
                
                echo ""
                echo -e "${GREEN}[SUCCESS]${NC} Development environment started!"
                echo ""
                echo -e "${CYAN}Services:${NC}"
                echo "  Frontend:  http://localhost:9999"
                echo "  Backend:   http://localhost:5000"
                echo "  PostgreSQL: localhost:5432 (isolated dev database)"
                exit 0
            else
                echo -e "${RED}[ERROR]${NC} Failed to start Docker Compose!"
                exit 1
            fi
        fi
    fi
    echo -e "${BLUE}[INFO]${NC} Local project not found. Downloading from GitHub..."
fi

# Production mode: Continue with install script
# AWS Token oluştur (install script'ine geçirmek için)
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    AWS_TOKEN_BASE64=$(echo -n "{\"accessKeyId\":\"$AWS_ACCESS_KEY_ID\",\"secretAccessKey\":\"$AWS_SECRET_ACCESS_KEY\",\"region\":\"$AWS_REGION\"}" | base64)
else
    AWS_TOKEN_BASE64=""
fi

# Tüm secrets'leri environment variable olarak export et
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

# Register leadership before installation (production only)
if [ "$MODE_ACTION" != "dev" ] && [ -n "$S3_BUCKET" ] && [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ] && command -v aws &> /dev/null && command -v jq &> /dev/null; then
    echo -e "${BLUE}[INFO]${NC} Registering leadership in S3..."
    
    if curl -s --max-time 1 http://169.254.169.254/latest/meta-data/instance-id &> /dev/null; then
        LEADER_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
        LEADER_TYPE="ec2"
    else
        LEADER_ID=$(hostname)
        LEADER_TYPE="physical"
    fi
    
    LEADER_INFO=$(jq -n \
        --arg leader_id "$LEADER_ID" \
        --arg leader_type "$LEADER_TYPE" \
        --arg registered_at "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --arg last_heartbeat "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{
            leader_id: $leader_id,
            leader_type: $leader_type,
            registered_at: $registered_at,
            last_heartbeat: $last_heartbeat
        }')
    
    echo "$LEADER_INFO" | aws s3 cp - "s3://${S3_BUCKET}/current-leader.json" \
        --content-type "application/json" 2>/dev/null && {
        echo -e "${GREEN}[SUCCESS]${NC} Leadership registered in S3"
        echo -e "${BLUE}[INFO]${NC}   Leader ID: ${LEADER_ID}"
        echo -e "${BLUE}[INFO]${NC}   Leader Type: ${LEADER_TYPE}"
    } || echo -e "${YELLOW}[WARN]${NC} Failed to register leadership (will be registered by install script)"
fi

# GitHub'dan install script'ini indir ve kur
echo -e "${BLUE}[INFO]${NC} Downloading installer script from GitHub..."
GITHUB_TOKEN="$ACCESS_TOKEN_GITHUB"
if [ -n "$AWS_TOKEN_BASE64" ] && [ -n "$S3_BUCKET" ]; then
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

