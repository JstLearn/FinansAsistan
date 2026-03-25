# ============================================================
# FinansAsistan - Bootstrap Script for Windows (Docker Desktop Kubernetes)
# One-command deployment and disaster recovery
# ============================================================

# Use Continue for error handling - we want to deploy all resources even if one fails
$ErrorActionPreference = "Continue"

# Colors
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

# Check prerequisites
function Check-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    # Docker check
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-Error "Docker is not installed. Please install Docker Desktop first."
        exit 1
    }
    
    # Docker running check
    try {
        docker ps 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Docker is not running. Please start Docker Desktop."
            exit 1
        }
    } catch {
        Write-Error "Docker is not running. Please start Docker Desktop."
        exit 1
    }
    
    # kubectl check
    if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-Error "kubectl is not found. Docker Desktop Kubernetes may not be enabled."
        Write-Info "Please enable Kubernetes in Docker Desktop Settings → Kubernetes → Enable Kubernetes"
        exit 1
    }
    
    # Kubernetes cluster check
    try {
        $clusterInfo = kubectl cluster-info 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $clusterInfo -match "Unable to connect|connection refused") {
            Write-Error "Kubernetes cluster is not available. Docker Desktop Kubernetes may not be enabled."
            Write-Info "Please enable Kubernetes in Docker Desktop Settings → Kubernetes → Enable Kubernetes"
            exit 1
        }
    } catch {
        Write-Error "Kubernetes cluster is not available. Docker Desktop Kubernetes may not be enabled."
        Write-Info "Please enable Kubernetes in Docker Desktop Settings → Kubernetes → Enable Kubernetes"
        exit 1
    }
    
    Write-Success "Prerequisites check passed"
}

# Cleanup Docker Compose containers (if any)
function Cleanup-DockerCompose {
    Write-Info "Checking for Docker Compose containers to clean up..."
    
    # Check if any FinansAsistan containers are running
    $allContainers = docker ps -a --format "{{.Names}}" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Could not check Docker containers (Docker may not be running)"
        return
    }
    
    $finansContainers = $allContainers | Where-Object { $_ -match "finans-" }
    
    if ($finansContainers) {
        Write-Warn "Found Docker Compose containers: $($finansContainers -join ', ')"
        Write-Info "Stopping and removing Docker Compose containers..."
        
        # Try to stop using compose files if they exist
        $projectDir = Split-Path $PSScriptRoot -Parent
        $devCompose = Join-Path $projectDir "docker-compose.dev.yml"
        $prodCompose = Join-Path $projectDir "docker-compose.prod.yml"
        
        if (Test-Path $devCompose) {
            try {
                $ErrorActionPreference = "SilentlyContinue"
                docker compose -f $devCompose down --remove-orphans --volumes *>$null
                if ($LASTEXITCODE -ne 0) {
                    docker-compose -f $devCompose down --remove-orphans --volumes *>$null
                }
                $ErrorActionPreference = "Stop"
            } catch {
                $ErrorActionPreference = "Stop"
            }
        }
        
        if (Test-Path $prodCompose) {
            try {
                $ErrorActionPreference = "SilentlyContinue"
                docker compose -f $prodCompose down --remove-orphans --volumes *>$null
                if ($LASTEXITCODE -ne 0) {
                    docker-compose -f $prodCompose down --remove-orphans --volumes *>$null
                }
                $ErrorActionPreference = "Stop"
            } catch {
                $ErrorActionPreference = "Stop"
            }
        }
        
        # Force stop and remove any remaining FinansAsistan containers
        foreach ($container in $finansContainers) {
            if ($container) {
                try {
                    $ErrorActionPreference = "SilentlyContinue"
                    docker stop $container *>$null
                    docker rm -f $container *>$null
                    $ErrorActionPreference = "Stop"
                } catch {
                    $ErrorActionPreference = "Stop"
                }
            }
        }
        
        Start-Sleep -Seconds 2
        Write-Success "Docker Compose containers cleaned up"
    } else {
        Write-Info "No Docker Compose containers found"
    }
}

# Check AWS credentials
function Check-AwsCredentials {
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Warn "AWS CLI not found. Some features may not work."
        return $false
    }
    
    try {
        $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
        if ($identity.Account) {
            Write-Success "AWS credentials verified (Account: $($identity.Account))"
            return $true
        }
    } catch {
        Write-Warn "AWS credentials not configured or invalid"
        return $false
    }
    
    return $false
}

# Get secrets from GitHub Secrets via S3 (exported by GitHub Actions)
function Get-GitHubSecretsFromS3 {
    param(
        [string]$S3Bucket,
        [string]$GitHubToken
    )
    
    $secrets = @{}
    
    if ([string]::IsNullOrWhiteSpace($S3Bucket)) {
        Write-Error "S3_BUCKET is required to fetch secrets from S3"
        return $secrets
    }
    
    Write-Info "Fetching secrets from S3 (exported by GitHub Actions)..."
    
    try {
        # Try to download encrypted secrets from S3
        $secretsPath = "s3://$S3Bucket/github-secrets/secrets.json.encrypted"
        $tempFile = Join-Path $env:TEMP "secrets.json.encrypted"
        
        # Download encrypted secrets file
        aws s3 cp $secretsPath $tempFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Encrypted secrets file not found in S3. GitHub Actions may not have exported secrets yet."
            return $secrets
        }
        
        # Decrypt secrets (using GitHub token as decryption key)
        # Note: This is a simple encryption, for production use proper encryption
        $encryptedContent = Get-Content $tempFile -Raw
        $decryptedContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($encryptedContent))
        $secrets = $decryptedContent | ConvertFrom-Json
        
        Remove-Item $tempFile -ErrorAction SilentlyContinue
        
        Write-Info "Secrets downloaded and decrypted from S3"
        return $secrets
        
    } catch {
        Write-Warn "Failed to fetch secrets from S3: $_"
        Write-Warn "Make sure GitHub Actions workflow has exported secrets to S3"
        return $secrets
    }
}

# Get secrets from GitHub Secrets via API (check existence only)
function Get-GitHubSecrets {
    param(
        [string]$GitHubToken,
        [string]$Repository = "JstLearn/FinansAsistan"
    )
    
    $secrets = @{}
    
    if ([string]::IsNullOrWhiteSpace($GitHubToken)) {
        Write-Error "GitHub token (ACCESS_TOKEN_GITHUB) is required to fetch secrets from GitHub API"
        return $secrets
    }
    
    Write-Info "Connecting to GitHub API to verify secrets..."
    
    try {
        # GitHub Secrets API endpoint
        $apiUrl = "https://api.github.com/repos/$Repository/actions/secrets"
        
        $headers = @{
            "Authorization" = "token $GitHubToken"
            "Accept" = "application/vnd.github.v3+json"
        }
        
        # Get list of available secrets
        $response = Invoke-RestMethod -Uri $apiUrl -Headers $headers -Method Get -ErrorAction Stop
        
        Write-Info "Connected to GitHub API - Found $($response.secrets.Count) secrets in repository"
        
        # Return secret names (we can't get values via API)
        $secretNames = $response.secrets | ForEach-Object { $_.name }
        Write-Info "Available secrets: $($secretNames -join ', ')"
        
        return @{ SecretNames = $secretNames }
        
    } catch {
        Write-Error "Failed to access GitHub Secrets API: $_"
        Write-Error "Make sure ACCESS_TOKEN_GITHUB has 'repo' and 'actions:read' permissions"
        return $secrets
    }
}

# Load .env file from QUICK_START directory only (for local development)
function Load-EnvFile {
    # Try multiple paths to find QUICK_START/.env
    $envFile = Join-Path $PSScriptRoot "..\QUICK_START\.env"
    if (-not (Test-Path $envFile)) {
        $envFile = Join-Path (Split-Path -Parent $PSScriptRoot) "QUICK_START\.env"
    }
    if (-not (Test-Path $envFile)) {
        $projectDir = (Get-Location).Path
        $envFile = Join-Path $projectDir "QUICK_START\.env"
    }
    
    if (Test-Path $envFile) {
        $absolutePath = (Resolve-Path $envFile).Path
        Write-Info "Loading .env file from QUICK_START directory: $absolutePath"
        $envContent = Get-Content $envFile
        
        foreach ($line in $envContent) {
            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) {
                continue
            }
            
            # Parse KEY=VALUE format (handle quoted values)
            if ($line -match '^\s*([^#=]+?)\s*=\s*(.+?)\s*$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                
                # Remove quotes if present
                if ($value -match '^["''](.*)["'']$') {
                    $value = $matches[1]
                }
                
                # Set as environment variable (only if not already set)
                if (-not [Environment]::GetEnvironmentVariable($key, "Process")) {
                    [Environment]::SetEnvironmentVariable($key, $value, "Process")
                }
            }
        }
        Write-Success ".env file loaded from QUICK_START directory"
        return $true
    }
    return $false
}

# Generate Kubernetes secrets directly in the cluster from environment variables, DO NOT WRITE FILES
function Generate-KubernetesSecrets {
    Write-Info "Loading secrets..."
    
    # Never create secrets file on disk; create/update secret directly in cluster
    
    # Check if we're running in GitHub Actions
    $isGitHubActions = $env:GITHUB_ACTIONS -eq "true"
    
    # Priority: GitHub Actions secrets > .env file > existing environment variables
    if (-not $isGitHubActions) {
        # Try to load .env file for local development
        $envLoaded = Load-EnvFile
        if ($envLoaded) {
            Write-Info "Using secrets from .env file (local development)"
        } else {
            Write-Info "No .env file found, using existing environment variables"
        }
    } else {
        Write-Info "Running in GitHub Actions - using GitHub Secrets (environment variables)"
    }
    
    $envVars = @{}
    $requiredSecrets = @(
        "BACKUP_INTERVAL",
        "S3_BUCKET",
        "AWS_ACCOUNT_ID",
        "AWS_ACCESS_KEY_ID",
        "JWT_SECRET",
        "AWS_REGION",
        "AWS_SECRET_ACCESS_KEY",
        "EMAIL_PASS",
        "EMAIL_USER",
        "SMTP_HOST",
        "SMTP_PORT",
        "SMTP_SSL",
        "ACCESS_TOKEN_GITHUB",
        "POSTGRES_DB",
        "POSTGRES_USER",
        "POSTGRES_PASSWORD"
    )
    
    # Read from environment variables (from GitHub Secrets or .env file)
        foreach ($secret in $requiredSecrets) {
            $value = [Environment]::GetEnvironmentVariable($secret, "Process")
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $envVars[$secret] = $value
        }
    }
    
    # Verify critical secrets are present
    $criticalSecrets = @("AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "S3_BUCKET", "JWT_SECRET", "POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD")
    $missingSecrets = @()
    foreach ($secret in $criticalSecrets) {
        if (-not $envVars.ContainsKey($secret) -or [string]::IsNullOrWhiteSpace($envVars[$secret])) {
            $missingSecrets += $secret
        }
    }
    
    if ($missingSecrets.Count -gt 0) {
        Write-Error "Critical secrets are missing:"
        foreach ($secret in $missingSecrets) {
            Write-Error "  - $secret"
        }
        Write-Error "All secrets must be set in GitHub Actions workflow as environment variables."
        exit 1
    }
    
    Write-Info "All required secrets found (from GitHub Actions environment variables)"
    
    # Set default values if not provided
    if (-not $envVars["BACKUP_INTERVAL"]) {
        $envVars["BACKUP_INTERVAL"] = "300"
    }
    if (-not $envVars["AWS_REGION"]) {
        $envVars["AWS_REGION"] = "eu-central-1"
    }
    # CORS_ORIGINS - check environment variable first, then use default
    $corsOrigins = [Environment]::GetEnvironmentVariable("CORS_ORIGINS", "Process")
    if ([string]::IsNullOrWhiteSpace($corsOrigins)) {
        # Default: allow all origins (for development)
        $corsOrigins = "*"
    }
    $envVars["CORS_ORIGINS"] = $corsOrigins
    
    # Add Kubernetes service URLs (these are not in GitHub Secrets, they're Kubernetes-specific)
    # Redis service name in Kubernetes: redis (from 03-redis-deployment.yaml)
    $envVars["redis-url"] = "redis://redis:6379"
    # Kafka service name in Kubernetes: kafka-cluster-kafka-bootstrap (from Strimzi Kafka)
    $envVars["kafka-brokers"] = "kafka-cluster-kafka-bootstrap:9092"
    
    # Also add JWT_SECRET with lowercase key (deployment expects jwt-secret)
    if ($envVars.ContainsKey("JWT_SECRET")) {
        $envVars["jwt-secret"] = $envVars["JWT_SECRET"]
    }
    
    # Also add EMAIL keys with lowercase (deployment expects email-user and email-pass)
    if ($envVars.ContainsKey("EMAIL_USER")) {
        $envVars["email-user"] = $envVars["EMAIL_USER"]
    }
    if ($envVars.ContainsKey("EMAIL_PASS")) {
        $envVars["email-pass"] = $envVars["EMAIL_PASS"]
    }
    
    # Build kubectl command to create/update secret directly
    $kubectlArgs = @("create","secret","generic","app-secrets","-n","finans-asistan")
    
    # Add all required secrets
    foreach ($key in $requiredSecrets) {
        if ($envVars.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace($envVars[$key])) {
            $value = $envVars[$key]
            $kubectlArgs += "--from-literal=$key=$value"
        }
    }
    
    # Add Kubernetes-specific keys (redis-url, kafka-brokers, jwt-secret, email-user, email-pass, CORS_ORIGINS)
    $k8sSpecificKeys = @("redis-url", "kafka-brokers", "jwt-secret", "email-user", "email-pass", "CORS_ORIGINS")
    foreach ($key in $k8sSpecificKeys) {
        if ($envVars.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace($envVars[$key])) {
            $value = $envVars[$key]
            $kubectlArgs += "--from-literal=$key=$value"
        }
    }
    # Ensure namespace is Active before creating secrets
    $namespacePhase = kubectl get namespace finans-asistan -o jsonpath='{.status.phase}' --ignore-not-found 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($namespacePhase) -or $namespacePhase -ne "Active") {
        Write-Warn "Namespace 'finans-asistan' is not Active (phase: $namespacePhase). Waiting..."
        $maxWait = 15
        $waited = 0
        while ($waited -lt $maxWait) {
            $phase = kubectl get namespace finans-asistan -o jsonpath='{.status.phase}' --ignore-not-found 2>&1
            if ($LASTEXITCODE -eq 0 -and $phase -eq "Active") {
                Write-Success "Namespace is now Active"
                break
            }
            Start-Sleep -Seconds 1
            $waited++
        }
        
        if ($waited -ge $maxWait) {
            Write-Error "Namespace 'finans-asistan' is not Active after $maxWait seconds (phase: $namespacePhase). Cannot create secrets."
            exit 1
        }
    }
    
    Write-Info "Creating/updating 'app-secrets' in cluster..."
    $secretYaml = & kubectl @kubectlArgs --dry-run=client -o yaml 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($secretYaml)) {
        Write-Error "Failed to render 'app-secrets' yaml via kubectl: $secretYaml"
        exit 1
    }
    $applyOut = $secretYaml | kubectl apply -f - 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to apply 'app-secrets': $applyOut"
        exit 1
    }
    Write-Success "Kubernetes secret 'app-secrets' applied"
}

# Create namespace (if it doesn't exist)
function Create-Namespace {
    Write-Info "Ensuring 'finans-asistan' namespace exists..."
    
    # Check if namespace already exists and its phase
    $namespacePhase = kubectl get namespace finans-asistan -o jsonpath='{.status.phase}' --ignore-not-found 2>&1
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($namespacePhase) -and $namespacePhase -eq "Active") {
        Write-Success "Namespace 'finans-asistan' already exists and is Active"
        return
    }
    
    # If namespace is in Terminating state, wait for it to be deleted
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($namespacePhase) -and $namespacePhase -eq "Terminating") {
        Write-Warn "Namespace 'finans-asistan' is in Terminating state. Waiting for deletion..."
        
        # Remove finalizers to force termination
        # Kubernetes namespaces can be blocked by either metadata.finalizers or spec.finalizers
        # We must check which ones exist before attempting to remove them, as JSON Patch "remove"
        # operations fail if the target path doesn't exist (per RFC 6902)
        try {
            # First, read the namespace to check which finalizers exist
            # Note: Namespace might be deleted during this process, so handle NotFound gracefully
            $namespaceJson = kubectl get namespace finans-asistan -o json --ignore-not-found 2>&1
            $namespaceGetError = $namespaceJson | Where-Object { $_ -match "NotFound|not found" }
            
            # If namespace was already deleted, that's fine - we can proceed to create it
            if ($LASTEXITCODE -ne 0 -or $namespaceGetError -or [string]::IsNullOrWhiteSpace($namespaceJson)) {
                Write-Info "Namespace already deleted or not found, will create new one"
            } else {
                $nsObj = $namespaceJson | ConvertFrom-Json
                $patchOperations = @()
                
                # Only add remove operation for metadata.finalizers if it exists
                if ($nsObj.metadata.finalizers -and $nsObj.metadata.finalizers.Count -gt 0) {
                    $patchOperations += @{ op = "remove"; path = "/metadata/finalizers" }
                }
                
                # Only add remove operation for spec.finalizers if it exists
                if ($nsObj.spec -and $nsObj.spec.finalizers -and $nsObj.spec.finalizers.Count -gt 0) {
                    $patchOperations += @{ op = "remove"; path = "/spec/finalizers" }
                }
                
                # Apply JSON patch only if there are operations to perform
                if ($patchOperations.Count -gt 0) {
                    # Build JSON patch array manually to ensure correct format
                    $patchArray = @()
                    foreach ($op in $patchOperations) {
                        $patchArray += "{`"op`":`"$($op.op)`",`"path`":`"$($op.path)`"}"
                    }
                    $patchJson = "[$($patchArray -join ',')]"
                    
                    $tempPatchFile = Join-Path $env:TEMP "namespace-finalize-patch-$(Get-Random).json"
                    $patchJson | Out-File -FilePath $tempPatchFile -Encoding utf8 -NoNewline
                    
                    # Patch namespace to remove finalizers
                    kubectl patch namespace finans-asistan --type='json' --patch-file=$tempPatchFile 2>&1 | Out-Null
                    
                    Remove-Item -Path $tempPatchFile -Force -ErrorAction SilentlyContinue
                }
                
                # Also try to finalize using raw API endpoint (same pattern as build-and-deploy.yml)
                # This ensures both finalizer fields are cleared, even if patch failed
                $needsUpdate = $false
                
                # Clear metadata.finalizers
                if ($nsObj.metadata.finalizers) {
                    $nsObj.metadata.finalizers = @()
                    $needsUpdate = $true
                }
                
                # Clear spec.finalizers (if it exists)
                if ($nsObj.spec -and $nsObj.spec.finalizers) {
                    $nsObj.spec.finalizers = @()
                    $needsUpdate = $true
                }
                
                # Only send finalize request if there were finalizers to clear
                if ($needsUpdate) {
                    # Convert to JSON and write to temp file without BOM
                    # PowerShell ConvertTo-Json adds BOM when piping, so we write to file first
                    $jsonContent = $nsObj | ConvertTo-Json -Depth 10
                    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                    $tempFinalizeFile = Join-Path $env:TEMP "namespace-finalize-$(Get-Random).json"
                    try {
                        # Write JSON to file without BOM
                        [System.IO.File]::WriteAllText($tempFinalizeFile, $jsonContent, $utf8NoBom)
                        # Use cmd.exe /c type to pipe file content to kubectl (avoids PowerShell BOM issues)
                        cmd.exe /c "type `"$tempFinalizeFile`" | kubectl replace --raw /api/v1/namespaces/finans-asistan/finalize -f -" 2>&1 | Out-Null
                    } finally {
                        Remove-Item -Path $tempFinalizeFile -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        } catch {
            Write-Warn "Failed to remove finalizers: $_"
        }
        
        # Wait for namespace to be fully deleted (max 15 seconds)
        $maxWait = 15
        $waited = 0
        while ($waited -lt $maxWait) {
            # Use --ignore-not-found to avoid errors when namespace is already deleted
            $checkPhase = kubectl get namespace finans-asistan -o jsonpath='{.status.phase}' --ignore-not-found 2>&1
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($checkPhase)) {
                Write-Info "Namespace deleted after $waited seconds"
                break
            }
            Start-Sleep -Seconds 1
            $waited++
        }
        
        if ($waited -ge $maxWait) {
            # Final check: namespace might have been deleted during wait
            $finalCheck = kubectl get namespace finans-asistan -o name --ignore-not-found 2>&1
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($finalCheck)) {
                Write-Info "Namespace was deleted during wait period"
            } else {
                Write-Warn "Namespace still terminating after $maxWait seconds, forcing deletion..."
                kubectl delete namespace finans-asistan --grace-period=0 --force 2>&1 | Out-Null
                Start-Sleep -Seconds 2
            }
        }
    }
    
    # Check if namespace still exists after cleanup
    # Use --ignore-not-found to avoid errors when namespace doesn't exist (which is expected after deletion)
    $namespaceCheck = kubectl get namespace finans-asistan -o name --ignore-not-found 2>&1
    if ($LASTEXITCODE -eq 0 -and $namespaceCheck -and $namespaceCheck -match "namespace/finans-asistan") {
        Write-Success "Namespace 'finans-asistan' already exists"
        return
    }
    
    # Namespace doesn't exist, create it
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    $namespaceFile = Join-Path $k8sDir "00-namespace.yaml"
    if (Test-Path $namespaceFile) {
        # Use kubectl create instead of apply to avoid annotation warnings
        $output = kubectl create -f $namespaceFile 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Namespace created from k8s/00-namespace.yaml"
        } elseif ($output -match "already exists") {
            Write-Success "Namespace already exists"
        } else {
            # If create fails, try apply (will patch annotation)
            kubectl apply -f $namespaceFile 2>&1 | Out-Null
            Write-Success "Namespace created/updated from k8s/00-namespace.yaml"
        }
    } else {
        # Fallback: create namespace directly
        kubectl create namespace finans-asistan 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Namespace created directly"
        } elseif ($LASTEXITCODE -ne 0) {
            # Namespace might already exist, verify
            $check = kubectl get namespace finans-asistan -o name --ignore-not-found 2>&1
            if ($LASTEXITCODE -eq 0 -and $check -and $check -match "namespace/finans-asistan") {
                Write-Success "Namespace already exists"
            } else {
                Write-Warn "Failed to create namespace, but continuing..."
            }
        }
    }
    # Wait for namespace to be ready and Active
    $maxWait = 15
    $waited = 0
    while ($waited -lt $maxWait) {
        $phase = kubectl get namespace finans-asistan -o jsonpath='{.status.phase}' --ignore-not-found 2>&1
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($phase) -and $phase -eq "Active") {
            Write-Success "Namespace 'finans-asistan' is Active and ready"
            return
        }
        Start-Sleep -Seconds 1
        $waited++
    }
    
    if ($waited -ge $maxWait) {
        Write-Warn "Namespace not Active after $maxWait seconds, but continuing..."
    }
}

# Deploy PostgreSQL
function Deploy-PostgreSQL {
    Write-Info "Deploying PostgreSQL..."
    
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    
    # Namespace should already exist from Create-Namespace, but verify
    $namespaceCheck = kubectl get namespace finans-asistan -o name --ignore-not-found 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($namespaceCheck) -or -not ($namespaceCheck -match "namespace/finans-asistan")) {
        # Namespace doesn't exist, create it
        $namespaceFile = Join-Path $k8sDir "00-namespace.yaml"
        if (Test-Path $namespaceFile) {
            kubectl create -f $namespaceFile 2>&1 | Out-Null
        } else {
            kubectl create namespace finans-asistan 2>&1 | Out-Null
        }
    }
    
    # Wait for namespace to be ready
    Start-Sleep -Seconds 2
    
    # Ensure app-secrets exists FIRST (from env vars), without writing files
    Write-Info "Ensuring 'app-secrets' exists in cluster..."
    Generate-KubernetesSecrets
    # Short wait for API propagation
    Start-Sleep -Seconds 2
    
    # Skip postgres-credentials secret. Postgres will read POSTGRES_* directly from app-secrets.
    Write-Info "Skipping 'postgres-credentials' check (using app-secrets POSTGRES_* keys)"
    
    # We no longer require 'postgres-credentials' secret. Postgres reads POSTGRES_* from app-secrets.
    # Check available storage classes
    Write-Info "Checking available storage classes..."
    $storageClasses = kubectl get storageclass -o jsonpath='{.items[*].metadata.name}' 2>&1
    Write-Info "Available storage classes: $storageClasses"
    
    # Check if hostpath storage class exists, if not create it for Docker Desktop
    if ($storageClasses -notmatch "hostpath") {
        Write-Info "Creating hostpath storage class for Docker Desktop..."
        $hostpathStorageClass = @"
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: hostpath
provisioner: docker.io/hostpath
volumeBindingMode: Immediate
"@
        $hostpathStorageClass | kubectl apply -f - 2>&1 | Out-Null
        Write-Success "hostpath storage class created"
    }
    
    # Proceed with PostgreSQL deployment (POSTGRES_* taken from app-secrets)
    
    # Deploy PostgreSQL
    $postgresFile = Join-Path $k8sDir "01-postgres-statefulset.yaml"
    if (Test-Path $postgresFile) {
        # Update storage class if needed (before applying)
        # Use JSON parsing instead of complex JSONPath to avoid PowerShell issues
        try {
            $scJson = kubectl get storageclass -o json 2>&1 | ConvertFrom-Json
            $defaultStorageClass = $null
            foreach ($sc in $scJson.items) {
                if ($sc.metadata.annotations.'storageclass.kubernetes.io/is-default-class' -eq "true") {
                    $defaultStorageClass = $sc.metadata.name
                    break
                }
            }
        if ($defaultStorageClass -and $storageClasses -notmatch "hostpath") {
            Write-Info "Using default storage class: $defaultStorageClass"
            # Temporarily update YAML to use default storage class
            $postgresContent = Get-Content $postgresFile -Raw
            $postgresContent = $postgresContent -replace 'storageClassName: hostpath', "storageClassName: $defaultStorageClass"
            $postgresContent | Set-Content $postgresFile -NoNewline
            }
        } catch {
            Write-Warn "Could not determine default storage class, using hostpath: $_"
        }
        
        Write-Info "Applying PostgreSQL StatefulSet..."
        # Capture both stdout and stderr, and exit code
        $applyOutput = kubectl apply -f $postgresFile 2>&1 | Out-String
        $applyExitCode = $LASTEXITCODE
        
        # Check if there are real errors (not just warnings)
        if ($applyExitCode -ne 0) {
            # Check if it's just a warning about SessionAffinity (which is harmless for headless services)
            if ($applyOutput -match "SessionAffinity.*ignored.*headless" -or 
                $applyOutput -match "Warning:.*SessionAffinity.*ignored") {
                Write-Warn "Warning about SessionAffinity in headless service (this is harmless, continuing...)"
                # Don't exit, continue with deployment
            } else {
            Write-Error "Failed to apply PostgreSQL StatefulSet!"
            Write-Error "Error output: $applyOutput"
            exit 1
            }
        } elseif ($applyOutput -match "Warning:.*SessionAffinity.*ignored") {
            # Even if exit code is 0, log the warning but continue
            Write-Warn "Warning about SessionAffinity in headless service (this is harmless, continuing...)"
        }
        
        Write-Success "PostgreSQL StatefulSet applied successfully"
        
        Write-Info "Waiting for PostgreSQL to be ready..."
        Write-Info "This may take 1-2 minutes (initializing database)..."
        
        $maxWait = 300  # 5 minutes
        $elapsed = 0
        $checkInterval = 5
        $postgresReady = $false
        
        while ($elapsed -lt $maxWait) {
            # Show progress
            Write-Progress -Activity "Waiting for PostgreSQL" -Status "Checking pod status... (${elapsed}s elapsed)"
            
            # Check if PostgreSQL pod is ready using JSON parsing (more reliable than JSONPath)
            try {
                $podJson = kubectl get pods -l app=postgres -n finans-asistan -o json 2>&1 | ConvertFrom-Json
                if ($podJson.items -and $podJson.items.Count -gt 0) {
                    $pod = $podJson.items[0]
                    $podStatus = $pod.status.phase
                    $readyCondition = $pod.status.conditions | Where-Object { $_.type -eq "Ready" } | Select-Object -First 1
                    $podReady = $readyCondition.status -eq "True"
                    
                    if ($podReady -and $podStatus -eq "Running") {
                $postgresReady = $true
                Write-Progress -Activity "Waiting for PostgreSQL" -Status "Ready!" -Completed
                break
                    }
                }
            } catch {
                # If JSON parsing fails, continue waiting
                Write-Debug "Pod status check failed: $_"
            }
            
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval
        }
        
        Write-Progress -Activity "Waiting for PostgreSQL" -Completed
        
        if ($postgresReady) {
            Write-Success "PostgreSQL is ready"
        } else {
            # Final check with kubectl wait
            kubectl wait --for=condition=ready pod -l app=postgres -n finans-asistan --timeout=30s 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "PostgreSQL is ready"
            } else {
                Write-Warn "PostgreSQL pod is not ready. Diagnosing issue..."
                
                # Check pod status
                Write-Info "Checking pod status..."
                kubectl get pods -l app=postgres -n finans-asistan 2>&1 | Out-Host
                
                # Check pod events
                $podName = kubectl get pods -l app=postgres -n finans-asistan --no-headers -o jsonpath='{.items[0].metadata.name}' 2>&1
                if ($podName) {
                    Write-Info "Pod events:"
                    kubectl describe pod $podName -n finans-asistan 2>&1 | Select-String -Pattern "Events:|Warning:|Error:|Status:" -Context 0,5 | Out-Host
                    
                    Write-Info "Pod logs (last 20 lines):"
                    kubectl logs $podName -n finans-asistan --tail=20 2>&1 | Out-Host
                }
                
                # Check if pod exists
                $podExists = kubectl get pods -l app=postgres -n finans-asistan --no-headers 2>&1
                if (-not $podExists) {
                    Write-Error "PostgreSQL pod does not exist. Checking StatefulSet..."
                    kubectl get statefulset postgres -n finans-asistan 2>&1 | Out-Host
                    kubectl describe statefulset postgres -n finans-asistan 2>&1 | Select-String -Pattern "Events:|Warning:|Error:" -Context 0,5 | Out-Host
                    
                    Write-Error "PostgreSQL deployment failed. Please check the issues above."
                    Write-Info "Common issues:"
                    Write-Info "  - nodeSelector mismatch (database label not found on nodes)"
                    Write-Info "  - PersistentVolumeClaim not available (storage class issue)"
                    Write-Info "  - Secret 'app-secrets' missing or POSTGRES_* keys absent"
                    Write-Info "  - Insufficient resources"
                } else {
                    Write-Warn "PostgreSQL may take longer to start. Pod is running but not ready yet."
                    Write-Info "This is normal for first-time initialization (can take 2-5 minutes)."
                }
            }
        }
    }
    
    Write-Success "PostgreSQL deployed"
    
}

# Deploy Kafka
function Deploy-Kafka {
    Write-Info "Deploying Kafka..."
    
    # Ensure Strimzi operator and CRDs are installed for namespace 'finans-asistan'
    Write-Info "Ensuring Strimzi (Kafka operator) and CRDs..."
    try {
        $installUrl = "https://strimzi.io/install/latest?namespace=finans-asistan"
        $installOutput = kubectl apply -f $installUrl -n finans-asistan 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Strimzi installation output: $installOutput"
        }
        Write-Info "Waiting for Strimzi CRDs to be established..."
        $crds = @("kafkas.kafka.strimzi.io","kafkatopics.kafka.strimzi.io","kafkausers.kafka.strimzi.io","kafkanodepools.kafka.strimzi.io")
        foreach ($crd in $crds) {
            Write-Info "Waiting for CRD: $crd"
            $waitOutput = kubectl wait --for=condition=Established ("crd/" + $crd) --timeout=120s 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "CRD $crd not ready: $waitOutput"
            }
        }
        Write-Success "Strimzi CRDs are ready"
    } catch {
        Write-Warn "Strimzi install/wait encountered an issue: $_"
    }
    
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    
    # Get active worker node count for Kafka replicas
    $nodes = kubectl get nodes --no-headers 2>&1
    if ($LASTEXITCODE -eq 0) {
        $nodeCount = ($nodes | Where-Object { $_ -notmatch "master|control-plane" } | Measure-Object -Line).Lines
        if ($nodeCount -eq 0) {
            $nodeCount = 1
        }
    } else {
        $nodeCount = 1
    }
    
    # Kafka replicas should be at least node_count
    $kafkaControllerReplicas = $nodeCount
    $kafkaBrokerReplicas = $nodeCount
    # For single node: use 1 controller (no quorum needed)
    # For multiple nodes: use minimum 3 controllers for KRaft quorum
    if ($nodeCount -eq 1) {
        $kafkaControllerReplicas = 1  # Single node: no quorum needed
    } else {
        # Multiple nodes: ensure odd number and minimum 3 for quorum
        if ($kafkaControllerReplicas % 2 -eq 0) {
            $kafkaControllerReplicas++
        }
        if ($kafkaControllerReplicas -lt 3) {
            $kafkaControllerReplicas = 3  # Minimum 3 for KRaft quorum
        }
    }
    
    Write-Info "Kafka Controller replicas: $kafkaControllerReplicas (ensures quorum)"
    Write-Info "Kafka Broker replicas: $kafkaBrokerReplicas (one per node)"
    
    $kafkaClusterFile = Join-Path $k8sDir "02-kafka-cluster.yaml"
    $kafkaNodePoolsFile = Join-Path $k8sDir "02a-kafka-nodepools.yaml"
    if (Test-Path $kafkaClusterFile) {
        # Apply Kafka cluster, show full output for debugging
        Write-Info "Applying Kafka cluster configuration..."
        $kafkaApplyOutput = kubectl apply -f $kafkaClusterFile 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Kafka cluster apply failed:"
            Write-Host $kafkaApplyOutput -ForegroundColor Red
            if ($kafkaApplyOutput -match 'Warning:.*deprecated') {
                Write-Warn "Deprecated API warning detected (can be ignored if migration is in progress)"
            } else {
                throw "Kafka cluster deployment failed: $kafkaApplyOutput"
            }
        } else {
            Write-Info "Kafka cluster configuration applied successfully"
        }
        if (Test-Path $kafkaNodePoolsFile) {
            # Wait for KafkaNodePool CRD to be established
            Write-Info "Ensuring KafkaNodePool CRD is ready..."
            $nodepoolCrdWait = kubectl wait --for=condition=Established crd/kafkanodepools.kafka.strimzi.io --timeout=60s 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                Write-Warn "KafkaNodePool CRD wait output: $nodepoolCrdWait"
            }
            
            # Apply Kafka nodepools first
            Write-Info "Applying Kafka NodePool configuration..."
            $nodepoolApplyOutput = kubectl apply -f $kafkaNodePoolsFile 2>&1 | Out-String
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Kafka NodePool apply failed:"
                Write-Host $nodepoolApplyOutput -ForegroundColor Red
                # Show detailed error information
                Write-Info "Checking KafkaNodePool CRD status..."
                kubectl get crd kafkanodepools.kafka.strimzi.io 2>&1 | Out-Host
                Write-Info "Checking Strimzi operator pods..."
                kubectl get pods -n finans-asistan -l name=strimzi-cluster-operator 2>&1 | Out-Host
                throw "Kafka NodePool deployment failed: $nodepoolApplyOutput"
            } else {
                Write-Info "Kafka NodePool configuration applied successfully"
            }
            # Then patch replicas using kubectl patch (simpler and more reliable)
            Start-Sleep -Seconds 3  # Wait for CRDs to be ready
            
            # Create patch files to avoid PowerShell string escaping issues
            $tempPatchDir = Join-Path $env:TEMP "kafka-patch-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempPatchDir -Force | Out-Null
            
            try {
                Write-Info "Patching Kafka Controller replicas to $kafkaControllerReplicas..."
                $controllerPatchJson = @"
[{"op":"replace","path":"/spec/replicas","value":$kafkaControllerReplicas}]
"@
                $controllerPatchFile = Join-Path $tempPatchDir "controller-patch.json"
                $controllerPatchJson | Out-File -FilePath $controllerPatchFile -Encoding UTF8 -NoNewline
                $controllerPatchOutput = kubectl patch kafkanodepool kafka-cluster-controllers -n finans-asistan --type='json' --patch-file=$controllerPatchFile 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) {
                    Write-Warn "Failed to patch Kafka Controller replicas:"
                    Write-Host $controllerPatchOutput -ForegroundColor Yellow
                    Write-Warn "Will use default replicas from manifest"
                } else {
                    Write-Info "Kafka Controller replicas patched successfully"
                }
                
                Write-Info "Patching Kafka Broker replicas to $kafkaBrokerReplicas..."
                $brokerPatchJson = @"
[{"op":"replace","path":"/spec/replicas","value":$kafkaBrokerReplicas}]
"@
                $brokerPatchFile = Join-Path $tempPatchDir "broker-patch.json"
                $brokerPatchJson | Out-File -FilePath $brokerPatchFile -Encoding UTF8 -NoNewline
                $brokerPatchOutput = kubectl patch kafkanodepool kafka-cluster-brokers -n finans-asistan --type='json' --patch-file=$brokerPatchFile 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) {
                    Write-Warn "Failed to patch Kafka Broker replicas:"
                    Write-Host $brokerPatchOutput -ForegroundColor Yellow
                    Write-Warn "Will use default replicas from manifest"
                } else {
                    Write-Info "Kafka Broker replicas patched successfully"
                }
            } finally {
                # Clean up temp files
                if (Test-Path $tempPatchDir) {
                    Remove-Item -Path $tempPatchDir -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        }
        
        Write-Info "Waiting for Kafka to be ready (no timeout, press Ctrl+C to abort)..."
        $elapsed = 0
        $checkInterval = 10
        $kafkaReady = $false
        while (-not $kafkaReady) {
            # Show heartbeat progress with elapsed time
            Write-Progress -Activity "Waiting for Kafka" -Status ("Initializing cluster... ({0}s elapsed)" -f $elapsed)
            
            # Check if Kafka cluster is ready (parse JSON to avoid jsonpath quoting issues on Windows)
            $kafkaJson = kubectl get kafka kafka-cluster -n finans-asistan -o json 2>&1 | Out-String
            try {
                $kobj = $kafkaJson | ConvertFrom-Json
                $cond = $null
                if ($kobj -and $kobj.status -and $kobj.status.conditions) {
                    $cond = ($kobj.status.conditions | Where-Object { $_.type -eq "Ready" }) | Select-Object -First 1
                }
                if ($cond -and $cond.status -eq "True") {
                    $kafkaReady = $true
                    Write-Progress -Activity "Waiting for Kafka" -Status "Ready!" -Completed
                    break
                }
            } catch {
                # ignore parse errors and keep waiting
            }

            # Periodic diagnostics every 60s to help identify issues
            if (($elapsed % 60) -eq 0 -and $elapsed -gt 0) {
                Write-Host "" ; Write-Info "Kafka diagnostics (t+$elapsed s):"
                Write-Info "  - Pods (finans-asistan):"
                kubectl get pods -n finans-asistan 2>&1 | Out-Host
                Write-Info "  - Kafka resource conditions:"
                kubectl get kafka kafka-cluster -n finans-asistan -o yaml 2>&1 | Select-String -Pattern "conditions:" -Context 0,6 | Out-Host
                Write-Info "  - Recent events (namespace finans-asistan):"
                kubectl get events -n finans-asistan --sort-by=.lastTimestamp 2>&1 | Select-Object -Last 10 | Out-Host
                Write-Info "  - Strimzi operator logs (last 50 lines):"
                $opPod = (kubectl get pods -n finans-asistan -l name=strimzi-cluster-operator -o jsonpath='{.items[0].metadata.name}' 2>$null)
                if ($opPod) { kubectl logs -n finans-asistan $opPod --tail=50 2>&1 | Out-Host }
            }
            
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval
        }
        
        Write-Progress -Activity "Waiting for Kafka" -Completed
        Write-Success "Kafka is ready"
    }
    
    $kafkaTopicsFile = Join-Path $k8sDir "03-kafka-topics.yaml"
    if (Test-Path $kafkaTopicsFile) {
        Write-Info "Deploying Kafka topics..."
        $applyOut = kubectl apply -f $kafkaTopicsFile 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) {
            if ($applyOut -match 'no matches for kind "KafkaTopic"') {
            Write-Warn "KafkaTopic CRD not ready yet. Retrying after short wait..."
            Start-Sleep -Seconds 10
            kubectl wait --for=condition=Established crd/kafkatopics.kafka.strimzi.io --timeout=120s 2>&1 | Out-Null
                $applyOut = kubectl apply -f $kafkaTopicsFile 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "Kafka topics deployment failed after retry:"
                    Write-Host $applyOut -ForegroundColor Red
                    # Don't throw - topics can be created later when Kafka is ready
                    Write-Warn "Kafka topics will be created when Kafka cluster is fully ready"
                } else {
                    Write-Info "Kafka topics deployed successfully"
                }
            } else {
                Write-Error "Kafka topics deployment failed:"
                Write-Host $applyOut -ForegroundColor Red
                # Don't throw - topics can be created later when Kafka is ready
                Write-Warn "Kafka topics will be created when Kafka cluster is fully ready"
            }
        } else {
            Write-Info "Kafka topics deployed successfully"
        }
    }
    
    Write-Success "Kafka deployed"
}

# Deploy Redis
function Deploy-Redis {
    Write-Info "Deploying Redis..."
    
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    $redisFile = Join-Path $k8sDir "10-redis.yaml"
    
    if (Test-Path $redisFile) {
        # Apply manifest; handle immutable PVC spec as non-fatal
        $applyOutput = kubectl apply -f $redisFile 2>&1
        $applyExit = $LASTEXITCODE
        if ($applyExit -ne 0) {
            if ($applyOutput -match "spec is immutable after creation") {
                Write-Warn "Redis PVC spec is immutable (already created). Continuing with existing claim."
                $global:LASTEXITCODE = 0
            } else {
                Write-Warn "kubectl apply for Redis returned non-zero exit code: $applyExit"
                Write-Warn "Output: $applyOutput"
            }
        } else {
            $global:LASTEXITCODE = 0
        }
        
        Write-Info "Waiting for Redis to be ready..."
        Write-Info "This usually takes 10-30 seconds..."
        
        $maxWait = 300  # 5 minutes
        $elapsed = 0
        $checkInterval = 5
        $redisReady = $false
        
        while ($elapsed -lt $maxWait) {
            # Show progress
            Write-Progress -Activity "Waiting for Redis" -Status "Starting... (${elapsed}s elapsed)"
            
            # Check if Redis pod is ready
            $redisJson = kubectl get pods -l app=redis -n finans-asistan -o json 2>&1 | Out-String
            $podStatus = ""
            $podReady = ""
            try {
                $r = $redisJson | ConvertFrom-Json
                if ($r -and $r.items -and $r.items.Count -gt 0) {
                    $podStatus = $r.items[0].status.phase
                    $cond = ($r.items[0].status.conditions | Where-Object { $_.type -eq "Ready" } | Select-Object -First 1)
                    if ($cond) { $podReady = $cond.status }
                }
            } catch {
                $podStatus = ""
                $podReady = ""
            }
            
            if ($podReady -eq "True" -and $podStatus -eq "Running") {
                $redisReady = $true
                Write-Progress -Activity "Waiting for Redis" -Status "Ready!" -Completed
                break
            }
            
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval
        }
        
        Write-Progress -Activity "Waiting for Redis" -Completed
        
        if ($redisReady) {
            Write-Success "Redis is ready"
        } else {
            # Final check with kubectl wait
            kubectl wait --for=condition=ready pod -l app=redis -n finans-asistan --timeout=30s 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Redis is ready"
            } else {
                Write-Warn "Redis may take longer to start"
            }
        }
    }
    
    Write-Success "Redis deployed"
}

# Create ECR image pull secret
function Create-ECRSecret {
    Write-Info "Creating ECR image pull secret..."
    
    if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
        Write-Warn "AWS CLI not found, skipping ECR secret creation"
        return $false
    }
    
    $awsRegion = if ($env:AWS_REGION) { $env:AWS_REGION } else { "eu-central-1" }
    
    # Set AWS credentials from environment variables if available (from .env file or GitHub Actions)
    if ($env:AWS_ACCESS_KEY_ID -and $env:AWS_SECRET_ACCESS_KEY) {
        Write-Info "Using AWS credentials from environment variables"
        
        # Force AWS CLI to use environment variables by disabling credentials/config files
        # This prevents AWS CLI from trying to read broken credentials file
        $originalCredentialsFile = $env:AWS_SHARED_CREDENTIALS_FILE
        $originalConfigFile = $env:AWS_CONFIG_FILE
        $originalProfile = $env:AWS_PROFILE
        
        # Set to non-existent files to force environment variable usage
        $env:AWS_SHARED_CREDENTIALS_FILE = "$env:TEMP\aws-credentials-nonexistent-$(Get-Random)"
        $env:AWS_CONFIG_FILE = "$env:TEMP\aws-config-nonexistent-$(Get-Random)"
        $env:AWS_PROFILE = ""
    } else {
        Write-Warn "AWS credentials not found in environment variables"
        Write-Warn "Make sure .env file is loaded or AWS credentials are set"
        return $false
    }
    
    try {
        # Try to get AWS account ID (using environment variables only)
        $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
        $awsAccountId = $identity.Account
        
        # If that fails, try using AWS_ACCOUNT_ID from environment
        if (-not $awsAccountId -and $env:AWS_ACCOUNT_ID) {
            $awsAccountId = $env:AWS_ACCOUNT_ID
            Write-Info "Using AWS_ACCOUNT_ID from environment: $awsAccountId"
        }
        
        if (-not $awsAccountId) {
            Write-Warn "Could not get AWS account ID, skipping ECR secret creation"
            Write-Warn "Set AWS_ACCOUNT_ID environment variable or fix AWS credentials"
            return $false
        }
        
        $ecrRegistry = "$awsAccountId.dkr.ecr.$awsRegion.amazonaws.com"
        Write-Info "ECR Registry: $ecrRegistry"
        
        # Export for use in Deploy-Applications
        $script:ECR_REGISTRY = $ecrRegistry
        
        # Get ECR login password (this generates a fresh token each time, valid for 12 hours)
        # AWS CLI will use environment variables (already set above)
        Write-Info "Getting ECR login password (fresh token)..."
        $ecrPassword = aws ecr get-login-password --region $awsRegion 2>&1
        if (-not $ecrPassword -or $LASTEXITCODE -ne 0) {
            Write-Warn "Could not get ECR password, skipping ECR secret creation"
            Write-Warn "Error: $ecrPassword"
            return $false
        }
        
        # Remove any error messages from output (password should be on last line)
        $ecrPassword = ($ecrPassword | Select-Object -Last 1).Trim()
        if (-not $ecrPassword -or $ecrPassword.Length -lt 100) {
            Write-Warn "ECR password seems invalid (too short), skipping ECR secret creation"
            return $false
        }
        
        # Ensure namespace exists (should already exist from Create-Namespace, but verify)
        $namespaceCheck = kubectl get namespace finans-asistan -o name --ignore-not-found 2>&1
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($namespaceCheck) -or -not ($namespaceCheck -match "namespace/finans-asistan")) {
            # Namespace doesn't exist, create it
            kubectl create namespace finans-asistan 2>&1 | Out-Null
        }
        
        # Delete existing ECR secret if it exists (to force recreation with fresh token)
        Write-Info "Removing existing ECR secret (if any) to create fresh one..."
        kubectl delete secret ecr-registry-secret -n finans-asistan --ignore-not-found 2>&1 | Out-Null
        
        # Create ECR registry secret using kubectl create secret docker-registry
        # This is more reliable than YAML, especially on Docker Desktop Kubernetes
        Write-Info "Creating ECR registry secret using kubectl create secret docker-registry..."
        $createOutput = kubectl create secret docker-registry ecr-registry-secret `
            --docker-server=$ecrRegistry `
            --docker-username=AWS `
            --docker-password=$ecrPassword `
            --namespace=finans-asistan 2>&1 | Out-String
        
        # If create fails (secret might still exist), try apply as fallback
        if ($LASTEXITCODE -ne 0) {
            # Check if it's just "already exists" error (which is fine)
            if ($createOutput -match "already exists") {
                Write-Info "ECR secret already exists, updating it..."
            } else {
                Write-Info "Create failed, trying apply with dry-run instead..."
            }
            # Use --server-side flag to avoid annotation warnings, or filter stderr
            $applyOutput = kubectl create secret docker-registry ecr-registry-secret `
                --docker-server=$ecrRegistry `
                --docker-username=AWS `
                --docker-password=$ecrPassword `
                --namespace=finans-asistan `
                --dry-run=client -o yaml | kubectl apply -f - 2>&1 | Where-Object { 
                    $_ -notmatch "Warning:" -and 
                    $_ -notmatch "missing.*annotation" -and 
                    $_ -notmatch "will be patched automatically"
                } | Out-String
            # Only treat as error if exit code is non-zero AND there are real errors (not just warnings)
            if ($LASTEXITCODE -ne 0) {
                $realErrors = $applyOutput | Where-Object { 
                    $_ -match "error|Error|ERROR|failed|Failed|FAILED" -and
                    $_ -notmatch "Warning:"
                }
                if ($realErrors) {
                    Write-Warn "Failed to create ECR secret: $realErrors"
                    return $false
                }
                # If only warnings, consider it success (exit code might be from warning)
                $LASTEXITCODE = 0
            }
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "ECR image pull secret created/updated"
            Write-Info "Token is valid for 12 hours"
            Write-Info "Secret docker-server: $ecrRegistry"
            
            # Verify secret was created correctly (wait a moment for it to be available)
            Start-Sleep -Seconds 2
            $secretCheck = kubectl get secret ecr-registry-secret -n finans-asistan 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Info "ECR secret verified in namespace 'finans-asistan'"
                
                # Add secret to default service account (for Docker Desktop Kubernetes compatibility)
                Write-Info "Adding ECR secret to default service account..."
                # Use PowerShell hashtable and convert to JSON to avoid escaping issues
                $patchObject = @{
                    imagePullSecrets = @(
                        @{
                            name = "ecr-registry-secret"
                        }
                    )
                }
                $patchJson = $patchObject | ConvertTo-Json -Compress -Depth 10
                # Write JSON to temp file to avoid PowerShell escaping issues
                $tempPatchFile = Join-Path $env:TEMP "kubectl-patch-$(Get-Random).json"
                $patchJson | Out-File -FilePath $tempPatchFile -Encoding utf8 -NoNewline
                $patchOutput = kubectl patch serviceaccount default -n finans-asistan --patch-file=$tempPatchFile 2>&1 | Out-String
                Remove-Item -Path $tempPatchFile -Force -ErrorAction SilentlyContinue
                if ($LASTEXITCODE -eq 0) {
                    Write-Info "ECR secret added to default service account"
                } else {
                    Write-Warn "Failed to add ECR secret to default service account (may not be needed)"
                    Write-Warn "Patch output: $patchOutput"
                    Write-Warn "Patch JSON was: $patchJson"
                }
            } else {
                Write-Warn "ECR secret verification failed"
                Write-Warn "Output: $secretCheck"
            }
            
            # Only restart deployments if they already exist (not first-time deployment)
            # If this is first-time deployment, pods will use the secret automatically
            Write-Info "Checking if deployments already exist..."
            $existingDeployments = kubectl get deployments -n finans-asistan -o jsonpath='{.items[*].metadata.name}' 2>&1
            if ($LASTEXITCODE -eq 0 -and $existingDeployments) {
                $deployments = @("backend", "frontend", "event-processor")
                $needsRestart = $false
                foreach ($deployment in $deployments) {
                    if ($existingDeployments -match $deployment) {
                        $needsRestart = $true
                        Write-Info "Restarting existing deployment: $deployment"
                        kubectl rollout restart deployment $deployment -n finans-asistan 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-Info "Restarted deployment: $deployment"
                        }
                    }
                }
                if (-not $needsRestart) {
                    Write-Info "No existing deployments found, new pods will use the secret automatically"
                }
            } else {
                Write-Info "No existing deployments found, new pods will use the secret automatically"
            }
            
            return $true
        } else {
            Write-Warn "Failed to create ECR secret"
            return $false
        }
    } catch {
        Write-Warn "Failed to create ECR secret: $_"
        return $false
    }
}

# Deploy Init Container RBAC
function Deploy-InitContainerRBAC {
    Write-Info "Deploying init container RBAC..."
    
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    $rbacFile = Join-Path $k8sDir "00-init-container-rbac.yaml"
    
    if (-not (Test-Path $rbacFile)) {
        Write-Warn "RBAC file not found: $rbacFile"
        return $false
    }
    
    Write-Info "Applying init container RBAC..."
    $applyOutput = kubectl apply -f $rbacFile 2>&1 | Out-String
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Init container RBAC applied successfully"
        if ($applyOutput) {
            Write-Output $applyOutput.Trim()
        }
        return $true
    } else {
        Write-Warn "Failed to apply init container RBAC"
        if ($applyOutput) {
            Write-Output $applyOutput.Trim()
        }
        return $false
    }
}

# Deploy applications
function Deploy-Applications {
Write-Host ""
    
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    
    # Deploy backend, frontend, and event-processor in order (sequential with dependencies)
    # Dependencies are based on init containers and service requirements:
    # - Backend depends on: PostgreSQL, Redis, Kafka (infrastructure services)
    # - Frontend depends on: Backend
    # - Event-Processor depends on: PostgreSQL, Redis, Kafka (infrastructure services)
    $appFiles = @(
        @{ file = "04-backend-deployment.yaml"; name = "backend"; dependsOn = @("postgres", "redis", "kafka-cluster") },
        @{ file = "05-frontend-deployment.yaml"; name = "frontend"; dependsOn = @("backend") },
        @{ file = "11-event-processor.yaml"; name = "event-processor"; dependsOn = @("postgres", "redis", "kafka-cluster") }
    )
    
    # Get ECR registry URL (use exported value from Create-ECRSecret if available, otherwise calculate)
    $ecrRegistry = $script:ECR_REGISTRY
    if (-not $ecrRegistry) {
        # Try to get from environment variables first
        if ($env:AWS_ACCOUNT_ID -and $env:AWS_REGION) {
            $ecrRegistry = "$($env:AWS_ACCOUNT_ID).dkr.ecr.$($env:AWS_REGION).amazonaws.com"
            Write-Info "Using ECR registry from environment: $ecrRegistry"
        } else {
            # Fallback: try AWS CLI
    try {
        if (Get-Command aws -ErrorAction SilentlyContinue) {
            $awsRegion = if ($env:AWS_REGION) { $env:AWS_REGION } else { "eu-central-1" }
            $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
            if ($identity -and $identity.Account) {
                $ecrRegistry = "$($identity.Account).dkr.ecr.$awsRegion.amazonaws.com"
                        Write-Info "Using ECR registry from AWS CLI: $ecrRegistry"
            }
        }
    } catch {
                Write-Warn "Could not get ECR registry from AWS CLI"
            }
        }
    } else {
        Write-Info "Using ECR registry from Create-ECRSecret: $ecrRegistry"
    }
    
    # If ECR registry is still not available, warn but continue (will use placeholder)
    if (-not $ecrRegistry) {
        Write-Warn "ECR registry not available, deployment files will use PLACEHOLDER_ECR_REGISTRY"
        Write-Warn "Make sure AWS_ACCOUNT_ID and AWS_REGION are set, or AWS CLI is configured"
    } else {
        # Check if images exist in ECR repositories
        Write-Info "Checking if images exist in ECR repositories..."
        Write-Info "Using ECR registry: $ecrRegistry"
        
        # Verify we're using the correct ECR registry (same as GitHub workflow)
        if ($env:AWS_ACCOUNT_ID -and $env:AWS_REGION) {
            $expectedRegistryFromEnv = "$($env:AWS_ACCOUNT_ID).dkr.ecr.$($env:AWS_REGION).amazonaws.com"
            if ($ecrRegistry -ne $expectedRegistryFromEnv) {
                Write-Warn "[WARN] ECR registry mismatch!"
                Write-Warn "   Environment AWS_ACCOUNT_ID would give: $expectedRegistryFromEnv"
                Write-Warn "   But using: $ecrRegistry"
                Write-Warn "   Make sure AWS_ACCOUNT_ID environment variable matches GitHub Secrets AWS_ACCOUNT_ID"
            }
        }
        
        $backendRepo = "finans-asistan-backend-production"
        $frontendRepo = "finans-asistan-frontend-production"
        $eventRepo = "finans-asistan-event-processor-production"
        
        $backendExists = $false
        $frontendExists = $false
        $eventExists = $false
        
        if (Get-Command aws -ErrorAction SilentlyContinue) {
            $awsRegion = if ($env:AWS_REGION) { $env:AWS_REGION } else { "eu-central-1" }
            
            # Force AWS CLI to use environment variables (disable credentials/config files)
            $originalCredentialsFile = $env:AWS_SHARED_CREDENTIALS_FILE
            $originalConfigFile = $env:AWS_CONFIG_FILE
            $originalProfile = $env:AWS_PROFILE
            
            # Set to non-existent files to force environment variable usage
            $env:AWS_SHARED_CREDENTIALS_FILE = "$env:TEMP\aws-credentials-nonexistent-$(Get-Random)"
            $env:AWS_CONFIG_FILE = "$env:TEMP\aws-config-nonexistent-$(Get-Random)"
            $env:AWS_PROFILE = ""
            
            try {
                # Check which AWS account we're authenticated as
                try {
                    $identity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
                    if ($identity -and $identity.Account) {
                        $currentAccountId = $identity.Account
                        Write-Info "Authenticated as AWS account: $currentAccountId"
                        $expectedRegistry = "$currentAccountId.dkr.ecr.$awsRegion.amazonaws.com"
                        if ($ecrRegistry -ne $expectedRegistry) {
                            Write-Error "❌ ECR registry mismatch detected!"
                            Write-Error "   Current AWS account: $currentAccountId"
                            Write-Error "   ECR registry being used: $ecrRegistry"
                            Write-Error "   Expected registry: $expectedRegistry"
                            Write-Error "   This means images were pushed to a different ECR registry!"
                            Write-Error "   Solution: Set AWS_ACCOUNT_ID environment variable to match GitHub Secrets"
                        }
                    }
                } catch {
                    Write-Warn "Could not verify AWS account ID"
                }
                
                try {
                    $backendImage = aws ecr describe-images --repository-name $backendRepo --region $awsRegion --image-ids imageTag=latest --query 'imageDetails[0].imageDigest' --output text 2>&1
                if ($LASTEXITCODE -eq 0 -and $backendImage -and $backendImage -ne "None") {
                    $backendExists = $true
                    Write-Info "[OK] Backend image found in ECR at: $ecrRegistry/$backendRepo`:latest"
                } else {
                    Write-Warn "[WARN] Backend image NOT found in ECR repository: $ecrRegistry/$backendRepo"
                    Write-Warn "   Checking if repository exists in current account..."
                    $repoCheck = aws ecr describe-repositories --repository-names $backendRepo --region $awsRegion 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Warn "   Repository exists but 'latest' tag not found. Checking available tags..."
                        $availableTags = aws ecr list-images --repository-name $backendRepo --region $awsRegion --query 'imageIds[*].imageTag' --output text 2>&1
                        if ($availableTags) {
                            $tags = ($availableTags -split '\s+')[0..4] -join ', '
                            Write-Warn "   Available tags: $tags"
                        }
                    } else {
                        Write-Error "   Repository does not exist in current AWS account!"
                    }
                }
            } catch {
                Write-Warn "[WARN] Backend image NOT found in ECR repository: $backendRepo"
            }
            
            try {
                $frontendImage = aws ecr describe-images --repository-name $frontendRepo --region $awsRegion --image-ids imageTag=latest --query 'imageDetails[0].imageDigest' --output text 2>&1
                if ($LASTEXITCODE -eq 0 -and $frontendImage -and $frontendImage -ne "None") {
                    $frontendExists = $true
                    Write-Info "[OK] Frontend image found in ECR"
                } else {
                    Write-Warn "[WARN] Frontend image NOT found in ECR repository: $frontendRepo"
                }
            } catch {
                Write-Warn "⚠️  Frontend image NOT found in ECR repository: $frontendRepo"
            }
            
            try {
                $eventImage = aws ecr describe-images --repository-name $eventRepo --region $awsRegion --image-ids imageTag=latest --query 'imageDetails[0].imageDigest' --output text 2>&1
                if ($LASTEXITCODE -eq 0 -and $eventImage -and $eventImage -ne "None") {
                    $eventExists = $true
                    Write-Info "[OK] Event-processor image found in ECR"
                } else {
                    Write-Warn "[WARN] Event-processor image NOT found in ECR repository: $eventRepo"
                }
            } catch {
                Write-Warn "⚠️  Event-processor image NOT found in ECR repository: $eventRepo"
            }
            
            if (-not $backendExists -or -not $frontendExists -or -not $eventExists) {
                Write-Error "Some images are missing in ECR repositories!"
                Write-Error "Please run GitHub Actions workflow to build and push images, or build them manually."
                Write-Error "Repository names:"
                if (-not $backendExists) { Write-Error "  - $backendRepo" }
                if (-not $frontendExists) { Write-Error "  - $frontendRepo" }
                if (-not $eventExists) { Write-Error "  - $eventRepo" }
            }
        } finally {
            # Restore original AWS config/credentials file settings
            if ($originalCredentialsFile) { $env:AWS_SHARED_CREDENTIALS_FILE = $originalCredentialsFile }
            else { Remove-Item Env:\AWS_SHARED_CREDENTIALS_FILE -ErrorAction SilentlyContinue }
            
            if ($originalConfigFile) { $env:AWS_CONFIG_FILE = $originalConfigFile }
            else { Remove-Item Env:\AWS_CONFIG_FILE -ErrorAction SilentlyContinue }
            
            if ($originalProfile) { $env:AWS_PROFILE = $originalProfile }
            else { Remove-Item Env:\AWS_PROFILE -ErrorAction SilentlyContinue }
        }
        } else {
            Write-Warn "AWS CLI not available, skipping ECR image check"
        }
    }
    
    # Deploy applications sequentially, waiting for each to be ready before starting the next
    foreach ($app in $appFiles) {
        $appFile = $app.file
        $appName = $app.name
        $dependsOn = $app.dependsOn
        
        # Wait for dependencies to be ready before deploying
        if ($dependsOn.Count -gt 0) {
            Write-Info "Waiting for dependencies of $appName to be ready..."
            foreach ($dependency in $dependsOn) {
                Write-Info "  Waiting for $dependency to be ready..."
                $elapsedDep = 0
                $checkIntervalDep = 5
                $dependencyReady = $false
                
                while (-not $dependencyReady) {
                    # Check different resource types (Deployment, StatefulSet, Kafka CRD)
                    $dependencyReady = $false
                    $lastError = $null
                    
                    # Try as StatefulSet first (for postgres, etc.)
                    $statefulSetOutput = kubectl get statefulset $dependency -n finans-asistan -o json 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        try {
                            $statefulSetJson = $statefulSetOutput | ConvertFrom-Json
                            if ($statefulSetJson -and $statefulSetJson.status) {
                                $readyReplicas = if ($null -ne $statefulSetJson.status.readyReplicas) { $statefulSetJson.status.readyReplicas } else { 0 }
                                $desiredReplicas = if ($null -ne $statefulSetJson.spec.replicas) { $statefulSetJson.spec.replicas } else { 0 }
                                
                                if ($readyReplicas -ge $desiredReplicas -and $desiredReplicas -gt 0) {
                                    $dependencyReady = $true
                                    Write-Info "  [OK] $dependency (StatefulSet) is ready ($readyReplicas/$desiredReplicas)"
                                    break
                                } else {
                                    if (($elapsedDep % 15) -eq 0 -and $elapsedDep -gt 0) {
                                        Write-Info "  [DEBUG] $dependency StatefulSet: readyReplicas=$readyReplicas, desiredReplicas=$desiredReplicas"
                                    }
                                }
                            }
                        } catch {
                            $lastError = $_.Exception.Message
                        }
                    }
                    
                    # Try as Deployment (for redis, etc.)
                    if (-not $dependencyReady) {
                        $deployOutput = kubectl get deployment $dependency -n finans-asistan -o json 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            try {
                                $deployJson = $deployOutput | ConvertFrom-Json
                                if ($deployJson -and $deployJson.status -and $deployJson.status.conditions) {
                                    $availableCondition = $deployJson.status.conditions | Where-Object { $_.type -eq "Available" } | Select-Object -First 1
                                    if ($availableCondition -and $availableCondition.status -eq "True") {
                                        $readyReplicas = if ($null -ne $deployJson.status.readyReplicas) { $deployJson.status.readyReplicas } else { 0 }
                                        $desiredReplicas = if ($null -ne $deployJson.spec.replicas) { $deployJson.spec.replicas } else { 0 }
                                        if ($readyReplicas -ge $desiredReplicas -and $desiredReplicas -gt 0) {
                                            $dependencyReady = $true
                                            Write-Info "  [OK] $dependency (Deployment) is ready ($readyReplicas/$desiredReplicas)"
                                            break
                                        }
                                    }
                                }
                            } catch {
                                $lastError = $_.Exception.Message
                            }
                        }
                    }
                    
                    # Try as Kafka CRD (e.g., kafka-cluster)
                    if (-not $dependencyReady -and $dependency -like "*kafka*") {
                        $kafkaOutput = kubectl get kafka $dependency -n finans-asistan -o json 2>&1
                        if ($LASTEXITCODE -eq 0) {
                            try {
                                $kafkaJson = $kafkaOutput | ConvertFrom-Json
                                if ($kafkaJson -and $kafkaJson.status -and $kafkaJson.status.conditions) {
                                    $readyCondition = $kafkaJson.status.conditions | Where-Object { $_.type -eq "Ready" } | Select-Object -First 1
                                    if ($readyCondition -and $readyCondition.status -eq "True") {
                                        $dependencyReady = $true
                                        Write-Info "  [OK] $dependency (Kafka) is ready"
                                        break
                                    }
                                }
                            } catch {
                                $lastError = $_.Exception.Message
                            }
                        }
                    }
                    
                    if (-not $dependencyReady) {
                        Start-Sleep -Seconds $checkIntervalDep
                        $elapsedDep += $checkIntervalDep
                        if (($elapsedDep % 15) -eq 0 -and $elapsedDep -gt 0) {
                            Write-Info "  Still waiting for $dependency... (${elapsedDep}s elapsed)"
                        }
                    }
                }
            }
        }
        
        $appPath = Join-Path $k8sDir $appFile
        if (Test-Path $appPath) {
            Write-Info "Deploying $appName ($appFile)..."
            
            # Read YAML content
            $yamlContent = Get-Content $appPath -Raw
            
            # Replace PLACEHOLDER_ECR_REGISTRY with actual registry if available
            if ($yamlContent -match "PLACEHOLDER_ECR_REGISTRY") {
                if ($ecrRegistry) {
                    Write-Info "Updating $appFile with ECR registry: $ecrRegistry"
                $yamlContent = $yamlContent -replace "PLACEHOLDER_ECR_REGISTRY", $ecrRegistry
                
                # Normalize line endings (CRLF -> LF) and ensure trailing newline
                $yamlContent = $yamlContent -replace "`r`n", "`n" -replace "`r", "`n"
                if (-not $yamlContent.EndsWith("`n")) {
                    $yamlContent += "`n"
                }
                
                # Write to temp file with UTF-8 encoding (no BOM) and Unix line endings
                $tempYaml = Join-Path $env:TEMP "temp-$appFile"
                $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                [System.IO.File]::WriteAllText($tempYaml, $yamlContent, $utf8NoBom)
                
                Write-Info "Applying $appFile to cluster..."
                $applyOutput = kubectl apply -f $tempYaml 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "❌ Failed to apply $appFile. Stopping deployment process."
                    if ($applyOutput) {
                        Write-Output $applyOutput.Trim()
                    }
                    Remove-Item -Path $tempYaml -Force -ErrorAction SilentlyContinue
                    return $false
                }
                
                Write-Info "[OK] $appFile applied successfully"
                if ($applyOutput) {
                    Write-Output $applyOutput.Trim()
                }
                
                # Verify image URL was updated (only if apply was successful)
                if ($appName -eq "backend") {
                    $backendImage = kubectl get deployment backend -n finans-asistan -o jsonpath='{.spec.template.spec.containers[0].image}' 2>&1
                    if ($backendImage) {
                        Write-Info "Backend image: $backendImage"
                        if ($backendImage -match "PLACEHOLDER_ECR_REGISTRY") {
                            Write-Error "Backend image still contains PLACEHOLDER_ECR_REGISTRY!"
                            Remove-Item -Path $tempYaml -Force -ErrorAction SilentlyContinue
                            return $false
                        }
                    }
                } elseif ($appName -eq "frontend") {
                    $frontendImage = kubectl get deployment frontend -n finans-asistan -o jsonpath='{.spec.template.spec.containers[0].image}' 2>&1
                    if ($frontendImage) {
                        Write-Info "Frontend image: $frontendImage"
                        if ($frontendImage -match "PLACEHOLDER_ECR_REGISTRY") {
                            Write-Error "Frontend image still contains PLACEHOLDER_ECR_REGISTRY!"
                            Remove-Item -Path $tempYaml -Force -ErrorAction SilentlyContinue
                            return $false
                        }
                    }
                } elseif ($appName -eq "event-processor") {
                    $eventImage = kubectl get deployment event-processor -n finans-asistan -o jsonpath='{.spec.template.spec.containers[0].image}' 2>&1
                    if ($eventImage) {
                        Write-Info "Event-processor image: $eventImage"
                        if ($eventImage -match "PLACEHOLDER_ECR_REGISTRY") {
                            Write-Error "Event-processor image still contains PLACEHOLDER_ECR_REGISTRY!"
                            Remove-Item -Path $tempYaml -Force -ErrorAction SilentlyContinue
                            return $false
                        }
                    }
                }
                    
                Remove-Item -Path $tempYaml -Force -ErrorAction SilentlyContinue
                } else {
                    Write-Warn "ECR registry not available, deploying $appFile with placeholder (may fail)"
                    Write-Info "Applying $appFile to cluster..."
                    $applyOutput = kubectl apply -f $appPath 2>&1 | Out-String
                    if ($LASTEXITCODE -ne 0) {
                        Write-Error "❌ Failed to apply $appFile. Stopping deployment process."
                        if ($applyOutput) {
                            Write-Output $applyOutput.Trim()
                        }
                        return $false
                    }
                    
                    Write-Info "[OK] $appFile applied successfully"
                    if ($applyOutput) {
                        Write-Output $applyOutput.Trim()
                    }
                }
            } else {
                # No placeholder, apply directly
                Write-Info "Applying $appFile to cluster..."
                $applyOutput = kubectl apply -f $appPath 2>&1 | Out-String
                if ($LASTEXITCODE -ne 0) {
                    Write-Error "❌ Failed to apply $appFile. Stopping deployment process."
                    if ($applyOutput) {
                        Write-Output $applyOutput.Trim()
                    }
                    return $false
                }
                
                Write-Info "[OK] $appFile applied successfully"
                if ($applyOutput) {
                    Write-Output $applyOutput.Trim()
                }
            }
            
            # Wait for this deployment to be ready before proceeding to the next (no timeout - will wait indefinitely)
            Write-Info "Waiting for $appName deployment to be ready (no timeout, will wait until ready)..."
            $elapsed = 0
            $checkInterval = 5
            $deploymentReady = $false
            
            while (-not $deploymentReady) {
                try {
                    $deployJson = kubectl get deployment $appName -n finans-asistan -o json 2>&1 | ConvertFrom-Json
                    if ($deployJson -and $deployJson.status.conditions) {
                        $availableCondition = $deployJson.status.conditions | Where-Object { $_.type -eq "Available" } | Select-Object -First 1
                        if ($availableCondition -and $availableCondition.status -eq "True") {
                            $readyReplicas = if ($null -ne $deployJson.status.readyReplicas) { $deployJson.status.readyReplicas } else { 0 }
                            $desiredReplicas = if ($null -ne $deployJson.spec.replicas) { $deployJson.spec.replicas } else { 0 }
                            if ($readyReplicas -ge $desiredReplicas -and $desiredReplicas -gt 0) {
                                $deploymentReady = $true
                                Write-Success "$appName is ready ($readyReplicas/$desiredReplicas)"
                                break
                            }
                        }
                    }
                } catch {
                    # Deployment might not exist yet, continue waiting
                }
                
                if (-not $deploymentReady) {
                    Start-Sleep -Seconds $checkInterval
                    $elapsed += $checkInterval
                    if (($elapsed % 15) -eq 0 -and $elapsed -gt 0) {
                        Write-Info "  Still waiting for $appName... (${elapsed}s elapsed)"
                    }
                }
            }
            
            if (-not $deploymentReady) {
                Write-Error "❌ $appName deployment failed to become ready. Stopping deployment process."
                return $false
            }
        }
    }
    
    # Show final pod status
    Write-Info "Final pod status:"
    kubectl get pods -n finans-asistan -l 'app in (backend,frontend,event-processor)' 2>&1 | Out-String | Write-Output
    
    Write-Success "All applications deployment completed"
}

# Update HPA minReplicas based on node count (ensure at least 1 pod per node)
function Update-HPAMinReplicas {
    Write-Info "Updating HPA minReplicas based on node count..."
    
    # Get total node count (leader + worker nodes) for distributed services
    # This ensures at least 1 pod per node (leader node + all worker nodes)
    $nodes = kubectl get nodes --no-headers 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Warn "Failed to get nodes, using default minReplicas"
        return
    }
    
    $nodeCount = ($nodes | Measure-Object -Line).Lines
    
    # If node count is 0, use 1 as minimum
    if ($nodeCount -eq 0) {
        $nodeCount = 1
    }
    
    Write-Info "Total nodes (leader + workers): $nodeCount"
    
    # Update each HPA minReplicas to match node count (ensures at least 1 pod per node)
    # Use temporary file to avoid PowerShell JSON escaping issues with kubectl patch
    $tempPatchFile = [System.IO.Path]::GetTempFileName()
    
    try {
        $patchJson = @{
            spec = @{
                minReplicas = $nodeCount
            }
        } | ConvertTo-Json -Compress
        
        # Write JSON to temp file
        $patchJson | Out-File -FilePath $tempPatchFile -Encoding utf8 -NoNewline
        
        # Use --patch-file instead of -p to avoid PowerShell string escaping issues
        kubectl patch hpa backend-hpa -n finans-asistan --type='merge' --patch-file=$tempPatchFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Failed to update backend-hpa minReplicas"
        }
        
        kubectl patch hpa frontend-hpa -n finans-asistan --type='merge' --patch-file=$tempPatchFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Failed to update frontend-hpa minReplicas"
        }
        
        kubectl patch hpa event-processor-hpa -n finans-asistan --type='merge' --patch-file=$tempPatchFile 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "Failed to update event-processor-hpa minReplicas"
        }
        
        # Update HPA minReplicas for distributed services (AlertManager, Grafana, Exporters, ArgoCD Server/Repo Server)
        # These services can scale horizontally across all nodes
        $distributedServices = @(
            "alertmanager-hpa",
            "grafana-hpa",
            "postgres-exporter-hpa",
            "redis-exporter-hpa",
            "kafka-exporter-hpa",
            "argocd-server-hpa",
            "argocd-repo-server-hpa"
        )
        
        foreach ($hpaName in $distributedServices) {
            # Use correct namespace based on HPA name
            $targetNamespace = "finans-asistan"
            if ($hpaName -like "argocd-*") {
                $targetNamespace = "argocd"
            }
            
            # Check if HPA exists before patching
            $hpaExists = kubectl get hpa $hpaName -n $targetNamespace --ignore-not-found 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $hpaExists -match $hpaName) {
                kubectl patch hpa $hpaName -n $targetNamespace --type='merge' --patch-file=$tempPatchFile 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Info "Updated $hpaName minReplicas to $nodeCount in namespace $targetNamespace"
                } else {
                    Write-Warn "Failed to update $hpaName minReplicas in namespace $targetNamespace"
                }
            } else {
                Write-Info "$hpaName not found yet in namespace $targetNamespace"
            }
        }
        
        # Leader node services keep minReplicas=1, maxReplicas=1 (HPA cannot scale these)
        # PostgreSQL, Redis, Prometheus, ArgoCD Application Controller - not updated here
    } finally {
        # Clean up temp file
        if (Test-Path $tempPatchFile) {
            Remove-Item $tempPatchFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Success "Distributed services HPA minReplicas updated to $nodeCount (ensures at least 1 pod per node - leader + all workers)"
    Write-Info "Non-distributed services (PostgreSQL, Redis, Prometheus, ArgoCD Application Controller) stay at minReplicas=1, maxReplicas=1 (must run on leader node only)"
}

# Deploy HPA (Horizontal Pod Autoscaler)
function Deploy-HPA {
    Write-Info "Deploying HPA..."
    
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    $hpaFile = Join-Path $k8sDir "06-hpa.yaml"
    
    if (Test-Path $hpaFile) {
        Write-Info "Deploying HPA for all services (backend, frontend, event-processor, postgres, redis)..."
        $applyOutput = kubectl apply -f $hpaFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "HPA deployment encountered issues: $applyOutput"
        }
        
        # Deploy Monitoring HPA (Prometheus, AlertManager, Grafana, Exporters)
        Write-Info "Deploying Monitoring HPA..."
        $monitoringHpaFile = Join-Path $k8sDir "06c-monitoring-hpa.yaml"
        if (Test-Path $monitoringHpaFile) {
            kubectl apply -f $monitoringHpaFile 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Monitoring HPA deployed"
            } else {
                Write-Warn "Monitoring HPA deployment encountered issues"
            }
        } else {
            Write-Warn "Monitoring HPA manifest not found, skipping..."
        }
            
        # Remove any existing ScaledObject (KEDA no longer used)
        # This may fail if KEDA is not installed, which is OK
        $ErrorActionPreference = "SilentlyContinue"
            kubectl delete scaledobject event-processor-scaler -n finans-asistan --ignore-not-found 2>&1 | Out-Null
        $ErrorActionPreference = "Stop"
        
        # Verify HPA deployment
        $hpaCount = (kubectl get hpa -n finans-asistan --no-headers 2>&1 | Measure-Object -Line).Lines
        if ($hpaCount -ge 5) {
            Write-Success "HPA deployed for all services ($hpaCount HPA resources created)"
        } else {
            Write-Warn "HPA deployment may be incomplete. Expected 5 HPA resources, found $hpaCount"
        }
        
        # Update HPA minReplicas based on node count (ensure at least 1 pod per node)
        Update-HPAMinReplicas
        
        # Deploy Kafka Auto-Scaler (CronJob) - KafkaNodePool does not support HPA
        Write-Info "Deploying Kafka Auto-Scaler (CronJob)..."
        $kafkaAutoscalerFile = Join-Path $k8sDir "06b-kafka-autoscaler.yaml"
        if (Test-Path $kafkaAutoscalerFile) {
            kubectl apply -f $kafkaAutoscalerFile 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Kafka Auto-Scaler deployed (runs every 5 minutes)"
            } else {
                Write-Warn "Kafka Auto-Scaler deployment encountered issues"
            }
        } else {
            Write-Warn "Kafka Auto-Scaler manifest not found, skipping..."
        }
    } else {
        Write-Warn "HPA manifest not found at $hpaFile, skipping..."
    }
}

# Deploy monitoring
function Deploy-Monitoring {
    Write-Info "Deploying monitoring..."
    
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    $monitoringFile = Join-Path $k8sDir "09-monitoring.yaml"
    
    if (Test-Path $monitoringFile) {
        kubectl apply -f $monitoringFile 2>&1 | Out-Null
        Write-Success "Monitoring deployed"
    } else {
        Write-Warn "Monitoring manifest not found, skipping..."
    }
}

# Deploy Cluster Autoscaler (EC2 node auto-scaling)
function Deploy-ClusterAutoscaler {
    Write-Info "Deploying Cluster Autoscaler (EC2 node auto-scaling)..."
    
    $k8sDir = Join-Path $PSScriptRoot "..\k8s"
    $autoscalerFile = Join-Path $k8sDir "07-cluster-autoscaler.yaml"
    
    if (-not (Test-Path $autoscalerFile)) {
        Write-Warn "Cluster Autoscaler manifest not found, skipping..."
        return
    }
    
    # Check if AWS credentials are available for Cluster Autoscaler
    $awsAccessKey = $env:AWS_ACCESS_KEY_ID
    $awsSecretKey = $env:AWS_SECRET_ACCESS_KEY
    $awsRegion = if ($env:AWS_REGION) { $env:AWS_REGION } else { "eu-central-1" }
    
    if ([string]::IsNullOrWhiteSpace($awsAccessKey) -or [string]::IsNullOrWhiteSpace($awsSecretKey)) {
        Write-Warn "AWS credentials not found. Cluster Autoscaler requires AWS credentials for EC2 auto-scaling."
        Write-Info "Cluster Autoscaler will be skipped. Set AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY to enable."
        return
    }
    
    Write-Info "Creating Cluster Autoscaler secret with AWS credentials..."
    
    # Create or update secret with AWS credentials
    $secretYaml = @"
apiVersion: v1
kind: Secret
metadata:
  name: cluster-autoscaler-aws-credentials
  namespace: kube-system
type: Opaque
stringData:
  aws-access-key-id: "$awsAccessKey"
  aws-secret-access-key: "$awsSecretKey"
"@
    
    $secretYaml | kubectl apply -f - 2>&1 | Out-Null
    
    # Update Cluster Autoscaler deployment with AWS region
    $tempAutoscalerFile = Join-Path $env:TEMP "cluster-autoscaler.yaml"
    $autoscalerContent = Get-Content $autoscalerFile -Raw
    
    # Replace placeholder values with actual AWS credentials and region
    $autoscalerContent = $autoscalerContent -replace 'CHANGE_ME', ''
    $autoscalerContent = $autoscalerContent -replace 'value: "eu-central-1"', "value: `"$awsRegion`""
    
    # Remove the secret section from deployment YAML (already created separately)
    # This regex matches the Secret resource and removes it (including the --- separator after it)
    $lines = $autoscalerContent -split "`n"
    $outputLines = @()
    $skipSecret = $false
    $skipUntilNextSeparator = $false
    
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^apiVersion: v1\s*$' -and $i + 1 -lt $lines.Count -and $lines[$i + 1] -match '^kind: Secret') {
            $skipSecret = $true
            $skipUntilNextSeparator = $true
            continue
        }
        if ($skipUntilNextSeparator -and $line -match '^---\s*$') {
            $skipUntilNextSeparator = $false
            $skipSecret = $false
            continue
        }
        if (-not $skipSecret) {
            $outputLines += $line
        }
    }
    $autoscalerContent = $outputLines -join "`n"
    
    $autoscalerContent | Out-File -FilePath $tempAutoscalerFile -Encoding UTF8 -NoNewline
    
    # Apply Cluster Autoscaler
    kubectl apply -f $tempAutoscalerFile 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Cluster Autoscaler deployed"
        Write-Info "Cluster Autoscaler will scale EC2 nodes based on pod resource requests"
        Write-Info "Ensure your AWS Auto Scaling Groups are tagged with: k8s.io/cluster-autoscaler/enabled"
    } else {
        Write-Warn "Cluster Autoscaler deployment failed"
    }
    
    # Cleanup temp file
    Remove-Item -Path $tempAutoscalerFile -Force -ErrorAction SilentlyContinue
}

# VPA removed - using only HPA for autoscaling

# Install operators
function Install-Operators {
    Write-Info "Installing Kubernetes operators..."
    
    # Metrics Server
    Write-Info "Installing Metrics Server..."
    try {
        kubectl apply -f "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            # Patch for insecure TLS (development only - Docker Desktop Kubernetes)
            kubectl patch deployment metrics-server -n kube-system --type='json' -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]' 2>&1 | Out-Null
            Write-Success "Metrics Server installed"
        } else {
            Write-Warn "Metrics Server installation failed (may already be installed)"
        }
    } catch {
        Write-Warn "Metrics Server installation error: $_"
    }
    
    # VPA removed - using only HPA for autoscaling
    # Leader node services (PostgreSQL, Redis, Prometheus, Grafana, etc.) have memory limits
    # set to match available RAM on R6G Large (16GB total, ~14.4GB usable)
    
    Write-Success "Operators installation completed"
}


# Deploy ArgoCD
function Deploy-ArgoCD {
    Write-Info "Deploying ArgoCD in argocd namespace..."
    
    # Check if ArgoCD is already installed in argocd namespace (correct location)
    $argocdAlreadyInstalled = $false
    try {
        $null = kubectl get deployment argocd-server -n argocd 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "ArgoCD is already installed in argocd namespace!"
            $argocdAlreadyInstalled = $true
            # Don't return - we still need to create/update the Application
        }
    } catch {
        # Not found, continue with installation
    }
    
    # Check if ArgoCD is incorrectly installed in finans-asistan namespace
    try {
        $null = kubectl get deployment argocd-server -n finans-asistan 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Warn "ArgoCD found in 'finans-asistan' namespace (should be in 'argocd')"
            Write-Info "Removing ArgoCD from finans-asistan namespace..."
            kubectl delete deployment,statefulset,service,configmap,secret -n finans-asistan -l app.kubernetes.io/part-of=argocd 2>&1 | Out-Null
            kubectl delete deployment argocd-server argocd-repo-server argocd-applicationset-controller argocd-dex-server argocd-notifications-controller argocd-redis -n finans-asistan 2>&1 | Out-Null
            kubectl delete statefulset argocd-application-controller -n finans-asistan 2>&1 | Out-Null
            kubectl delete service argocd-server argocd-repo-server argocd-redis argocd-dex-server argocd-applicationset-controller argocd-metrics argocd-server-metrics argocd-notifications-controller-metrics -n finans-asistan 2>&1 | Out-Null
            kubectl delete configmap argocd-cm argocd-rbac-cm argocd-cmd-params-cm argocd-gpg-keys-cm argocd-notifications-cm argocd-ssh-known-hosts-cm argocd-tls-certs-cm -n finans-asistan 2>&1 | Out-Null
            kubectl delete secret argocd-secret argocd-initial-admin-secret argocd-notifications-secret argocd-redis argocd-repo-github -n finans-asistan 2>&1 | Out-Null
            Write-Info "Waiting for resources to be deleted..."
            Start-Sleep -Seconds 5
            Write-Success "ArgoCD removed from finans-asistan namespace"
        }
    } catch {
        # Not found, continue
    }
    
    # Check if ArgoCD is incorrectly installed in default namespace
    try {
        $null = kubectl get deployment argocd-server -n default 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Warn "ArgoCD found in 'default' namespace (should be in 'argocd')"
            Write-Info "Removing ArgoCD from default namespace..."
            kubectl delete deployment,statefulset,service,configmap,secret -n default -l app.kubernetes.io/part-of=argocd 2>&1 | Out-Null
            kubectl delete deployment argocd-server argocd-repo-server argocd-applicationset-controller argocd-dex-server argocd-notifications-controller argocd-redis -n default 2>&1 | Out-Null
            kubectl delete statefulset argocd-application-controller -n default 2>&1 | Out-Null
            kubectl delete service argocd-server argocd-repo-server argocd-redis argocd-dex-server argocd-applicationset-controller argocd-metrics argocd-server-metrics argocd-notifications-controller-metrics -n default 2>&1 | Out-Null
            kubectl delete configmap argocd-cm argocd-rbac-cm argocd-cmd-params-cm argocd-gpg-keys-cm argocd-notifications-cm argocd-ssh-known-hosts-cm argocd-tls-certs-cm -n default 2>&1 | Out-Null
            kubectl delete secret argocd-secret argocd-initial-admin-secret argocd-notifications-secret argocd-redis -n default 2>&1 | Out-Null
            Write-Info "Waiting for resources to be deleted..."
            Start-Sleep -Seconds 5
            Write-Success "ArgoCD removed from default namespace"
        }
    } catch {
        # Not found, continue
    }
    
    # Clean up any stuck ArgoCD CRDs before installation (only if needed)
    # This is a troubleshooting step - only runs if CRDs are stuck in deletion
    try {
        $crds = kubectl get crd -o json 2>&1 | ConvertFrom-Json
        $argocdCrds = $crds.items | Where-Object { $_.metadata.name -like "*argoproj.io" }
        
        $hasStuck = $false
        foreach ($crd in $argocdCrds) {
            if ($crd.metadata.deletionTimestamp) {
                $name = $crd.metadata.name
                if (-not $hasStuck) {
                    Write-Warn "Found stuck ArgoCD CRDs (from previous incomplete deletion), cleaning up..."
                    $hasStuck = $true
                }
                Write-Info "Removing finalizers from stuck CRD: $name"
                kubectl patch crd $name --type json -p '[{"op": "remove", "path": "/metadata/finalizers"}]' 2>&1 | Out-Null
            }
        }
        if ($hasStuck) {
            Write-Info "Waiting for stuck CRDs to be fully deleted..."
            Start-Sleep -Seconds 3
        }
    } catch {
        # No CRDs found or error, continue
    }
    
    # ArgoCD will be installed in argocd namespace (standard ArgoCD namespace)
    # Ensure argocd namespace exists
    $namespaceCheck = kubectl get namespace argocd -o name --ignore-not-found 2>&1
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($namespaceCheck) -or -not ($namespaceCheck -match "namespace/argocd")) {
        # Namespace doesn't exist, create it
        kubectl create namespace argocd 2>&1 | Out-Null
        Write-Info "Created argocd namespace"
    }
    
    # Only install ArgoCD if not already installed
    if (-not $argocdAlreadyInstalled) {
        # Download ArgoCD install.yaml (use standard argocd namespace, don't modify)
        Write-Info "Downloading ArgoCD install.yaml (will install in argocd namespace)..."
        $tempArgoCdFile = Join-Path $env:TEMP "argocd-install.yaml"
        try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" -OutFile $tempArgoCdFile -ErrorAction Stop
        
        # Read the file (keep original - ArgoCD should be installed in argocd namespace)
        $argocdContent = Get-Content $tempArgoCdFile -Raw
        
        # Write content back (no namespace modifications needed)
        $argocdContent | Out-File -FilePath $tempArgoCdFile -Encoding utf8 -NoNewline
        
        # Install ArgoCD in argocd namespace (standard ArgoCD namespace)
        # Apply with explicit namespace to ensure namespace-scoped resources go to argocd
        # Cluster-scoped resources (ClusterRole, ClusterRoleBinding) will ignore the namespace flag
        kubectl apply -f $tempArgoCdFile --namespace=argocd --validate=false 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            # Fallback: apply without namespace flag if it causes issues with cluster-scoped resources
            # This will use the namespace specified in the YAML (argocd)
            kubectl apply -f $tempArgoCdFile 2>&1 | Out-Null
        }
    } catch {
        Write-Warn "Failed to download/modify ArgoCD install.yaml: $_"
        Write-Info "Falling back to direct install with namespace override..."
        # Fallback: download, modify namespace, then apply
        try {
            $fallbackContent = (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml" -UseBasicParsing).Content
            # Keep original namespace (argocd) - no modifications needed
            # ArgoCD should be installed in its standard namespace
            # Apply with explicit namespace to ensure namespace-scoped resources go to argocd
            $fallbackContent | kubectl apply -f - --namespace=argocd --validate=false 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) {
                # Fallback: apply without namespace flag
                $fallbackContent | kubectl apply -f - 2>&1 | Out-Null
            }
        } catch {
            Write-Warn "Fallback ArgoCD installation also failed: $_"
        }
    } finally {
        if (Test-Path $tempArgoCdFile) {
            Remove-Item $tempArgoCdFile -Force -ErrorAction SilentlyContinue
        }
    }
    } else {
        # ArgoCD already installed, skip installation but continue with configuration
        Write-Info "Skipping ArgoCD installation (already installed), proceeding with configuration..."
    }
    
    # Continue with configuration and Application creation regardless of installation status
    if ($argocdAlreadyInstalled -or $LASTEXITCODE -eq 0) {
        Write-Info "Waiting for ArgoCD to be ready..."
        Write-Info "This may take 1-3 minutes (downloading images and initializing components)..."
        Write-Host ""
        
        # Wait for critical ArgoCD components using kubectl wait (more efficient)
        $components = @(
            @{type="deployment"; name="argocd-redis"},
            @{type="deployment"; name="argocd-repo-server"},
            @{type="deployment"; name="argocd-server"},
            @{type="statefulset"; name="argocd-application-controller"}
        )
        
        $maxWait = 180  # 3 minutes (reduced from 5)
        $elapsed = 0
        $checkInterval = 5  # Check every 5 seconds (reduced from 10)
        $allReady = $false
        $lastPodStatus = ""
        
        while ($elapsed -lt $maxWait) {
            # Show ArgoCD pod status with image pull progress every 5 seconds
            if (($elapsed % $checkInterval) -eq 0) {
                # Get all ArgoCD pods by name pattern with error handling
                try {
                    $kubectlOutput = kubectl get pods -n argocd -o json 2>&1
                    if ($LASTEXITCODE -eq 0 -and $kubectlOutput) {
                        # Validate JSON before parsing
                        $pods = $null
                        try {
                            $pods = $kubectlOutput | ConvertFrom-Json
                        } catch {
                            # JSON parsing failed, skip pod status display this iteration
                            $pods = $null
                        }
                        
                        if ($pods -and $pods.items) {
                            # Filter ArgoCD pods (name starts with argocd-)
                            $argocdPods = $pods.items | Where-Object { $_.metadata.name -like "argocd-*" }
                            if ($argocdPods) {
                                $podStatusOutput = @()
                                foreach ($pod in $argocdPods) {
                                    $podName = $pod.metadata.name
                                    $podPhase = $pod.status.phase
                                    $containerStatuses = @()
                                    $hasImagePull = $false
                                    
                                    if ($pod.status.containerStatuses) {
                                        foreach ($cs in $pod.status.containerStatuses) {
                                            # Check if image field exists and is not null
                                            if ($cs.image -and -not [string]::IsNullOrWhiteSpace($cs.image)) {
                                                $image = $cs.image
                                                $imageName = $image.Split('/')[-1]
                                                
                                                if ($cs.state.waiting) {
                                                    $reason = $cs.state.waiting.reason
                                                    $message = $cs.state.waiting.message
                                                    
                                                    if ($reason -eq "ContainerCreating" -or $reason -eq "PodInitializing") {
                                                        $status = "[Pulling] $imageName"
                                                        $hasImagePull = $true
                                                        if ($message) {
                                                            $status += " - $message"
                                                        }
                                                    } elseif ($reason -eq "ImagePullBackOff" -or $reason -eq "ErrImagePull") {
                                                        $status = "[ERROR] $imageName - $reason"
                                                        $hasImagePull = $true
                                                        if ($message) {
                                                            $status += ": $message"
                                                        }
                                                    } else {
                                                        $status = "[Waiting] $imageName - $reason"
                                                    }
                                                    $containerStatuses += "    $status"
                                                } elseif ($cs.state.running) {
                                                    $containerStatuses += "    [Ready] $imageName"
                                                } elseif ($cs.state.terminated) {
                                                    $containerStatuses += "    [Terminated] $imageName"
                                                }
                                            }
                                        }
                                    }
                                    
                                    # Show pod status if pulling images or not fully running
                                    if ($hasImagePull -or $podPhase -ne "Running" -or $containerStatuses.Count -gt 0) {
                                        $podStatusOutput += "  Pod: $podName ($podPhase)"
                                        foreach ($status in $containerStatuses) {
                                            $podStatusOutput += $status
                                        }
                                        $podStatusOutput += ""
                                    }
                                }
                                
                                # Show status only if status changed (avoid duplicate logs)
                                # Check if there are any pods that are not ready
                                $hasNotReadyPods = $false
                                foreach ($pod in $argocdPods) {
                                    if ($pod.status.phase -ne "Running") {
                                        $hasNotReadyPods = $true
                                        break
                                    }
                                    if ($pod.status.containerStatuses) {
                                        foreach ($cs in $pod.status.containerStatuses) {
                                            if (-not $cs.ready) {
                                                $hasNotReadyPods = $true
                                                break
                                            }
                                        }
                                    }
                                }
                                
                                if ($hasNotReadyPods -and $podStatusOutput.Count -gt 0) {
                                    $currentPodStatus = $podStatusOutput -join "`n"
                                    if ($currentPodStatus -ne $lastPodStatus) {
                                        Write-Host "`n===============================================================" -ForegroundColor Cyan
                                        Write-Host "  ArgoCD Image Pull Status (${elapsed}s elapsed)" -ForegroundColor Cyan
                                        Write-Host "===============================================================" -ForegroundColor Cyan
                                        Write-Host $currentPodStatus
                                        $lastPodStatus = $currentPodStatus
                                    }
                                } elseif (-not $hasNotReadyPods) {
                                    # All pods are ready, clear last status to avoid showing again
                                    if ($lastPodStatus -ne "") {
                                        $lastPodStatus = ""
                                    }
                                }
                            }
                        }
                    }
                }
                catch {
                    # kubectl command failed or pods not available yet - continue waiting
                }
            }
            
            # Check pod readiness directly (more reliable than deployment conditions)
            # Get all ArgoCD pods and check if they're all ready
            try {
                $pods = kubectl get pods -n argocd -o json 2>&1
                if ($LASTEXITCODE -eq 0 -and $pods) {
                    $podList = $pods | ConvertFrom-Json
                    if ($podList.items) {
                        $argocdPods = $podList.items | Where-Object { $_.metadata.name -like "argocd-*" }
                        $totalPods = $argocdPods.Count
                        $readyPods = 0
                        
                        foreach ($pod in $argocdPods) {
                            # Check if pod is ready (all containers ready and phase is Running)
                            $podReady = $true
                            
                            # Check pod phase
                            if ($pod.status.phase -ne "Running") {
                                $podReady = $false
                            }
                            
                            # Check all containers are ready
                            if ($podReady -and $pod.status.containerStatuses) {
                                foreach ($cs in $pod.status.containerStatuses) {
                                    if (-not $cs.ready) {
                                        $podReady = $false
                                        break
                                    }
                                }
                            } elseif ($podReady) {
                                # No container statuses yet
                                $podReady = $false
                            }
                            
                            if ($podReady) {
                                $readyPods++
                            }
                        }
                        
                        # All pods ready = all components ready
                        if ($totalPods -gt 0 -and $readyPods -eq $totalPods) {
                            $readyComponents = $totalComponents
                        } else {
                            # Fallback: check components individually
            foreach ($component in $components) {
                try {
                    $isReady = $false
                    if ($component.type -eq "deployment") {
                        $availableStatus = kubectl get deployment $component.name -n argocd -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>&1
                                        if ($availableStatus -eq "True") {
                                        $isReady = $true
                        }
                    } elseif ($component.type -eq "statefulset") {
                        $readyReplicas = kubectl get statefulset $component.name -n argocd -o jsonpath='{.status.readyReplicas}' 2>&1
                        $desiredReplicas = kubectl get statefulset $component.name -n argocd -o jsonpath='{.spec.replicas}' 2>&1
                        
                                        if (-not [string]::IsNullOrWhiteSpace($readyReplicas) -and -not [string]::IsNullOrWhiteSpace($desiredReplicas)) {
                            $readyReplicasInt = 0
                            $desiredReplicasInt = 0
                            if ([int]::TryParse($readyReplicas, [ref]$readyReplicasInt) -and [int]::TryParse($desiredReplicas, [ref]$desiredReplicasInt)) {
                                if ($readyReplicasInt -ge $desiredReplicasInt -and $readyReplicasInt -gt 0) {
                                    $isReady = $true
                                }
                            }
                        }
                    }
                    
                    if ($isReady) {
                        $readyComponents++
                    }
                } catch {
                    # Component not ready yet - continue checking
                }
                            }
                        }
                    }
                }
            } catch {
                # Pods not available yet - continue checking
            }
            
            # Show progress with component status
            Write-Progress -Activity "Waiting for ArgoCD" -Status "Components ready: $readyComponents/$totalComponents (${elapsed}s elapsed)"
            
            if ($readyComponents -eq $totalComponents) {
                $allReady = $true
                Write-Progress -Activity "Waiting for ArgoCD" -Status "All components ready!" -Completed
                Write-Host ""
                Write-Host "[OK] All ArgoCD components are ready!" -ForegroundColor Green
                break
            }
            
            Start-Sleep -Seconds $checkInterval
            $elapsed += $checkInterval
        }
        
        Write-Progress -Activity "Waiting for ArgoCD" -Completed
        
        # Final verification with kubectl wait for critical component
        $waitExitCode = 0
        if (-not $allReady) {
            Write-Host ""
            Write-Info "Performing final verification..."
            kubectl wait --for=condition=available deployment/argocd-server -n argocd --timeout=60s 2>&1 | Out-Null
            $waitExitCode = $LASTEXITCODE
        }
        
        # Show final pod status
        Write-Host ""
        Write-Info "Final ArgoCD pod status:"
        kubectl get pods -n argocd | Select-String -Pattern "argocd-" | Out-Host
        $getPodsExitCode = $LASTEXITCODE
        
        # Verify deployment readiness: if allReady was false, both wait and get pods must succeed
        # If allReady was true, at least get pods must succeed
        $deploymentReady = if (-not $allReady) {
            ($waitExitCode -eq 0) -and ($getPodsExitCode -eq 0)
        } else {
            $getPodsExitCode -eq 0
        }
        
        if ($deploymentReady) {
            # Configure ArgoCD services for distributed deployment (podAntiAffinity)
            Write-Info "Configuring ArgoCD services for distributed deployment..."
            Configure-ArgoCDDistributed
            
            # Configure ArgoCD Application Controller to run only on leader node
            Write-Info "Configuring ArgoCD Application Controller to run only on leader node..."
            Configure-ArgoCDApplicationControllerLeader
            
            # Deploy ArgoCD HPA (after ArgoCD is installed)
            Write-Info "Deploying ArgoCD HPA..."
            $k8sDir = Join-Path $PSScriptRoot "..\k8s"
            $argocdHpaFile = Join-Path $k8sDir "06d-argocd-hpa.yaml"
            if (Test-Path $argocdHpaFile) {
                kubectl apply -f $argocdHpaFile 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-Success "ArgoCD HPA deployed"
                    
                    # Update ArgoCD HPA minReplicas after deployment
                    Write-Info "Updating ArgoCD HPA minReplicas based on node count..."
                    $nodes = kubectl get nodes --no-headers 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $nodeCount = ($nodes -split "`n" | Where-Object { $_ }).Count
                        if ($nodeCount -lt 1) { $nodeCount = 1 }
                        
                        $tempPatchFile = [System.IO.Path]::GetTempFileName()
                        try {
                            $patchJson = @{
                                spec = @{
                                    minReplicas = $nodeCount
                                }
                            } | ConvertTo-Json -Compress
                            
                            $patchJson | Out-File -FilePath $tempPatchFile -Encoding utf8 -NoNewline
                            
                            $argocdHpas = @("argocd-server-hpa", "argocd-repo-server-hpa")
                            foreach ($hpaName in $argocdHpas) {
                                # ArgoCD HPAs are in 'argocd' namespace
                                kubectl patch hpa $hpaName -n argocd --type='merge' --patch-file=$tempPatchFile 2>&1 | Out-Null
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Info "Updated $hpaName minReplicas to $nodeCount in namespace argocd"
                                } else {
                                    Write-Warn "Failed to update $hpaName minReplicas in namespace argocd"
                                }
                            }
                        } finally {
                            if (Test-Path $tempPatchFile) {
                                Remove-Item $tempPatchFile -Force -ErrorAction SilentlyContinue
                            }
                        }
                    }
                } else {
                    Write-Warn "ArgoCD HPA deployment encountered issues"
                }
            } else {
                Write-Warn "ArgoCD HPA manifest not found, skipping..."
            }
            
            # Create ArgoCD repository credential (for GitHub access)
            Write-Info "Creating ArgoCD repository credential for GitHub..."
            Create-ArgoCDRepoCredential
            
            # Create ArgoCD application
            $argocdAppFile = Join-Path $PSScriptRoot "..\k8s\13-argocd-application.yaml"
            if (Test-Path $argocdAppFile) {
                Write-Info "Creating ArgoCD application..."
                # Suppress warnings (like finalizer warnings) - they are not errors
                $ErrorActionPreference = "SilentlyContinue"
                $applyOutput = kubectl apply -f $argocdAppFile 2>&1
                $ErrorActionPreference = "Stop"
                
                # Filter out warnings and check for real errors
                $errors = $applyOutput | Where-Object { $_ -match '^Error|^error:' -and $_ -notmatch 'Warning' }
                if ($LASTEXITCODE -eq 0 -and -not $errors) {
                    # Check if there are warnings (these are OK)
                    $warnings = $applyOutput | Where-Object { $_ -match 'Warning' }
                    if ($warnings) {
                        Write-Info "ArgoCD application created (warnings can be ignored)"
                    } else {
                        Write-Success "ArgoCD application created"
                    }
                } else {
                    Write-Warn "ArgoCD application creation encountered issues, but continuing..."
                }
            }
            
            Write-Success "ArgoCD deployed"
            Write-Info "Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath={''{.data.password}''} | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String(`$_)) }"
            Write-Info "Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
        }
    } else {
        Write-Warn "ArgoCD installation failed"
    }
}

# Create ArgoCD repository credential for GitHub
function Create-ArgoCDRepoCredential {
    Write-Info "Creating ArgoCD repository credential for GitHub..."
    
    # Determine ArgoCD namespace (check where ArgoCD is installed)
    $argocdNamespace = "argocd"  # Default namespace
    $argocdPods = kubectl get pods -A -o json 2>&1 | ConvertFrom-Json
    if ($argocdPods -and $argocdPods.items) {
        $firstArgoCDPod = $argocdPods.items | Where-Object { $_.metadata.name -like "*argocd*" } | Select-Object -First 1
        if ($firstArgoCDPod) {
            $argocdNamespace = $firstArgoCDPod.metadata.namespace
            Write-Info "Detected ArgoCD namespace: $argocdNamespace"
        }
    }
    
    # Get GitHub token from environment variables or app-secrets
    # NOTE: Workflow (GitHub Actions) handles secret updates from GitHub Secrets
    # This function is only for bootstrap/initial setup
    # Priority: Environment variable > app-secrets > empty (public repo)
    $githubToken = [Environment]::GetEnvironmentVariable("ACCESS_TOKEN_GITHUB", "Process")
    
    if ([string]::IsNullOrWhiteSpace($githubToken)) {
        # Try to get from app-secrets
        try {
            $appSecrets = kubectl get secret app-secrets -n finans-asistan -o jsonpath='{.data.ACCESS_TOKEN_GITHUB}' 2>&1
            if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($appSecrets)) {
                $githubToken = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($appSecrets))
                Write-Info "Found ACCESS_TOKEN_GITHUB in app-secrets"
            }
        } catch {
            # app-secrets not found or doesn't have ACCESS_TOKEN_GITHUB
        }
    } else {
        Write-Info "Found ACCESS_TOKEN_GITHUB in environment variables"
    }
    
    if ([string]::IsNullOrWhiteSpace($githubToken)) {
        Write-Warn "ACCESS_TOKEN_GITHUB not found, ArgoCD will use public repository access"
        Write-Warn "For private repositories, set ACCESS_TOKEN_GITHUB in GitHub Secrets or QUICK_START/.env"
        
        # Create repository secret without credentials (public repo)
        kubectl create secret generic argocd-repo-github `
            --from-literal=type=git `
            --from-literal=url=https://github.com/JstLearn/FinansAsistan.git `
            -n $argocdNamespace `
            --dry-run=client -o yaml | kubectl apply -f - 2>&1 | Out-Null
        
        # Add ArgoCD label for repository secret
        kubectl label secret argocd-repo-github `
            argocd.argoproj.io/secret-type=repository `
            -n $argocdNamespace `
            --overwrite 2>&1 | Out-Null
        
        Write-Info "ArgoCD repository secret created (public access) in namespace: $argocdNamespace"
        return
    }
    
    # Create repository secret with GitHub token
    Write-Info "Creating ArgoCD repository secret with GitHub token..."
    
    # Delete existing secret if exists
    kubectl delete secret argocd-repo-github -n $argocdNamespace --ignore-not-found 2>&1 | Out-Null
    
    # Create new secret with GitHub token
    $githubToken = $githubToken.Trim()
    kubectl create secret generic argocd-repo-github `
        --from-literal=type=git `
        --from-literal=url=https://github.com/JstLearn/FinansAsistan.git `
        --from-literal=password=$githubToken `
        --from-literal=username=git `
        -n $argocdNamespace `
        --dry-run=client -o yaml | kubectl apply -f - 2>&1 | Out-Null
    
    if ($LASTEXITCODE -eq 0) {
        # Add ArgoCD label for repository secret
        kubectl label secret argocd-repo-github `
            argocd.argoproj.io/secret-type=repository `
            -n $argocdNamespace `
            --overwrite 2>&1 | Out-Null
        
        Write-Success "ArgoCD repository credential created with GitHub token in namespace: $argocdNamespace"
        
        # Restart ArgoCD repo-server to pick up new credential
        Write-Info "Restarting ArgoCD repo-server to apply new credential..."
        kubectl rollout restart deployment argocd-repo-server -n $argocdNamespace 2>&1 | Out-Null
        
        # Wait a moment for repo-server to restart
        Start-Sleep -Seconds 5
    } else {
        Write-Warn "Failed to create ArgoCD repository credential"
    }
}

# Configure ArgoCD services for distributed deployment
function Configure-ArgoCDDistributed {
    Write-Info "Removing affinity constraints from ArgoCD services for distributed deployment..."
    Write-Info "Each node will have at least 1 pod, but can have more based on load (HPA minReplicas = node count)"
    
    # Check if argocd-server exists and has affinity, then remove it
    try {
        $serverExists = kubectl get deployment argocd-server -n argocd --ignore-not-found 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $serverExists -match "argocd-server") {
            $serverAffinity = kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.template.spec.affinity}' 2>&1
            if ($LASTEXITCODE -eq 0 -and $serverAffinity -and $serverAffinity -ne "null" -and -not [string]::IsNullOrWhiteSpace($serverAffinity)) {
                # Use JSON patch to remove affinity - use patch file to avoid PowerShell string escaping issues
                $tempPatchFile = [System.IO.Path]::GetTempFileName()
                try {
                    $patchJson = '{"spec":{"template":{"spec":{"affinity":null}}}}'
                    $patchJson | Out-File -FilePath $tempPatchFile -Encoding utf8 -NoNewline
                    $patchResult = kubectl patch deployment argocd-server -n argocd --type='merge' --patch-file=$tempPatchFile 2>&1 | Out-String
                } finally {
                    if (Test-Path $tempPatchFile) {
                        Remove-Item $tempPatchFile -Force -ErrorAction SilentlyContinue
                    }
                }
                if ($LASTEXITCODE -eq 0) {
                    Write-Info "ArgoCD Server configured for distributed deployment (affinity removed)"
                } else {
                    Write-Warn "Failed to remove affinity from argocd-server: $patchResult"
                }
            } else {
                Write-Info "ArgoCD Server has no affinity constraints (already configured)"
            }
        } else {
            Write-Info "ArgoCD Server deployment not found (may not be deployed yet)"
        }
    } catch {
        Write-Warn "Error checking argocd-server: $_"
    }
    
    # Check if argocd-repo-server exists and has affinity, then remove it
    try {
        $repoExists = kubectl get deployment argocd-repo-server -n argocd --ignore-not-found 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $repoExists -match "argocd-repo-server") {
            $repoAffinity = kubectl get deployment argocd-repo-server -n argocd -o jsonpath='{.spec.template.spec.affinity}' 2>&1
            if ($LASTEXITCODE -eq 0 -and $repoAffinity -and $repoAffinity -ne "null" -and -not [string]::IsNullOrWhiteSpace($repoAffinity)) {
                # Use JSON patch to remove affinity - use patch file to avoid PowerShell string escaping issues
                $tempPatchFile = [System.IO.Path]::GetTempFileName()
                try {
                    $patchJson = '{"spec":{"template":{"spec":{"affinity":null}}}}'
                    $patchJson | Out-File -FilePath $tempPatchFile -Encoding utf8 -NoNewline
                    $patchResult = kubectl patch deployment argocd-repo-server -n argocd --type='merge' --patch-file=$tempPatchFile 2>&1 | Out-String
                } finally {
                    if (Test-Path $tempPatchFile) {
                        Remove-Item $tempPatchFile -Force -ErrorAction SilentlyContinue
                    }
                }
                if ($LASTEXITCODE -eq 0) {
                    Write-Info "ArgoCD Repo Server configured for distributed deployment (affinity removed)"
                } else {
                    Write-Warn "Failed to remove affinity from argocd-repo-server: $patchResult"
                }
            } else {
                Write-Info "ArgoCD Repo Server has no affinity constraints (already configured)"
            }
        } else {
            Write-Info "ArgoCD Repo Server deployment not found (may not be deployed yet)"
        }
    } catch {
        Write-Warn "Error checking argocd-repo-server: $_"
    }
    
    # Note: argocd-application-controller is leader-only, so we don't modify it here
    
    Write-Success "ArgoCD services configured for distributed deployment"
}

# Configure ArgoCD Application Controller to run only on leader node
function Configure-ArgoCDApplicationControllerLeader {
    Write-Info "Configuring ArgoCD Application Controller to run only on leader node..."
    
    # Use JSON Patch format to add nodeAffinity while preserving existing affinity (podAntiAffinity)
    # JSON Patch allows us to add nodeAffinity to existing affinity structure
    $patchJson = @"
[
  {
    "op": "add",
    "path": "/spec/template/spec/affinity/nodeAffinity",
    "value": {
      "requiredDuringSchedulingIgnoredDuringExecution": {
        "nodeSelectorTerms": [
          {
            "matchExpressions": [
              {
                "key": "leader",
                "operator": "In",
                "values": ["true"]
              }
            ]
          }
        ]
      }
    }
  }
]
"@
    
    $tempPatchFile = Join-Path $env:TEMP "argocd-controller-leader-patch.json"
    $patchJson | Out-File -FilePath $tempPatchFile -Encoding utf8 -NoNewline
    
    try {
        kubectl patch statefulset argocd-application-controller -n argocd --type='json' --patch-file=$tempPatchFile 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Info "ArgoCD Application Controller configured to run only on leader node"
        } else {
            # If patch fails, it might already be configured, so check current state
            $currentAffinity = kubectl get statefulset argocd-application-controller -n argocd -o jsonpath='{.spec.template.spec.affinity.nodeAffinity}' 2>&1
            if ($currentAffinity -and -not [string]::IsNullOrWhiteSpace($currentAffinity)) {
                Write-Info "ArgoCD Application Controller already has nodeAffinity configured"
            } else {
                Write-Warn "Failed to patch argocd-application-controller with leader node affinity"
            }
        }
    } catch {
        Write-Warn "Error patching argocd-application-controller: $_"
    } finally {
        if (Test-Path $tempPatchFile) {
            Remove-Item $tempPatchFile -Force -ErrorAction SilentlyContinue
        }
    }
    
    Write-Success "ArgoCD Application Controller configured for leader node only"
}

# Health check
function Test-Health {
    Write-Info "Running health checks..."
    
    # Check pods
    $pods = kubectl get pods -n finans-asistan --no-headers 2>&1
    if ($LASTEXITCODE -eq 0) {
        $runningPods = ($pods | Where-Object { $_ -match "Running|Completed" }).Count
        $totalPods = ($pods -split "`n" | Where-Object { $_ }).Count
        Write-Info "Pods: $runningPods/$totalPods running"
    }
    
    # Check services
    $services = kubectl get svc -n finans-asistan --no-headers 2>&1
    if ($LASTEXITCODE -eq 0) {
        $serviceCount = ($services -split "`n" | Where-Object { $_ }).Count
        Write-Info "Services: $serviceCount available"
    }
    
    Write-Success "Health checks completed"
}

# Show summary
function Show-Summary {
    Write-Host ""
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host "  [OK] Bootstrap Completed Successfully!" -ForegroundColor Green
    Write-Host "===========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Kubernetes Cluster: Docker Desktop Kubernetes" -ForegroundColor White
    Write-Host "GitOps: ArgoCD (automatic sync from GitHub)" -ForegroundColor White
    Write-Host ""
    Write-Host "Useful Commands:" -ForegroundColor Cyan
    Write-Host "  Check pods:      kubectl get pods -n finans-asistan" -ForegroundColor White
    Write-Host "  Check services:  kubectl get svc -n finans-asistan" -ForegroundColor White
    Write-Host "  View logs:       kubectl logs -f deployment/backend -n finans-asistan" -ForegroundColor White
    Write-Host "  ArgoCD status:   kubectl get applications -n finans-asistan" -ForegroundColor White
    Write-Host ""
}

# Main execution
Write-Host ""
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host "  FinansAsistan - Kubernetes Bootstrap (Windows)" -ForegroundColor Cyan
Write-Host "===========================================================" -ForegroundColor Cyan
Write-Host ""

# Error tracking for final summary
$script:bootstrapErrors = @()
$script:bootstrapWarnings = @()

function Invoke-BootstrapStep {
    param(
        [string]$StepName,
        [scriptblock]$StepScript
    )
    Write-Info "=========================================="
    Write-Info "Executing: $StepName"
    Write-Info "=========================================="
    try {
        $ErrorActionPreference = "Continue"
        & $StepScript
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            $script:bootstrapErrors += "$StepName failed (exit code: $LASTEXITCODE)"
            Write-Warn "$StepName completed with errors (exit code: $LASTEXITCODE), continuing..."
        } else {
            Write-Success "$StepName completed successfully"
        }
    } catch {
        $script:bootstrapErrors += "$StepName failed: $_"
        Write-Warn "$StepName failed: $_, continuing with next steps..."
    }
}

# Main execution with error handling
Write-Info "Starting FinansAsistan Kubernetes bootstrap..."
Write-Info "Note: Script will attempt to deploy all resources even if some steps fail"
Write-Host ""

Invoke-BootstrapStep "Check-Prerequisites" { Check-Prerequisites }
Invoke-BootstrapStep "Check-AwsCredentials" { Check-AwsCredentials }
Invoke-BootstrapStep "Create-Namespace" { Create-Namespace }
Invoke-BootstrapStep "Generate-KubernetesSecrets" { Generate-KubernetesSecrets }
Invoke-BootstrapStep "Install-Operators" { Install-Operators }
Invoke-BootstrapStep "Create-ECRSecret" { Create-ECRSecret }
Invoke-BootstrapStep "Deploy-InitContainerRBAC" { Deploy-InitContainerRBAC }
Invoke-BootstrapStep "Deploy-PostgreSQL" { Deploy-PostgreSQL }
Invoke-BootstrapStep "Deploy-Kafka" { Deploy-Kafka }
Invoke-BootstrapStep "Deploy-Redis" { Deploy-Redis }
Invoke-BootstrapStep "Deploy-Applications" { Deploy-Applications }
Invoke-BootstrapStep "Deploy-HPA" { Deploy-HPA }
Invoke-BootstrapStep "Deploy-Monitoring" { Deploy-Monitoring }
# Cluster Autoscaler removed - not needed for Docker Desktop compatibility
Invoke-BootstrapStep "Deploy-ArgoCD" { Deploy-ArgoCD }
Invoke-BootstrapStep "Test-Health" { Test-Health }
Invoke-BootstrapStep "Show-Summary" { Show-Summary }

Write-Host ""
Write-Info "=========================================="
Write-Info "Bootstrap Summary"
Write-Info "=========================================="

if ($script:bootstrapErrors.Count -gt 0) {
    Write-Warn "Bootstrap completed with $($script:bootstrapErrors.Count) error(s):"
    foreach ($err in $script:bootstrapErrors) {
        Write-Warn "  - $error"
    }
    Write-Host ""
    Write-Warn "Some resources may not be deployed. Check logs above for details."
    Write-Info "You can manually retry failed steps or check resource status with:"
    Write-Info "  kubectl get pods -n finans-asistan"
    Write-Info "  kubectl get deployments -n finans-asistan"
    Write-Info "  kubectl get statefulsets -n finans-asistan"
} else {
    Write-Success "Bootstrap completed successfully! All resources deployed."
}

Write-Host ""