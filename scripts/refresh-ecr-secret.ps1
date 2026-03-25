# ════════════════════════════════════════════════════════════
# FinansAsistan - ECR Secret Refresh Script (PowerShell)
# Refreshes ECR authentication token in Kubernetes
# ════════════════════════════════════════════════════════════

param(
    [string]$Namespace = "finans-asistan",
    [string]$SecretName = "ecr-registry-secret"
)

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

# Check required tools
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Error "kubectl is not installed"
    exit 1
}

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI is not installed"
    Write-Info "Install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
}

# Get AWS region and account ID from environment or secrets
$AWS_REGION = $env:AWS_REGION
$AWS_ACCOUNT_ID = $env:AWS_ACCOUNT_ID

if (-not $AWS_REGION) {
    Write-Warn "AWS_REGION not set, trying to get from Kubernetes secret..."
    $AWS_REGION = kubectl get secret app-secrets -n $Namespace -o jsonpath='{.data.AWS_REGION}' 2>$null | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
}

if (-not $AWS_ACCOUNT_ID) {
    Write-Warn "AWS_ACCOUNT_ID not set, trying to get from Kubernetes secret..."
    $AWS_ACCOUNT_ID = kubectl get secret app-secrets -n $Namespace -o jsonpath='{.data.AWS_ACCOUNT_ID}' 2>$null | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
}

if (-not $AWS_REGION -or -not $AWS_ACCOUNT_ID) {
    Write-Error "AWS_REGION and AWS_ACCOUNT_ID must be set"
    Write-Info "Set environment variables:"
    Write-Host "  `$env:AWS_REGION = 'eu-central-1'"
    Write-Host "  `$env:AWS_ACCOUNT_ID = '050907117703'"
    exit 1
}

$ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

Write-Info "Refreshing ECR secret: $SecretName"
Write-Info "Namespace: $Namespace"
Write-Info "ECR Registry: $ECR_REGISTRY"
Write-Info "AWS Region: $AWS_REGION"

# Get ECR login password
Write-Info "Getting ECR login password..."
try {
    $ECR_PASSWORD = aws ecr get-login-password --region $AWS_REGION 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to get ECR password"
        Write-Host $ECR_PASSWORD
        exit 1
    }
    Write-Success "ECR password obtained (valid for 12 hours)"
} catch {
    Write-Error "Failed to get ECR password: $_"
    exit 1
}

# Create docker config JSON
$DOCKER_CONFIG_JSON = @{
    auths = @{
        $ECR_REGISTRY = @{
            username = "AWS"
            password = $ECR_PASSWORD
        }
    }
} | ConvertTo-Json -Compress

# Base64 encode
$DOCKER_CONFIG_B64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($DOCKER_CONFIG_JSON))

# Create or update secret
Write-Info "Creating/updating Kubernetes secret..."
kubectl create secret docker-registry $SecretName `
    --docker-server=$ECR_REGISTRY `
    --docker-username=AWS `
    --docker-password=$ECR_PASSWORD `
    --namespace=$Namespace `
    --dry-run=client -o yaml | kubectl apply -f - 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Success "ECR secret updated successfully"
    Write-Info "Secret will be used by pods to pull images from ECR"
    Write-Info "Token is valid for 12 hours"
} else {
    Write-Error "Failed to update ECR secret"
    exit 1
}

Write-Success "ECR secret refresh completed!"
Write-Info "Pods should now be able to pull images from ECR"
Write-Info "Check pod status with: kubectl get pods -n $Namespace"

