#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - EC2 User Data Script
# k3s agent join + leadership check + bootstrap
# t4g.small ARM64 Linux spot instance support
# ════════════════════════════════════════════════════════════

set -euo pipefail

# Variables (passed from Terraform templatefile)
K3S_TOKEN_TF="${k3s_token}"  # Fallback if S3 read fails (optional)
K3S_SERVER_URL_TF="${k3s_server_url}"  # Fallback if S3 read fails (optional)
S3_BUCKET="${s3_bucket}"
AWS_REGION="${AWS_REGION}"

# Detect architecture (ARM64 for t4g.small, x86_64 for other instances)
ARCH=$(uname -m)
echo "🔍 Detected architecture: $ARCH"

# Update system packages
echo "📦 Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl wget unzip jq ca-certificates gnupg lsb-release >/dev/null 2>&1

# Install AWS CLI if not present (architecture-aware)
if ! command -v aws &> /dev/null; then
    echo "📥 Installing AWS CLI for architecture: $ARCH"
    if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        # ARM64 architecture (t4g.small instances)
        curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
    else
        # x86_64 architecture
        curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    fi
    unzip -q awscliv2.zip
    ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli
    rm -rf awscliv2.zip aws/
    echo "✅ AWS CLI installed successfully"
else
    echo "✅ AWS CLI already installed"
fi

# Verify jq installation
if ! command -v jq &> /dev/null; then
    echo "❌ jq installation failed - required for JSON parsing"
    exit 1
fi

# Configure AWS credentials (from instance profile)
export AWS_DEFAULT_REGION="${AWS_REGION}"
echo "🌍 AWS Region: ${AWS_REGION}"

# Get k3s join info from current-leader.json (preferred) or use Terraform variables (fallback)
echo "📥 Getting k3s join info from current-leader.json..."
K3S_TOKEN=""
K3S_SERVER_URL=""
MAX_RETRIES=30
RETRY_COUNT=0

while [ -z "$K3S_TOKEN" ] || [ -z "$K3S_SERVER_URL" ]; do
    LEADER_INFO=$(aws s3 cp "s3://$${S3_BUCKET}/current-leader.json" - 2>/dev/null || echo "")
    
    if [ -n "$LEADER_INFO" ]; then
        # Extract k3s token and server URL from current-leader.json
        K3S_TOKEN_FROM_S3=$(echo "$LEADER_INFO" | jq -r '.k3s_token // ""' 2>/dev/null || echo "")
        K3S_SERVER_URL_FROM_S3=$(echo "$LEADER_INFO" | jq -r '.k3s_server_url // ""' 2>/dev/null || echo "")
        
        if [ -n "$K3S_TOKEN_FROM_S3" ] && [ -n "$K3S_SERVER_URL_FROM_S3" ]; then
            K3S_TOKEN="$K3S_TOKEN_FROM_S3"
            K3S_SERVER_URL="$K3S_SERVER_URL_FROM_S3"
            echo "✅ k3s join info loaded from current-leader.json"
            break
        fi
    fi
    
    # Fallback to Terraform variables if provided
    if [ -n "$${K3S_TOKEN_TF}" ] && [ -n "$${K3S_SERVER_URL_TF}" ]; then
        K3S_TOKEN="$${K3S_TOKEN_TF}"
        K3S_SERVER_URL="$${K3S_SERVER_URL_TF}"
        echo "✅ k3s join info loaded from Terraform variables"
        break
    fi
    
    # Retry if not found
    RETRY_COUNT=$((RETRY_COUNT + 1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Failed to get k3s join info after $MAX_RETRIES retries"
        echo "   Please ensure leader node has registered in S3 with k3s token"
        exit 1
    fi
    
    echo "⏳ Waiting for k3s join info in S3... (attempt $RETRY_COUNT/$MAX_RETRIES)"
    sleep 10
done

# Install k3s agent (supports ARM64 architecture)
echo "🚀 Installing k3s agent..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --token $${K3S_TOKEN} --server $${K3S_SERVER_URL}" sh -

# Wait for k3s agent to be ready
echo "⏳ Waiting for k3s agent to start..."
MAX_WAIT=300
ELAPSED=0
while ! systemctl is-active --quiet k3s-agent && [ $ELAPSED -lt $MAX_WAIT ]; do
  sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $((ELAPSED % 15)) -eq 0 ]; then
        echo "  Still waiting for k3s agent... ($ELAPSED/$MAX_WAIT seconds)"
    fi
done

if systemctl is-active --quiet k3s-agent; then
echo "✅ k3s agent joined successfully"
else
    echo "❌ k3s agent failed to start after $MAX_WAIT seconds"
    systemctl status k3s-agent || true
    journalctl -u k3s-agent --no-pager -n 50 || true
    exit 1
fi

# Check if physical machine exists (EC2 should not be leader if physical exists)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
LEADER_TYPE="ec2"

# Check current leader from S3
CURRENT_LEADER=$(aws s3 cp "s3://$${S3_BUCKET}/current-leader.json" - 2>/dev/null || echo "")
SHOULD_BE_LEADER=false

if [ -z "$CURRENT_LEADER" ]; then
    # No leader exists - EC2 can be temporary leader
    SHOULD_BE_LEADER=true
    echo "No leader found - EC2 will be temporary leader"
else
    CURRENT_LEADER_TYPE=$(echo "$CURRENT_LEADER" | jq -r '.leader_type // "unknown"' 2>/dev/null || echo "unknown")
    if [ "$CURRENT_LEADER_TYPE" != "physical" ]; then
        # Current leader is EC2 or unknown - this EC2 can take over
        SHOULD_BE_LEADER=true
        echo "Current leader is not physical - EC2 can be temporary leader"
    else
        echo "Physical machine leader exists - EC2 will not be leader"
    fi
fi

# If EC2 should be leader, run bootstrap script
if [ "$SHOULD_BE_LEADER" = true ]; then
    echo "Running bootstrap script as temporary leader..."
    
    # Create working directory
    mkdir -p /opt/finans-asistan
    cd /opt/finans-asistan
    
    # Download bootstrap script from S3
    echo "📥 Downloading bootstrap script from S3..."
    if aws s3 cp "s3://$${S3_BUCKET}/scripts/bootstrap.sh" /tmp/bootstrap.sh 2>/dev/null; then
        echo "✅ Bootstrap script downloaded from S3"
        chmod +x /tmp/bootstrap.sh
        BOOTSTRAP_SCRIPT="/tmp/bootstrap.sh"
    else
        echo "⚠️  Failed to download from S3, trying GitHub fallback..."
        # Fallback: GitHub'dan çek (eğer erişilebilirse)
        if command -v git &> /dev/null; then
            if git clone https://github.com/JstLearn/FinansAsistan.git /tmp/finans-repo 2>/dev/null; then
                cp /tmp/finans-repo/scripts/bootstrap.sh /tmp/bootstrap.sh
                chmod +x /tmp/bootstrap.sh
                BOOTSTRAP_SCRIPT="/tmp/bootstrap.sh"
                echo "✅ Bootstrap script downloaded from GitHub (fallback)"
            else
                echo "❌ Failed to download bootstrap script from both S3 and GitHub"
                exit 1
            fi
        else
            echo "❌ Git not available and S3 download failed"
            exit 1
        fi
    fi
    
    # Set environment variables
    export LEADER_TYPE="ec2"
    export LEADER_ID="$INSTANCE_ID"
    export S3_BUCKET="$${S3_BUCKET}"
    export AWS_REGION="${AWS_REGION}"
    
    # Run bootstrap script (non-blocking, in background)
    nohup bash "$BOOTSTRAP_SCRIPT" > /var/log/bootstrap.log 2>&1 &
    
    echo "✅ Bootstrap script started in background"
    echo "   Script: $BOOTSTRAP_SCRIPT"
    echo "   Logs: /var/log/bootstrap.log"
fi

