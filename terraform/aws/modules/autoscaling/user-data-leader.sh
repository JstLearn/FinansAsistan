#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - EC2 Leader User Data Script
# k3s server installation + bootstrap (first instance)
# R6G Large ARM64 Linux spot instance support
# ════════════════════════════════════════════════════════════

set -euo pipefail

# Variables (passed from Terraform templatefile)
S3_BUCKET="${s3_bucket}"
AWS_REGION="${AWS_REGION}"

# Detect architecture (ARM64 for R6G, x86_64 for other instances)
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
        # ARM64 architecture (R6G instances)
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
echo "🌍 AWS Region: $${AWS_REGION}"

# Get instance ID
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
echo "🆔 Instance ID: $${INSTANCE_ID}"

# Check for k3s snapshot in S3 (for restore scenario)
echo "🔍 Checking for k3s snapshot in S3..."
SNAPSHOT_KEY=$(aws s3 ls "s3://$${S3_BUCKET}/k3s/snapshots/" --recursive 2>/dev/null | \
    grep "\.db$" | sort -r | head -n 1 | awk '{print $4}' || echo "")

if [ -n "$SNAPSHOT_KEY" ]; then
    echo "📥 Found k3s snapshot: $SNAPSHOT_KEY"
    echo "🔄 Restoring k3s cluster from snapshot..."
    
    # Download snapshot
    SNAPSHOT_FILE="/tmp/etcd-snapshot.db"
    if aws s3 cp "s3://$${S3_BUCKET}/$SNAPSHOT_KEY" "$SNAPSHOT_FILE" 2>/dev/null; then
        echo "✅ Snapshot downloaded"
        
        # Install k3s with snapshot restore
        echo "🚀 Installing k3s server with snapshot restore..."
        curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
            --disable traefik \
            --write-kubeconfig-mode 644 \
            --tls-san $(curl -s ifconfig.me 2>/dev/null || echo localhost) \
            --node-label leader=true \
            --node-taint leader=true:NoSchedule \
            --cluster-reset \
            --cluster-reset-restore-path=$SNAPSHOT_FILE" sh -
        
        # Clean up snapshot file
        rm -f "$SNAPSHOT_FILE"
        echo "✅ k3s cluster restored from snapshot"
    else
        echo "⚠️  Failed to download snapshot, proceeding with fresh install"
        SNAPSHOT_KEY=""
    fi
fi

# Install k3s SERVER (fresh install if no snapshot)
if [ -z "$SNAPSHOT_KEY" ]; then
    echo "🚀 Installing k3s server (leader node - fresh install)..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --disable traefik \
    --write-kubeconfig-mode 644 \
    --tls-san $(curl -s ifconfig.me 2>/dev/null || echo localhost) \
    --node-label leader=true \
    --node-taint leader=true:NoSchedule" sh -
fi

# Wait for k3s server to be ready
echo "⏳ Waiting for k3s server to start..."
MAX_WAIT=300
ELAPSED=0
while ! systemctl is-active --quiet k3s && [ $ELAPSED -lt $MAX_WAIT ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $((ELAPSED % 15)) -eq 0 ]; then
        echo "  Still waiting for k3s server... ($ELAPSED/$MAX_WAIT seconds)"
    fi
done

if systemctl is-active --quiet k3s; then
    echo "✅ k3s server started successfully"
    
    # Setup kubectl
    mkdir -p ~/.kube
    sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config 2>/dev/null || true
    sudo chown $(whoami):$(whoami) ~/.kube/config 2>/dev/null || true
    export KUBECONFIG=~/.kube/config
    
    # Wait for Kubernetes API to be ready
    echo "⏳ Waiting for Kubernetes API to be ready..."
    ELAPSED=0
    while ! kubectl get nodes &>/dev/null && [ $ELAPSED -lt $MAX_WAIT ]; do
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done
    
    if kubectl get nodes &>/dev/null; then
        echo "✅ Kubernetes API is ready"
    else
        echo "⚠️  Kubernetes API may not be fully ready yet"
    fi
else
    echo "❌ k3s server failed to start after $MAX_WAIT seconds"
    systemctl status k3s || true
    journalctl -u k3s --no-pager -n 50 || true
    exit 1
fi

# Register as leader in S3 (includes k3s join info for worker nodes)
echo "📝 Registering as leader in S3..."
INSTANCE_IP=$(curl -s ifconfig.me 2>/dev/null || echo "localhost")
K3S_TOKEN=""
K3S_SERVER_URL=""

# Get k3s token if available
if [ -f /var/lib/rancher/k3s/server/node-token ]; then
    K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/node-token)
    K3S_SERVER_URL="https://${INSTANCE_IP}:6443"
fi

LEADER_INFO=$(cat <<EOF
{
  "leader_id": "$${INSTANCE_ID}",
  "leader_type": "ec2",
  "node_ip": "${INSTANCE_IP}",
  "registered_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_heartbeat": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "k3s_token": "${K3S_TOKEN}",
  "k3s_server_url": "${K3S_SERVER_URL}"
}
EOF
)

echo "$LEADER_INFO" | aws s3 cp - "s3://$${S3_BUCKET}/current-leader.json" \
    --content-type "application/json" 2>/dev/null || {
    echo "⚠️  Failed to register leader in S3 (will retry in bootstrap)"
}

echo "✅ Leader registered in S3 (includes k3s join info)"

# ════════════════════════════════════════════════════════════
# Heartbeat Loop (Background)
# ════════════════════════════════════════════════════════════
cat <<'EOF' > /usr/local/bin/heartbeat.sh
#!/bin/bash
S3_BUCKET="$1"
INSTANCE_ID="$2"

while true; do
    # Only update if we are still the registered leader
    CURRENT_LEADER=$(aws s3 cp "s3://${S3_BUCKET}/current-leader.json" - 2>/dev/null | jq -r '.leader_id' || echo "")
    
    if [ "$CURRENT_LEADER" = "$INSTANCE_ID" ]; then
        # Update heartbeat timestamp
        UPDATED_INFO=$(aws s3 cp "s3://${S3_BUCKET}/current-leader.json" - 2>/dev/null | \
            jq --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.last_heartbeat = $now')
        
        echo "$UPDATED_INFO" | aws s3 cp - "s3://${S3_BUCKET}/current-leader.json" \
            --content-type "application/json" 2>/dev/null
    else
         echo "⚠️  We are no longer the leader ($CURRENT_LEADER). Physical machine took over. Terminating..."
         # Shutdown and terminate this instance (ASG will try to restart if desired_capacity > 0, 
         # but ideally the physical leader will set desired_capacity to 0)
         sudo shutdown -h now
         exit 0
     fi
    sleep 15
done
EOF

chmod +x /usr/local/bin/heartbeat.sh
nohup /usr/local/bin/heartbeat.sh "${S3_BUCKET}" "${INSTANCE_ID}" > /var/log/heartbeat.log 2>&1 &

# Download and run bootstrap script
echo "📥 Downloading bootstrap script from S3..."
mkdir -p /opt/finans-asistan
cd /opt/finans-asistan

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

# Load environment variables from S3 (QUICK_START/.env file)
echo "📥 Loading environment variables from S3..."
ENV_FILE="/tmp/.env"
if aws s3 cp "s3://$${S3_BUCKET}/FinansAsistan/QUICK_START/.env" "$ENV_FILE" 2>/dev/null; then
    echo "✅ QUICK_START/.env file downloaded from S3"
    # Export all variables from .env file
    set -a
    source "$ENV_FILE"
    set +a
    echo "✅ Environment variables loaded from QUICK_START/.env file"
else
    echo "⚠️  QUICK_START/.env file not found in S3, trying secrets.json.encrypted..."
    # Fallback: Try to load from encrypted secrets file
    if aws s3 cp "s3://$${S3_BUCKET}/github-secrets/secrets.json.encrypted" /tmp/secrets.json.encrypted 2>/dev/null; then
        echo "✅ Encrypted secrets file downloaded, will be decrypted by bootstrap script"
    else
        echo "⚠️  No secrets file found in S3"
        echo "   Bootstrap script will try to load from environment variables"
    fi
fi

# Set required environment variables (minimum for bootstrap to work)
export LEADER_TYPE="ec2"
export LEADER_ID="$INSTANCE_ID"
export S3_BUCKET="$${S3_BUCKET}"
export AWS_REGION="$${AWS_REGION}"
export MACHINE_ID="$INSTANCE_ID"
export MACHINE_TYPE="ec2"

# Run bootstrap script (non-blocking, in background)
echo "🚀 Starting bootstrap script..."
nohup bash "$BOOTSTRAP_SCRIPT" > /var/log/bootstrap.log 2>&1 &

echo "✅ Bootstrap script started in background"
echo "   Script: $BOOTSTRAP_SCRIPT"
echo "   Logs: /var/log/bootstrap.log"
echo "   Tail logs: tail -f /var/log/bootstrap.log"

