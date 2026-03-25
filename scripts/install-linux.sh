#!/bin/bash
# ════════════════════════════════════════════════════════════
# FinansAsistan - One-Line Linux Installer
# GitHub'dan script'i indirir, tüm bağımlılıkları kurar ve çalıştırır
# ════════════════════════════════════════════════════════════

set -euo pipefail

TOKEN="${1:-}"
AWS_TOKEN="${2:-}"
AWS_PROFILE="${3:-default}"
S3_BUCKET_OVERRIDE="${4:-}"

if [ -z "$TOKEN" ]; then
    echo "Usage: $0 <GITHUB_TOKEN> [AWS_TOKEN_BASE64] [AWS_PROFILE] [S3_BUCKET]"
    exit 1
fi

TOKEN="$(printf '%s' "$TOKEN" | tr -d '\r\n')"
TOKEN="${TOKEN#GITHUB_ACCESS_TOKEN=}"
TOKEN="${TOKEN#token }"
TOKEN="$(printf '%s' "$TOKEN" | xargs)"

if [ -z "$TOKEN" ]; then
    echo "[ERROR] GitHub token gereklidir"
    exit 1
fi

echo ""
echo "═══════════════════════════════════════════════════════════"
echo "  FinansAsistan - One-Line Installer"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Hydrate AWS credentials from base64 encoded JSON
hydrate_aws_credentials() {
    local encoded_token="$1"
    local profile="$2"

    if [ -z "$encoded_token" ]; then
        return 0
    fi

    local clean_token
    clean_token="$(printf '%s' "$encoded_token" | tr -d '\r\n')"
    clean_token="${clean_token#AWS_TOKEN=}"
    clean_token="${clean_token//[[:space:]]/}"

    local py_bin=""
    if command_exists python3; then
        py_bin="python3"
    elif command_exists python; then
        py_bin="python"
    else
        echo "[ERROR] Python is required to parse AWS token. Please install python3." >&2
        return 1
    }

    local credentials_path="$HOME/.aws/credentials"
    local py_script="
import base64, json, sys, os, configparser

token, profile, cred_path = sys.argv[1:4]

try:
    decoded = base64.b64decode(token).decode('utf-8')
    data = json.loads(decoded)
except Exception as exc:
    print(f'ERROR:{exc}')
    sys.exit(1)

access = data.get('accessKeyId') or data.get('access_key_id')
secret = data.get('secretAccessKey') or data.get('secret_access_key')
session = data.get('sessionToken') or data.get('session_token') or ''
region = data.get('region') or ''

if not access or not secret:
    print('ERROR:accessKeyId and secretAccessKey are required')
    sys.exit(1)

os.makedirs(os.path.dirname(cred_path), exist_ok=True)

config = configparser.RawConfigParser()
config.optionxform = str
if os.path.exists(cred_path):
    config.read(cred_path)
if not config.has_section(profile):
    config.add_section(profile)

config.set(profile, 'aws_access_key_id', access)
config.set(profile, 'aws_secret_access_key', secret)
if session:
    config.set(profile, 'aws_session_token', session)
else:
    if config.has_option(profile, 'aws_session_token'):
        config.remove_option(profile, 'aws_session_token')
if region:
    config.set(profile, 'region', region)

with open(cred_path, 'w') as fh:
    config.write(fh)

print(access)
print(secret)
print(session)
print(region)
"

    local output
    output="$("$py_bin" -c "$py_script" "$clean_token" "$profile" "$credentials_path")" || {
        echo "[ERROR] Failed to parse AWS token: $output" >&2
        return 1
    }

    if printf '%s' "$output" | grep -q '^ERROR:'; then
        echo "[ERROR] Failed to parse AWS token: $output" >&2
        return 1
    fi

    IFS=$'\n' read -r access_key secret_key session_token region <<<"$output"

    export AWS_ACCESS_KEY_ID="$access_key"
    export AWS_SECRET_ACCESS_KEY="$secret_key"
    [ -n "$session_token" ] && export AWS_SESSION_TOKEN="$session_token"
    [ -n "$region" ] && export AWS_DEFAULT_REGION="$region"

    echo "[SUCCESS] AWS credentials injected from token"
}

# 1. Check and install Git
echo "[INFO] Checking Git installation..."
if ! command_exists git; then
    echo "[WARN] Git not found. Installing..."
    if command_exists apt-get; then
        sudo apt-get update
        sudo apt-get install -y git
    elif command_exists yum; then
        sudo yum install -y git
    elif command_exists dnf; then
        sudo dnf install -y git
    elif command_exists pacman; then
        sudo pacman -S --noconfirm git
    else
        echo "[ERROR] Cannot install Git automatically. Please install Git manually."
        exit 1
    fi
fi
echo "[SUCCESS] Git found: $(git --version)"

# 2. Check Docker (setup script will install if needed)
echo "[INFO] Checking Docker installation..."
if ! command_exists docker; then
    echo "[WARN] Docker not found. Will be installed by setup script."
else
    echo "[SUCCESS] Docker found: $(docker --version)"
fi

# 3. Check AWS CLI (setup script will install if needed)
echo "[INFO] Checking AWS CLI installation..."
if ! command_exists aws; then
    echo "[WARN] AWS CLI not found. Will be installed by setup script if needed."
else
    echo "[SUCCESS] AWS CLI found: $(aws --version)"
fi

# 3.0. Check and install ArgoCD CLI (required for production)
install_argocd_cli() {
    echo "[INFO] Installing ArgoCD CLI..."
    
    # Check if already installed
    if command_exists argocd; then
        if argocd version --client >/dev/null 2>&1; then
            echo "[SUCCESS] ArgoCD CLI already installed: $(argocd version --client 2>&1 | head -n1)"
            return 0
        fi
    fi
    
    # Get latest version
    local version
    version=$(curl -s https://api.github.com/repos/argoproj/argo-cd/releases/latest | grep -oP '"tag_name": "\K[^"]*' || echo "v3.2.0")
    
    # Determine architecture
    local arch="amd64"
    if [ "$(uname -m)" = "aarch64" ] || [ "$(uname -m)" = "arm64" ]; then
        arch="arm64"
    fi
    
    # Download and install
    local install_dir="$HOME/.local/bin"
    mkdir -p "$install_dir"
    
    local download_url="https://github.com/argoproj/argo-cd/releases/download/${version}/argocd-linux-${arch}"
    local output_path="${install_dir}/argocd"
    
    echo "[INFO] Downloading ArgoCD CLI from GitHub..."
    if curl -sSL -o "$output_path" "$download_url"; then
        chmod +x "$output_path"
        
        # Add to PATH if not already there
        if [[ ":$PATH:" != *":$install_dir:"* ]]; then
            export PATH="$install_dir:$PATH"
            echo "export PATH=\"$install_dir:\$PATH\"" >> "$HOME/.bashrc"
            echo "[INFO] Added $install_dir to PATH"
        fi
        
        # Verify installation
        if "$output_path" version --client >/dev/null 2>&1; then
            echo "[SUCCESS] ArgoCD CLI installed successfully"
            return 0
        fi
    fi
    
    echo "[WARN] Failed to install ArgoCD CLI automatically"
    echo "[INFO] You can install it manually from: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
    return 1
}

# Check ArgoCD CLI (both dev and production mode)
echo ""
echo "[INFO] Checking ArgoCD CLI installation..."
if command_exists argocd; then
    if argocd version --client >/dev/null 2>&1; then
        echo "[SUCCESS] ArgoCD CLI found: $(argocd version --client 2>&1 | head -n1)"
    else
        echo "[WARN] ArgoCD CLI found but not working properly. Attempting to reinstall..."
        install_argocd_cli
    fi
else
    echo "[WARN] ArgoCD CLI not found. Installing..."
    install_argocd_cli
fi
echo ""

# 3.1 Hydrate AWS credentials if token provided
if ! hydrate_aws_credentials "$AWS_TOKEN" "$AWS_PROFILE"; then
    exit 1
fi

# 3.2 Override S3 bucket if provided
if [ -n "$S3_BUCKET_OVERRIDE" ]; then
    export S3_BUCKET="$S3_BUCKET_OVERRIDE"
    echo "[INFO] Using custom S3 bucket: $S3_BUCKET"
fi

# 4. Download setup script from GitHub using API
echo "[INFO] Downloading setup script from GitHub..."
SETUP_SCRIPT="/tmp/setup-linux-docker.sh"

# Get file content from GitHub API (base64 encoded)
API_RESPONSE=$(curl -s -H "Authorization: token $TOKEN" \
     -H "Accept: application/vnd.github.v3+json" \
     "https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/setup-linux-docker.sh")

# Extract and decode base64 content
SCRIPT_CONTENT=$(echo "$API_RESPONSE" | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -d)

if [ -z "$SCRIPT_CONTENT" ]; then
    echo "[ERROR] Failed to download setup script"
    echo "[INFO] Make sure your token has 'repo' scope"
    exit 1
fi

echo "$SCRIPT_CONTENT" > "$SETUP_SCRIPT"
chmod +x "$SETUP_SCRIPT"
echo "[SUCCESS] Setup script downloaded"

# 5. Clone repository
echo "[INFO] Cloning repository..."
PROJECT_DIR="FinansAsistan"

if [ -d "$PROJECT_DIR" ]; then
    echo "[WARN] Project directory exists. Skipping removal (disabled for safety)..."
    # rm -rf "$PROJECT_DIR"  # DISABLED: File deletion is disabled for safety
fi

git clone "https://$TOKEN@github.com/JstLearn/FinansAsistan.git" "$PROJECT_DIR" || {
    echo "[ERROR] Failed to clone repository"
    echo "[INFO] Make sure Git is installed and token is valid"
    exit 1
}

echo "[SUCCESS] Repository cloned"

# 6. Change to project directory
cd "$PROJECT_DIR"

# 7. Run setup script
echo "[INFO] Running setup script..."
"$SETUP_SCRIPT"

# Cleanup
rm -f "$SETUP_SCRIPT"

