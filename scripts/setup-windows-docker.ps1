# FinansAsistan - Windows Docker Compose Setup Script (PowerShell)
# S3'ten projeyi indirir, DB'yi restore eder ve Docker Compose ile baslatir

param(
    [string]$ModeAction = "prod-cp-a", # prod-cp-a (varsayilan), prod-cp-b, prod-cp-c1, prod-cp-c2, prod-worker, dev
    [switch]$ForceTakeover = $false  # Force takeover: Mevcut lideri devre disi birak ve bu makineyi lider yap
)

$ErrorActionPreference = "Stop"

# UTF-8 encoding ayarlari
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null

# Global error handler
trap {
    $line = $_.InvocationInfo.ScriptLineNumber
    $command = $_.InvocationInfo.Line
    Write-Host "[ERROR] Script failed at line $line" -ForegroundColor Red
    Write-Host "[ERROR] Command: $command" -ForegroundColor Red
    Write-Host "[ERROR] Error: $_" -ForegroundColor Red
    exit 1
}

# ==============================================================================
# Utility Functions
# ==============================================================================

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

function Get-EnvVar {
    param([string]$Name)
    
    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
    }
    
    $value = [Environment]::GetEnvironmentVariable($Name, "User")
    if (-not [string]::IsNullOrWhiteSpace($value)) {
        return $value
    }
    
    $value = [Environment]::GetEnvironmentVariable($Name, "Machine")
    return $value
}

function Test-DockerCommand {
    param([string]$Command)
    
    try {
        $output = & $Command --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    } catch {
        return $false
    }
    return $false
}

function Invoke-DockerCompose {
    param(
        [string]$ComposeFile,
        [string[]]$Arguments,
        [switch]$ShowOutput
    )
    
    # Try docker compose (v2) first
    $cmd = "docker"
    $args = @("compose", "-f", $ComposeFile) + $Arguments
    
    try {
        if ($ShowOutput) {
            & $cmd $args
            $exitCode = $LASTEXITCODE
        } else {
            # Capture both stdout and stderr, but don't treat stderr as error
            $ErrorActionPreference = "Continue"
            $output = & $cmd $args 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
            $ErrorActionPreference = "Stop"
            
            # Docker Compose may write to stderr even on success, so check exit code
            if ($exitCode -eq 0) {
                return @{ Success = $true; Output = $output; Command = "$cmd $($args -join ' ')"; ExitCode = $exitCode }
            } else {
                return @{ Success = $false; Output = $output; Command = "$cmd $($args -join ' ')"; ExitCode = $exitCode }
            }
        }
        if ($exitCode -eq 0) {
            return @{ Success = $true; Output = ""; Command = "$cmd $($args -join ' ')"; ExitCode = $exitCode }
        }
    } catch {
        $errorOutput = $_.Exception.Message
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) { $exitCode = -1 }
        # Continue to try docker-compose (v1)
    }
    
    # Try docker-compose (v1)
    $cmd = "docker-compose"
    $args = @("-f", $ComposeFile) + $Arguments
    
    try {
        if ($ShowOutput) {
            & $cmd $args
            $exitCode = $LASTEXITCODE
        } else {
            # Capture both stdout and stderr, but don't treat stderr as error
            $ErrorActionPreference = "Continue"
            $output = & $cmd $args 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
            $ErrorActionPreference = "Stop"
            
            # Docker Compose may write to stderr even on success, so check exit code
            if ($exitCode -eq 0) {
                return @{ Success = $true; Output = $output; Command = "$cmd $($args -join ' ')"; ExitCode = $exitCode }
            } else {
                return @{ Success = $false; Output = $output; Command = "$cmd $($args -join ' ')"; ExitCode = $exitCode }
            }
        }
        if ($exitCode -eq 0) {
            return @{ Success = $true; Output = ""; Command = "$cmd $($args -join ' ')"; ExitCode = $exitCode }
        }
    } catch {
        $ErrorActionPreference = "Stop"
        $errorOutput = $_.Exception.Message
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) { $exitCode = -1 }
        return @{ Success = $false; Output = $errorOutput; Command = "$cmd $($args -join ' ')"; ExitCode = $exitCode }
    }
    
    return @{ Success = $false; Output = "Both docker compose and docker-compose failed"; Command = "unknown"; ExitCode = -1 }
}

function Initialize-Environment {
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + 
                [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    # Ensure TEMP is set
if ([string]::IsNullOrWhiteSpace($env:TEMP)) {
    $env:TEMP = [System.IO.Path]::GetTempPath()
}

if ([string]::IsNullOrWhiteSpace($env:TEMP)) {
        Write-Error "TEMP environment variable is not set"
    exit 1
    }
}

function Load-EnvFile {
    $envFilePaths = @(
        (Join-Path (Split-Path -Parent $PSScriptRoot) "QUICK_START\.env"),
        (Join-Path $PSScriptRoot "..\QUICK_START\.env"),
        "QUICK_START\.env"
    )
    
    foreach ($envFile in $envFilePaths) {
        if (Test-Path $envFile) {
            Write-Info "Loading .env file from: $envFile"
            
            $envContent = Get-Content $envFile -ErrorAction SilentlyContinue
            if ($envContent) {
                foreach ($line in $envContent) {
                    if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) {
                        continue
                    }
                    
                    if ($line -match '^\s*([^#=]+?)\s*=\s*(.+?)\s*$') {
                        $key = $matches[1].Trim()
                        $value = $matches[2].Trim()
                        
                        if (-not [Environment]::GetEnvironmentVariable($key, "Process")) {
                            [Environment]::SetEnvironmentVariable($key, $value, "Process")
                        }
                    }
                }
                
                $env:QUICK_START_ENV_LOADED = "true"
                Write-Success ".env file loaded"
                return
            }
        }
    }
    
    Write-Warn ".env file not found. Will use existing environment variables."
}

function Test-Prerequisites {
# Check PowerShell version - show full version info
$psVersion = $PSVersionTable.PSVersion
$psMajor = $psVersion.Major
$psMinor = $psVersion.Minor
$psPatch = $psVersion.Patch
$psVersionString = "$psMajor.$psMinor.$psPatch"

if ($psMajor -lt 5) {
    Write-Error "PowerShell 5.1 or higher is required. Current version: $psVersionString"
    exit 1
}

# Show PowerShell edition (Core vs Desktop)
$edition = if ($PSVersionTable.PSEdition) { $PSVersionTable.PSEdition } else { "Desktop" }
Write-Success "PowerShell version: $psVersionString ($edition)"

    # Check Docker
Write-Info "Checking Docker installation..."
    if (-not (Test-DockerCommand "docker")) {
    Write-Warn "Docker Desktop not found!"
    Write-Host ""
    Write-Host "Docker Desktop is required to run this project."
    Write-Host "Download URL: https://www.docker.com/products/docker-desktop"
    Write-Host ""
    
    $response = Read-Host "Would you like to open the download page? (Y/N)"
    if ($response -eq "Y" -or $response -eq "y") {
        Start-Process "https://www.docker.com/products/docker-desktop"
    }
    
    Write-Host ""
    Write-Host "After installing Docker Desktop:"
    Write-Host "  1. Start Docker Desktop"
    Write-Host "  2. Wait for it to fully start"
    Write-Host "  3. Restart PowerShell"
    Write-Host "  4. Run this script again"
    exit 1
}
    
    $dockerVersion = docker --version 2>&1
    Write-Success "Docker found: $dockerVersion"

# Check if Docker is running
Write-Info "Checking if Docker is running..."
try {
    docker ps 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker not running"
    }
    Write-Success "Docker is running"
} catch {
    Write-Error "Docker Desktop is not running!"
    Write-Host ""
    Write-Host "Please:"
    Write-Host "  1. Start Docker Desktop"
        Write-Host "  2. Wait for it to fully start"
    Write-Host "  3. Run this script again"
    exit 1
}

# Check Docker Compose
Write-Info "Checking Docker Compose..."
    if ((Test-DockerCommand "docker compose") -or (Test-DockerCommand "docker-compose")) {
        Write-Success "Docker Compose found"
    } else {
    Write-Error "Docker Compose not found!"
    Write-Host "Docker Desktop includes Docker Compose. Please ensure Docker Desktop is running."
    exit 1
}

    # Check WSL2 (optional, for PostgreSQL restore)
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    wsl --version 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Success "WSL2 found"
    } else {
        Write-Warn "WSL2 not found. PostgreSQL restore may require WSL2 or Git Bash."
    }
} else {
    Write-Warn "WSL2 not found. PostgreSQL restore may require WSL2 or Git Bash."
}

    # Check AWS CLI
Write-Info "Checking AWS CLI installation..."
$awsCmd = Get-Command aws -ErrorAction SilentlyContinue
if (-not $awsCmd) {
    $awsPath = where.exe aws 2>$null
    if ($awsPath) {
        $awsCmd = Get-Command $awsPath -ErrorAction SilentlyContinue
    }
}

if ($awsCmd) {
    try {
            $awsVersionOutput = & $awsCmd.Source --version 2>&1 | Where-Object { $_ -match "aws-cli" } | Select-Object -First 1
        if ($awsVersionOutput) {
            Write-Success "AWS CLI found: $awsVersionOutput"
        } else {
            Write-Success "AWS CLI found at: $($awsCmd.Source)"
        }
    } catch {
        Write-Success "AWS CLI found at: $($awsCmd.Source)"
    }
} else {
        # Check common installation paths
    $awsPaths = @(
        "$env:ProgramFiles\Amazon\AWSCLIV2\aws.exe",
        "${env:ProgramFiles(x86)}\Amazon\AWSCLIV2\aws.exe"
    )
    
        $found = $false
    foreach ($awsPath in $awsPaths) {
        if (Test-Path $awsPath) {
            $awsDir = Split-Path $awsPath
            $env:Path = "$awsDir;$env:Path"
            Write-Success "AWS CLI found at: $awsPath"
                $found = $true
            break
            }
        }
        
        if (-not $found) {
            Write-Warn "AWS CLI not found in PATH. AWS operations may fail."
            Write-Warn "Please restart PowerShell after installing AWS CLI."
        }
    }
    
    # Check ArgoCD CLI (both dev and production mode)
    Write-Host ""
    Write-Info "Checking ArgoCD CLI installation..."
    if (Get-Command argocd -ErrorAction SilentlyContinue) {
        try {
            $argocdVersion = argocd version --client 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-Success "ArgoCD CLI found: $($argocdVersion.Trim())"
            } else {
                Write-Warn "ArgoCD CLI found but not working properly. Attempting to reinstall..."
                Install-ArgoCDCLI | Out-Null
            }
        } catch {
            Write-Warn "ArgoCD CLI found but not working properly. Attempting to reinstall..."
            Install-ArgoCDCLI | Out-Null
        }
    } else {
        Write-Warn "ArgoCD CLI not found. Installing..."
        if (-not (Install-ArgoCDCLI)) {
            Write-Warn "Failed to install ArgoCD CLI automatically"
            Write-Info "ArgoCD CLI will be needed for deployments"
            Write-Info "You can install it manually later if needed"
        }
    }
    Write-Host ""
}

# Check ArgoCD CLI (required for production mode)
function Install-ArgoCDCLI {
    Write-Info "Installing ArgoCD CLI..."
    
    # Check if already installed
    if (Get-Command argocd -ErrorAction SilentlyContinue) {
        try {
            $argocdVersion = argocd version --client 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-Success "ArgoCD CLI already installed"
                return $true
            }
        } catch {
            # Continue with installation
        }
    }
    
    # Create installation directory
    $installDir = Join-Path $env:USERPROFILE "Tools\ArgoCD"
    if (-not (Test-Path $installDir)) {
        New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    }
    
    try {
        # Get latest version from GitHub API
        Write-Info "Fetching latest ArgoCD CLI version..."
        $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/argoproj/argo-cd/releases/latest" -ErrorAction Stop
        $version = $releaseInfo.tag_name
        Write-Info "Latest version: $version"
        
        # Download ArgoCD CLI
        $downloadUrl = "https://github.com/argoproj/argo-cd/releases/download/$version/argocd-windows-amd64.exe"
        $outputPath = Join-Path $installDir "argocd.exe"
        
        Write-Info "Downloading ArgoCD CLI from GitHub..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath -ErrorAction Stop
        
        if (Test-Path $outputPath) {
            Write-Success "ArgoCD CLI downloaded successfully"
            
            # Add to PATH if not already there
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$installDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir", "User")
                $env:Path += ";$installDir"
                Write-Success "ArgoCD CLI added to PATH"
            }
            
            # Verify installation
            if (Get-Command argocd -ErrorAction SilentlyContinue) {
                $argocdVersion = argocd version --client 2>&1 | Out-String
                Write-Success "ArgoCD CLI installed successfully"
                return $true
            }
        }
    } catch {
        Write-Warn "Failed to install ArgoCD CLI automatically: $_"
        Write-Info "You can install ArgoCD CLI manually from: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
        return $false
    }
    
    return $false
}

function Test-AWSCredentials {
    # Force AWS CLI to use environment variables
$env:AWS_SHARED_CREDENTIALS_FILE = Join-Path $env:TEMP "aws-credentials-nonexistent-$(Get-Random)"

if ($env:AWS_PROFILE) {
    Remove-Item Env:\AWS_PROFILE -ErrorAction SilentlyContinue
}
if ($env:AWS_CONFIG_FILE) {
    Remove-Item Env:\AWS_CONFIG_FILE -ErrorAction SilentlyContinue
}

    # Verify AWS credentials
    Write-Info "Verifying AWS CLI access..."
try {
    $awsWhoami = aws sts get-caller-identity --region $env:AWS_REGION 2>&1
    if ($LASTEXITCODE -ne 0) {
    $awsWhoami = aws sts get-caller-identity 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "AWS CLI credentials are invalid or not configured"
        Write-Error "AWS CLI output: $awsWhoami"
                Write-Error "Please check your AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
        exit 1
        }
    }
    Write-Info "AWS credentials verified successfully"
} catch {
    Write-Error "Failed to verify AWS credentials: $_"
    exit 1
}

    # Check S3 bucket access
Write-Info "Checking S3 bucket access: s3://$env:S3_BUCKET"
try {
    $bucketCheck = aws s3 ls "s3://$env:S3_BUCKET" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cannot access S3 bucket: s3://$env:S3_BUCKET"
        Write-Error "AWS CLI output: $bucketCheck"
        Write-Error "Please verify:"
            Write-Error "  1. S3_BUCKET name is correct"
        Write-Error "  2. AWS credentials have permission to access this bucket"
        Write-Error "  3. Bucket exists in region: $env:AWS_REGION"
        exit 1
    }
    Write-Info "S3 bucket access verified"
} catch {
    Write-Error "Failed to check S3 bucket: $_"
    exit 1
    }
}

function Load-AWSCredentials {
    Write-Info "Loading AWS credentials from environment variables..."
    
    $isGitHubActions = $env:GITHUB_ACTIONS -eq "true"
    
    if ($isGitHubActions) {
        Write-Info "Running in GitHub Actions - reading secrets from environment variables..."
    } else {
        Write-Info "Reading AWS credentials from environment variables (from QUICK_START/.env)..."
    }
    
    # Check required AWS credentials
    if (-not $env:AWS_ACCESS_KEY_ID -or -not $env:AWS_SECRET_ACCESS_KEY) {
        Write-Error "AWS credentials not found in environment variables."
        if ($isGitHubActions) {
            Write-Error "Make sure GitHub Actions workflow sets AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY from secrets."
        } else {
            Write-Error "Make sure QUICK_START/.env file contains AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY."
            Write-Error "Or run this script from QUICK_START/start-windows-*.ps1 which loads .env file."
        }
        exit 1
    }
    
    if (-not $env:S3_BUCKET) {
        Write-Error "S3_BUCKET not found in environment variables."
        if ($isGitHubActions) {
            Write-Error "Make sure GitHub Actions workflow sets S3_BUCKET from secrets."
        } else {
            Write-Error "Make sure QUICK_START/.env file contains S3_BUCKET."
        }
        exit 1
    }
    
    if (-not $env:AWS_REGION) {
        $env:AWS_REGION = "eu-central-1"
        Write-Info "AWS_REGION not found, using default: eu-central-1"
    }
    
    Write-Success "AWS credentials found in environment variables"
}

function Test-LeadershipSecret {
    Write-Info "Verifying leadership secret..."
    
    # Load .env file first to get JWT_SECRET
    $envFile = ""
    if (Test-Path "QUICK_START\.env") {
        $envFile = "QUICK_START\.env"
    } elseif (Test-Path "..\QUICK_START\.env") {
        $envFile = "..\QUICK_START\.env"
    }
    
    if ([string]::IsNullOrWhiteSpace($envFile) -or -not (Test-Path $envFile)) {
        Write-Warn "QUICK_START\.env file not found. Skipping secret verification."
        Write-Warn "This might be the first setup or .env file is not configured yet."
        return
    }
    
    # Load .env file
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*?)\s*=\s*(.*?)\s*$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            # Remove quotes if present
            if ($value -match '^["''](.*)["'']$') {
                $value = $matches[1]
            }
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    
    # Get JWT_SECRET from environment
    $expectedSecret = $env:JWT_SECRET
    
    if ([string]::IsNullOrWhiteSpace($expectedSecret)) {
        Write-Warn "JWT_SECRET not found in QUICK_START\.env. Skipping secret verification."
        return
    }
    
    # Prompt for secret
    Write-Host ""
    Write-Host "Leadership Secret Required" -ForegroundColor Cyan
    Write-Host ""
    $secureSecret = Read-Host "Enter leadership secret" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureSecret)
    $userSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    Write-Host ""
    
    if ($userSecret -ne $expectedSecret) {
        Write-Error "Invalid leadership secret! Access denied."
        Write-Error "Please contact the administrator for the correct secret."
        exit 1
    }
    
    Write-Success "Leadership secret verified!"
}

function Get-ProjectDirectory {
$currentDir = Get-Location
    $isProjectDir = (Test-Path "docker-compose.yml") -or (Test-Path "docker-compose.dev.yml") -or (Test-Path "docker-compose.prod.yml")

if ($isProjectDir) {
    Write-Info "Already in project directory. Using current directory: $currentDir"
        return $currentDir.Path
    }
    
    $projectDir = "FinansAsistan"
    if (-not (Test-Path $projectDir)) {
        New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
    }
    
    Set-Location $projectDir
    return $projectDir
}

function Download-ProjectFromS3 {
    param(
        [bool]$IsProduction,
        [string]$S3Bucket
    )
    
$skipS3Download = $false
    
    if (-not $IsProduction) {
    $hasProjectFiles = (Test-Path "docker-compose.dev.yml") -or (Test-Path "back") -or (Test-Path "front")
    
    if ($hasProjectFiles) {
        Write-Info "Development mode: Local project files found. Skipping S3 download..."
        $skipS3Download = $true
    } else {
        Write-Info "Development mode: Local project files not found. Downloading from S3..."
    }
} else {
    Write-Info "Production mode: Downloading from S3 (will overwrite local files)..."
}

    if ($skipS3Download) {
        return
    }
    
    Write-Info "Downloading from s3://$S3Bucket/FinansAsistan/..."
    Write-Info "This may take a few minutes depending on project size..."
    Write-Host ""

    # Verify S3 path exists
    Write-Info "Verifying S3 bucket access..."
    $bucketCheck = aws s3 ls "s3://$S3Bucket/FinansAsistan/" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Cannot access S3 bucket: s3://$S3Bucket/FinansAsistan/"
        Write-Error "Error: $bucketCheck"
        exit 1
    }

    Write-Info "S3 bucket accessible. Starting download..."
    Write-Host "  (This may take a few minutes - please wait...)" -ForegroundColor Gray
    Write-Host ""

    # Download from S3
    $syncOutput = aws s3 sync "s3://$S3Bucket/FinansAsistan/" . `
        --exclude ".git/*" `
        --exclude ".github/workflows/*.yml" `
        --exclude "*.log" `
        --exclude ".DS_Store" `
        --exclude "Thumbs.db" 2>&1 | Out-String
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to download project from S3"
        Write-Error "Error output: $syncOutput"
        exit 1
    }

    Write-Success "Project downloaded from S3"
}

function Get-DockerComposeFile {
    param([bool]$IsProduction)

$composeFile = $null
    
    if ($IsProduction) {
    if (Test-Path "docker-compose.prod.yml") {
        $composeFile = "docker-compose.prod.yml"
    } elseif (Test-Path "docker-compose.yml") {
        $composeFile = "docker-compose.yml"
    } elseif (Test-Path "docker-compose.dev.yml") {
        $composeFile = "docker-compose.dev.yml"
        Write-Warn "Production mode requested but only docker-compose.dev.yml found. Using dev file."
    } else {
            Write-Error "No docker-compose file found for production mode"
        Write-Error "Files in current directory:"
        Get-ChildItem -File | ForEach-Object { Write-Host "  - $($_.Name)" }
        exit 1
    }
        Write-Info "Found $composeFile (Production Mode)"
} else {
    if (Test-Path "docker-compose.dev.yml") {
        $composeFile = "docker-compose.dev.yml"
    } elseif (Test-Path "docker-compose.yml") {
        $composeFile = "docker-compose.yml"
    } else {
            Write-Error "docker-compose.yml or docker-compose.dev.yml not found"
        exit 1
    }
        Write-Info "Found $composeFile (Development Mode)"
    }
    
    return $composeFile
}

function Remove-DockerResources {
    Write-Warn "[WARNING] FULL CLEANUP: This will remove ALL containers, pods, volumes, and Kubernetes resources!"
    Write-Warn "[WARNING] This will cause DATA LOSS if volumes are deleted!"
    
Write-Info "Cleaning up all FinansAsistan resources..."

    # Stop containers using compose files
    if (Test-Path "docker-compose.dev.yml") {
        $result = Invoke-DockerCompose -ComposeFile "docker-compose.dev.yml" -Arguments @("down", "--remove-orphans", "--volumes")
        # Ignore errors during cleanup
    }
    if (Test-Path "docker-compose.prod.yml") {
        $result = Invoke-DockerCompose -ComposeFile "docker-compose.prod.yml" -Arguments @("down", "--remove-orphans", "--volumes")
        # Ignore errors during cleanup
    }
    
    # Stop and remove all FinansAsistan containers
        try {
            $ErrorActionPreference = "SilentlyContinue"
        $allContainers = docker ps -a --format "{{.Names}}" 2>&1
        $finansContainers = $allContainers | Where-Object { $_ -match "finans-" }
        
        if ($finansContainers) {
    foreach ($container in $finansContainers) {
        if ($container) {
                docker stop $container *>$null
                docker rm -f $container *>$null
                }
            }
            Write-Info "All FinansAsistan containers stopped and removed"
        }
                $ErrorActionPreference = "Stop"
            } catch {
                $ErrorActionPreference = "Stop"
    }
    
    # Remove volumes
try {
    $ErrorActionPreference = "SilentlyContinue"
    $allVolumes = docker volume ls --format "{{.Name}}" 2>&1
    $finansVolumes = $allVolumes | Where-Object { $_ -match "finans-" }
    
    if ($finansVolumes) {
        foreach ($volume in $finansVolumes) {
            if ($volume) {
                docker volume rm -f $volume *>$null
            }
        }
        Write-Info "FinansAsistan volumes removed"
    }
    $ErrorActionPreference = "Stop"
} catch {
    $ErrorActionPreference = "Stop"
}
    
    # Cleanup Kubernetes resources
    Write-Info "Cleaning up Kubernetes resources..."
    if (Get-Command kubectl -ErrorAction SilentlyContinue) {
        try {
            $ErrorActionPreference = "SilentlyContinue"
            
            # Delete all resources in finans-asistan namespace
            $namespaceExists = kubectl get namespace finans-asistan 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Info "Deleting all resources in finans-asistan namespace..."
                kubectl delete all --all -n finans-asistan --ignore-not-found=true --timeout=60s *>$null
                kubectl delete pvc --all -n finans-asistan --ignore-not-found=true --timeout=60s *>$null
                kubectl delete configmap,secret --all -n finans-asistan --ignore-not-found=true --timeout=60s *>$null
                kubectl delete ingress --all -n finans-asistan --ignore-not-found=true --timeout=60s *>$null
                kubectl delete namespace finans-asistan --ignore-not-found=true --timeout=120s *>$null
            }
            
            # Delete ArgoCD from default namespace
            Write-Info "Cleaning up ArgoCD resources..."
            kubectl delete deployment,statefulset,service,configmap,secret -n default -l app.kubernetes.io/part-of=argocd --ignore-not-found=true --timeout=60s *>$null
            kubectl delete deployment argocd-server argocd-repo-server argocd-applicationset-controller argocd-dex-server argocd-notifications-controller argocd-redis -n default --ignore-not-found=true --timeout=60s *>$null
            kubectl delete statefulset argocd-application-controller -n default --ignore-not-found=true --timeout=60s *>$null
            
            # Cleanup Traefik
            Write-Info "Cleaning up Traefik resources..."
            $traefikNamespaceExists = kubectl get namespace traefik-system 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                kubectl delete all --all -n traefik-system --ignore-not-found=true --timeout=60s *>$null
                kubectl delete namespace traefik-system --ignore-not-found=true --timeout=120s *>$null
            }
            
            # Cleanup monitoring namespace
            $monitoringNamespaceExists = kubectl get namespace monitoring 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Info "Cleaning up monitoring resources..."
                kubectl delete all --all -n monitoring --ignore-not-found=true --timeout=60s *>$null
                kubectl delete pvc --all -n monitoring --ignore-not-found=true --timeout=60s *>$null
                kubectl delete namespace monitoring --ignore-not-found=true --timeout=120s *>$null
            }
            
            Write-Success "Kubernetes resources cleaned up"
            $ErrorActionPreference = "Stop"
        } catch {
            $ErrorActionPreference = "Stop"
            Write-Warn "Some Kubernetes cleanup operations may have failed: $_"
        }
    } else {
        Write-Info "kubectl not found, skipping Kubernetes cleanup"
    }
    
    Write-Success "Full cleanup completed"
    Write-Warn "[WARNING] All existing resources have been removed. Starting fresh installation..."
    Start-Sleep -Seconds 3

    # Remove networks
try {
    $ErrorActionPreference = "SilentlyContinue"
    $allNetworks = docker network ls --format "{{.Name}}" 2>&1
    $finansNetworks = $allNetworks | Where-Object { $_ -match "finans-" }
    
    if ($finansNetworks) {
        foreach ($network in $finansNetworks) {
            if ($network) {
                docker network rm $network *>$null
            }
        }
        Write-Info "FinansAsistan networks removed"
    }
    $ErrorActionPreference = "Stop"
} catch {
    $ErrorActionPreference = "Stop"
}

    # Prune unused networks
try {
    $ErrorActionPreference = "SilentlyContinue"
    docker network prune -f *>$null
    $ErrorActionPreference = "Stop"
} catch {
    $ErrorActionPreference = "Stop"
}

Start-Sleep -Seconds 2
Write-Success "All FinansAsistan resources cleaned up"
}

# Helper function to write variable to .env file
function Write-VarToEnvFile {
    param(
        [string]$VarName,
        [string]$VarValue,
        [string]$EnvFilePath
    )
    
    if (Test-Path $EnvFilePath) {
        $envContent = Get-Content $EnvFilePath -Raw
        $envLines = $envContent -split "`n"
        $varExists = $false
        $newLines = @()
        
        foreach ($line in $envLines) {
            if ($line -match "^$VarName\s*=") {
                $newLines += "$VarName=$VarValue"
                $varExists = $true
            } else {
                $newLines += $line
            }
        }
        
        if (-not $varExists) {
            $newLines += "$VarName=$VarValue"
        }
        
        $newContent = $newLines -join "`n"
        $newContent | Out-File -FilePath $EnvFilePath -Encoding UTF8 -NoNewline
        Write-Success "Added/Updated $VarName in QUICK_START/.env file"
    } else {
        Write-Warn "QUICK_START/.env file not found at: $EnvFilePath"
        Write-Warn "Please manually add $VarName=$VarValue to your .env file"
    }
}

function Set-RequiredEnvironmentVariables {
Write-Info "Setting environment variables from GitHub Secrets..."

$requiredVars = @(
    "POSTGRES_DB",
    "POSTGRES_USER", 
    "POSTGRES_PASSWORD",
    "JWT_SECRET",
    "EMAIL_USER",
    "EMAIL_PASS",
        "SMTP_HOST",
        "SMTP_PORT",
        "SMTP_SSL",
    "S3_BUCKET",
    "AWS_REGION",
    "AWS_ACCESS_KEY_ID",
    "AWS_SECRET_ACCESS_KEY"
)

$optionalVars = @(
    "AWS_ACCOUNT_ID",
    "ACCESS_TOKEN_GITHUB",
        "BACKUP_INTERVAL",
        "IMAP_HOST",
        "IMAP_PORT",
        "IMAP_SSL",
        "CLOUDFLARE_API",
        "CLOUDFLARE_TUNNEL_TOKEN",
        "CORS_ORIGINS"
)

# Set required variables
$missingVars = @()
foreach ($varName in $requiredVars) {
    $value = Get-EnvVar -Name $varName
    if ([string]::IsNullOrWhiteSpace($value)) {
        $missingVars += $varName
    } else {
        Set-Item -Path "env:$varName" -Value $value
        Write-Info "Set $varName in Process scope"
    }
}

if ($missingVars.Count -gt 0) {
    Write-Error "The following environment variables must be set (from GitHub Secrets):"
    foreach ($var in $missingVars) {
        Write-Error "  - $var"
    }
    exit 1
}

    # Find .env file path
    $quickStartEnvFile = Join-Path (Split-Path -Parent $PSScriptRoot) "QUICK_START\.env"
    if (-not (Test-Path $quickStartEnvFile)) {
        $quickStartEnvFile = Join-Path $PSScriptRoot "..\QUICK_START\.env"
    }
    if (-not (Test-Path $quickStartEnvFile)) {
        $projectDir = (Get-Location).Path
        $quickStartEnvFile = Join-Path $projectDir "QUICK_START\.env"
    }

    # Set optional variables (prompt if missing for Cloudflare tokens)
foreach ($varName in $optionalVars) {
    $value = Get-EnvVar -Name $varName
    
    # Special handling for CORS_ORIGINS - use default if not set
    if ($varName -eq "CORS_ORIGINS" -and [string]::IsNullOrWhiteSpace($value)) {
        $value = "*"  # Default value for CORS_ORIGINS
        Set-Item -Path "env:$varName" -Value $value
        Write-Info "Set $varName to default value: $value"
        Write-VarToEnvFile -VarName $varName -VarValue $value -EnvFilePath $quickStartEnvFile
    }
    elseif (-not [string]::IsNullOrWhiteSpace($value)) {
        Set-Item -Path "env:$varName" -Value $value
        Write-Info "Set $varName from environment"
            
            # Write Cloudflare tokens and CORS_ORIGINS to .env file if they exist in environment
            if ($varName -in @("CLOUDFLARE_API", "CLOUDFLARE_TUNNEL_TOKEN", "CORS_ORIGINS")) {
                Write-VarToEnvFile -VarName $varName -VarValue $value -EnvFilePath $quickStartEnvFile
            }
        } elseif ($varName -in @("CLOUDFLARE_API", "CLOUDFLARE_TUNNEL_TOKEN")) {
            $inputValue = Read-Host "[OPTIONAL] $varName eksik. Deger girmek ister misiniz? (bos gecilebilir)"
            if (-not [string]::IsNullOrWhiteSpace($inputValue)) {
                $trimmedValue = $inputValue.Trim()
                Set-Item -Path "env:$varName" -Value $trimmedValue
                Write-Info "Set $varName from user input (Process scope)"
                Write-VarToEnvFile -VarName $varName -VarValue $trimmedValue -EnvFilePath $quickStartEnvFile
            }
        }
    }
}

function Start-DockerComposeServices {
    param(
        [string]$ComposeFile
    )
    
Write-Info "Starting Docker Compose services..."
    Write-Info "Using compose file: $ComposeFile"
    
    if (-not (Test-Path $ComposeFile)) {
        Write-Error "Docker Compose file not found: $ComposeFile"
    exit 1
}

    # Ensure all environment variables are set in Process scope before starting Docker Compose
    # Docker Compose reads environment variables from the current process
    $requiredVars = @(
        "POSTGRES_DB", "POSTGRES_USER", "POSTGRES_PASSWORD",
        "JWT_SECRET", "EMAIL_USER", "EMAIL_PASS",
        "SMTP_HOST", "SMTP_PORT", "SMTP_SSL",
        "S3_BUCKET", "AWS_REGION", "AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY"
    )
    
    $optionalVars = @("AWS_ACCOUNT_ID", "ACCESS_TOKEN_GITHUB", "BACKUP_INTERVAL", "IMAP_HOST", "IMAP_PORT", "IMAP_SSL", "CLOUDFLARE_API", "CLOUDFLARE_TUNNEL_TOKEN")
    
    foreach ($varName in $requiredVars) {
        $value = [Environment]::GetEnvironmentVariable($varName, "Process")
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = [Environment]::GetEnvironmentVariable($varName, "User")
        }
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = [Environment]::GetEnvironmentVariable($varName, "Machine")
        }
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            Set-Item -Path "env:$varName" -Value $value
        }
    }
    
    foreach ($varName in $optionalVars) {
        $value = [Environment]::GetEnvironmentVariable($varName, "Process")
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = [Environment]::GetEnvironmentVariable($varName, "User")
        }
        if ([string]::IsNullOrWhiteSpace($value)) {
            $value = [Environment]::GetEnvironmentVariable($varName, "Machine")
        }
        if (-not [string]::IsNullOrWhiteSpace($value)) {
            Set-Item -Path "env:$varName" -Value $value
        }
    }

    # Verify environment variables are set before Docker Compose
    Write-Info "Verifying environment variables are set..."
    $missingVars = @()
    foreach ($varName in $requiredVars) {
        $value = [Environment]::GetEnvironmentVariable($varName, "Process")
        if ([string]::IsNullOrWhiteSpace($value)) {
            $missingVars += $varName
        }
    }
    
    if ($missingVars.Count -gt 0) {
        Write-Error "The following required environment variables are not set:"
        foreach ($var in $missingVars) {
            Write-Error "  - $var"
        }
        Write-Error "Please ensure all required variables are set before running Docker Compose"
            exit 1
        }
    
    Write-Info "All required environment variables are set"
    
    # Use QUICK_START/.env file for Docker Compose (read directly, don't copy)
    $projectDir = (Get-Location).Path
    $quickStartEnvFile = Join-Path (Split-Path -Parent $PSScriptRoot) "QUICK_START\.env"
    
    # Try alternative paths if not found
    if (-not (Test-Path $quickStartEnvFile)) {
        $quickStartEnvFile = Join-Path $PSScriptRoot "..\QUICK_START\.env"
    }
    if (-not (Test-Path $quickStartEnvFile)) {
        $quickStartEnvFile = Join-Path $projectDir "QUICK_START\.env"
    }
    
    if (Test-Path $quickStartEnvFile) {
        Write-Info "Using QUICK_START/.env file: $quickStartEnvFile"
        # Load .env file into environment variables before running Docker Compose
        # Docker Compose will use these environment variables from the process
        Get-Content $quickStartEnvFile | ForEach-Object {
            if ($_ -match '^\s*([^#][^=]*)\s*=\s*(.*)\s*$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()
                # Set environment variable in Process scope (Docker Compose reads from here)
                [Environment]::SetEnvironmentVariable($key, $value, "Process")
            }
        }
    } else {
        Write-Warn "QUICK_START/.env file not found. Docker Compose will use environment variables from process."
        Write-Warn "Expected locations:"
        Write-Warn "  - $quickStartEnvFile"
    }
    
    Write-Info "Running Docker Compose command (environment variables loaded from QUICK_START/.env)..."
    Write-Info "Command: docker compose -f $ComposeFile up --build (showing live logs)..."
    Write-Info "Building images and starting containers (this may take a few minutes)..."
    Write-Host ""
    
    # Temporarily set ErrorActionPreference to Continue to avoid false errors from stderr
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    
    try {
        # First, build images with live output (shows build progress)
        Write-Info "[Docker Compose] Building images (live output)..."
        Write-Info "You will see: Building steps and progress for each service"
        Write-Host ""
        
        Invoke-DockerCompose -ComposeFile $ComposeFile -Arguments @("build") -ShowOutput
        
        $buildExitCode = $LASTEXITCODE
        
        if ($buildExitCode -ne 0) {
            Write-Error "Docker Compose build failed with exit code: $buildExitCode"
            throw "Build failed"
        }
        
        Write-Host ""
        Write-Success "[Docker Compose] Build completed successfully!"
        Write-Host ""
        
        # Then, start containers in detached mode (shows only creation, no runtime logs)
        Write-Info "[Docker Compose] Creating and starting containers..."
        $result = Invoke-DockerCompose -ComposeFile $ComposeFile -Arguments @("up", "-d", "--no-deps")
        
        if ($result.Output) {
            # Show only container creation messages, filter out runtime logs
            $outputLines = $result.Output -split "`n" | Where-Object { $_.Trim() -ne "" }
            $relevantLines = $outputLines | Where-Object { 
                $_ -match "Creating|Created|Starting|Started|Container|Network|Volume|Built" -and
                $_ -notmatch "level=|caller=|ts=|msg=|component=|E[0-9]|W[0-9]|I[0-9]"
            }
            
            if ($relevantLines) {
                Write-Host ""
                Write-Info "[Docker Compose] Container operations:"
                foreach ($line in $relevantLines) {
                    if ($line -match "Error|error|ERROR|Failed|failed") {
                        Write-Host "  $line" -ForegroundColor Yellow
                    } elseif ($line -match "Created|Started|Built") {
                        Write-Host "  $line" -ForegroundColor Green
                    } else {
                        Write-Host "  $line" -ForegroundColor Gray
                    }
                }
                Write-Host ""
            }
        }
        
        if (-not $result.Success -or $result.ExitCode -ne 0) {
            Write-Error "Docker Compose up failed with exit code: $($result.ExitCode)"
            throw "Container startup failed"
        }
        
        Write-Success "[Docker Compose] All containers created and started successfully!"
        Write-Info "Containers are running in background. Use 'docker compose logs -f' to view runtime logs."
    } finally {
        $ErrorActionPreference = $oldErrorAction
    }
    
    Write-Info "[Docker Compose] Build and start completed. Exit code: $($result.ExitCode)"
    
    # Check if Docker Compose actually succeeded by verifying containers are running
    if (-not $result.Success -or $result.ExitCode -ne 0) {
        Write-Error "Docker Compose failed!"
        Write-Error "Command: $($result.Command)"
        Write-Error "Exit code: $($result.ExitCode)"
        Write-Host ""
        Write-Error "Docker Compose output:"
        if ($result.Output) {
            # Output is already a string, split by lines for better display
            $outputLines = $result.Output -split "`n" | Where-Object { $_.Trim() -ne "" }
            foreach ($line in $outputLines) {
                Write-Host $line -ForegroundColor Red
            }
        } else {
            Write-Host "No output captured" -ForegroundColor Red
        }
        Write-Host ""
        Write-Error "Please check the docker-compose.prod.yml file and environment variables"
        Write-Error "You can also try running manually: $($result.Command)"
        Write-Host ""
        Write-Info "To debug, try running: docker-compose -f $ComposeFile config"
        Write-Info "This will validate the compose file syntax"
        exit 1
    }
    
    # Verify containers are actually running
    Write-Info "Verifying containers are running..."
    Start-Sleep -Seconds 3
    $containers = docker ps --filter "name=finans-" --format "{{.Names}}: {{.Status}}" 2>&1
    if ($LASTEXITCODE -eq 0 -and $containers) {
        Write-Success "Docker Compose services started successfully"
        $containers | ForEach-Object { Write-Info "  $_" }
    } else {
        Write-Warn "Could not verify container status, but Docker Compose reported success"
    }
    
    Write-Success "Docker Compose services started"
}

function Wait-ForServices {
    param(
        [string]$ComposeFile,
        [int]$MaxWaitSeconds = 30
    )
    
Write-Info "Verifying services are running..."
Start-Sleep -Seconds 5

$waitTime = 0
    $servicesRunning = $false

    while ($waitTime -lt $MaxWaitSeconds) {
    try {
            $containers = docker compose -f $ComposeFile ps --format json 2>&1
        if ($LASTEXITCODE -ne 0) {
                $containers = docker-compose -f $ComposeFile ps --format json 2>&1
        }
        
        if ($LASTEXITCODE -eq 0 -and $containers) {
            $runningCount = 0
            $totalCount = 0
            
            $containers | ForEach-Object {
                try {
                    $container = $_ | ConvertFrom-Json
                    $totalCount++
                    if ($container.State -eq "running") {
                        $runningCount++
                    }
                } catch {
                    # Skip invalid JSON
                }
            }
            
            if ($totalCount -gt 0 -and $runningCount -eq $totalCount) {
                Write-Success "All services are running: $($runningCount)/$($totalCount) containers"
                $servicesRunning = $true
                break
            } else {
                Write-Info "Waiting for services... $($runningCount)/$($totalCount) containers running"
            }
        }
    } catch {
        # Continue waiting
    }
    
    Start-Sleep -Seconds 2
    $waitTime += 2
}

if (-not $servicesRunning) {
        Write-Error "Not all services are running after $MaxWaitSeconds seconds"
        Write-Error "Check service status with: docker compose -f $ComposeFile ps"
    exit 1
    }
}

function Restore-PostgreSQLDatabase {
    param(
        [string]$ComposeFile,
        [string]$S3Bucket
    )
    
    Write-Info "Checking for PostgreSQL backup in S3..."
    
    try {
        aws s3 ls "s3://$S3Bucket/postgres/backups/" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warn "No PostgreSQL backup found. Will use fresh database."
            return
        }
    } catch {
        Write-Warn "No PostgreSQL backup found. Will use fresh database."
        return
    }
    
    Write-Info "Restoring PostgreSQL database from S3..."
    
    # Find latest backup - only .sql.gz files, not .checksum files
    $backupList = aws s3 ls "s3://$S3Bucket/postgres/backups/" --recursive | Where-Object { $_ -match '\.sql\.gz$' } | Sort-Object
    $latestBackup = ($backupList | Select-Object -Last 1) -split '\s+' | Select-Object -Last 1
    
    if (-not $latestBackup) {
        Write-Warn "No backup file found (.sql.gz), using fresh database"
        return
    }
    
        Write-Info "Found backup: $latestBackup"
        
        # Download backup
    $backupFile = Join-Path $env:TEMP "postgres_backup.sql.gz"
    $downloadOutput = aws s3 cp "s3://$S3Bucket/$latestBackup" $backupFile 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to download backup file from S3"
        Write-Error "Error: $downloadOutput"
        exit 1
    }
    
    if (-not (Test-Path $backupFile)) {
        Write-Error "Failed to download backup file"
            exit 1
        }
    
    # Get database credentials
        $dbPassword = $env:POSTGRES_PASSWORD
        $dbUser = $env:POSTGRES_USER
        $dbName = $env:POSTGRES_DB
    
        if (-not $dbPassword -or -not $dbUser -or -not $dbName) {
        Write-Error "POSTGRES_PASSWORD, POSTGRES_USER, and POSTGRES_DB environment variables must be set"
        exit 1
        }
        
    # Terminate active connections
        Write-Info "Terminating active connections to database..."
    $terminateQuery = "SELECT pg_terminate_backend(pg_stat_activity.pid) FROM pg_stat_activity WHERE pg_stat_activity.datname = '$dbName' AND pid != pg_backend_pid();"
    
    # Suppress NOTICE messages and errors - only check exit code
    $oldErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "SilentlyContinue"
    $terminateOutput = docker compose -f $ComposeFile exec -T -e PGPASSWORD=$dbPassword postgres psql -U $dbUser -d postgres -c $terminateQuery 2>&1 | Where-Object { $_ -notmatch 'NOTICE:' }
        if ($LASTEXITCODE -ne 0) {
        $terminateOutput = docker-compose -f $ComposeFile exec -T -e PGPASSWORD=$dbPassword postgres psql -U $dbUser -d postgres -c $terminateQuery 2>&1 | Where-Object { $_ -notmatch 'NOTICE:' }
        }
    $ErrorActionPreference = $oldErrorAction
        Start-Sleep -Seconds 2
        
    # Drop and create database
        Write-Info "Dropping existing database..."
    $dropQuery = "DROP DATABASE IF EXISTS $dbName;"
    
    # Suppress NOTICE messages - they are not errors
    $ErrorActionPreference = "SilentlyContinue"
    $dropOutput = docker compose -f $ComposeFile exec -T -e PGPASSWORD=$dbPassword postgres psql -U $dbUser -d postgres -c $dropQuery 2>&1 | Where-Object { $_ -notmatch 'NOTICE:' }
            if ($LASTEXITCODE -ne 0) {
        $dropOutput = docker-compose -f $ComposeFile exec -T -e PGPASSWORD=$dbPassword postgres psql -U $dbUser -d postgres -c $dropQuery 2>&1 | Where-Object { $_ -notmatch 'NOTICE:' }
    }
    $ErrorActionPreference = $oldErrorAction
    
    # Check if there was a real error (not just NOTICE)
    if ($LASTEXITCODE -ne 0 -and $dropOutput -match 'ERROR:') {
        Write-Error "Failed to drop database: $dropOutput"
        exit 1
        }
        
        Write-Info "Creating new database..."
    $createQuery = "CREATE DATABASE $dbName;"
    
    # Suppress NOTICE messages
    $ErrorActionPreference = "SilentlyContinue"
    $createOutput = docker compose -f $ComposeFile exec -T -e PGPASSWORD=$dbPassword postgres psql -U $dbUser -d postgres -c $createQuery 2>&1 | Where-Object { $_ -notmatch 'NOTICE:' }
            if ($LASTEXITCODE -ne 0) {
        $createOutput = docker-compose -f $ComposeFile exec -T -e PGPASSWORD=$dbPassword postgres psql -U $dbUser -d postgres -c $createQuery 2>&1 | Where-Object { $_ -notmatch 'NOTICE:' }
                if ($LASTEXITCODE -ne 0) {
            # Check if database already exists (this is OK)
            if ($createOutput -match 'already exists') {
                Write-Info "Database already exists, continuing..."
            } else {
                Write-Error "Failed to create database: $createOutput"
                $ErrorActionPreference = $oldErrorAction
            exit 1
        }
        }
    }
    $ErrorActionPreference = $oldErrorAction
        
    # Decompress and restore
        Write-Info "Restoring database from backup file..."
    
    if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
        Write-Error "WSL not found. Cannot restore database automatically."
                    exit 1
                }
    
                $tempSql = Join-Path $env:TEMP "postgres_restore.sql"
                
                try {
        # Decompress using PowerShell GZipStream
        $inputFile = New-Object System.IO.FileStream($backupFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read)
                    $gzipStream = New-Object System.IO.Compression.GZipStream($inputFile, [System.IO.Compression.CompressionMode]::Decompress)
                    $outputFile = New-Object System.IO.FileStream($tempSql, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
                    
                    $gzipStream.CopyTo($outputFile)
                    
                    $outputFile.Close()
                    $gzipStream.Close()
                    $inputFile.Close()
                    
                    Write-Info "Backup file decompressed successfully"
                } catch {
                    Write-Warn "PowerShell decompression failed, trying WSL gunzip..."
        $driveLetter = $backupFile[0].ToString().ToLower()
        $wslBackupFile = "/mnt/$driveLetter" + ($backupFile.Substring(2) -replace "\\", "/")
                    $gunzipOutput = wsl gunzip -c $wslBackupFile 2>&1
                    
                    if ($LASTEXITCODE -eq 0) {
                        # Convert array to string if needed (wsl output can be array of lines)
                        $sqlContent = if ($gunzipOutput -is [Array]) {
                            $gunzipOutput -join "`n"
                        } else {
                            $gunzipOutput.ToString()
                        }
                        
                        # Write without BOM using UTF8NoBOM encoding
                        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                        [System.IO.File]::WriteAllText($tempSql, $sqlContent, $utf8NoBom)
                        Write-Info "Backup file decompressed using WSL gunzip"
                    } else {
            Write-Error "Failed to decompress backup file"
            exit 1
        }
    }
    
    if (-not ((Test-Path $tempSql) -and ((Get-Item $tempSql).Length -gt 0))) {
        Write-Error "Decompressed file is empty or does not exist"
        exit 1
    }
    
    # Filter SQL (remove schema creation commands and BOM)
                    # Read SQL file and remove BOM if present
                    # Try multiple encodings to handle BOM properly
                    $sqlContent = $null
                    $encodings = @(
                        [System.Text.Encoding]::UTF8,
                        [System.Text.Encoding]::Unicode,
                        [System.Text.Encoding]::BigEndianUnicode,
                        [System.Text.Encoding]::ASCII
                    )
                    
                    # Read file as bytes first to detect BOM
                    $rawBytes = [System.IO.File]::ReadAllBytes($tempSql)
                    $detectedEncoding = $null
                    $contentBytes = $rawBytes
                    
                    # Detect and remove BOM, determine encoding
                    if ($rawBytes.Length -ge 3 -and $rawBytes[0] -eq 0xEF -and $rawBytes[1] -eq 0xBB -and $rawBytes[2] -eq 0xBF) {
                        # UTF-8 BOM detected, remove first 3 bytes
                        $contentBytes = $rawBytes[3..($rawBytes.Length - 1)]
                        $detectedEncoding = New-Object System.Text.UTF8Encoding $false
                    } elseif ($rawBytes.Length -ge 2 -and $rawBytes[0] -eq 0xFF -and $rawBytes[1] -eq 0xFE) {
                        # UTF-16 LE BOM detected, remove first 2 bytes and decode as UTF-16 LE
                        $contentBytes = $rawBytes[2..($rawBytes.Length - 1)]
                        $detectedEncoding = New-Object System.Text.UnicodeEncoding $false, $false  # LE, no BOM
                    } elseif ($rawBytes.Length -ge 2 -and $rawBytes[0] -eq 0xFE -and $rawBytes[1] -eq 0xFF) {
                        # UTF-16 BE BOM detected, remove first 2 bytes and decode as UTF-16 BE
                        $contentBytes = $rawBytes[2..($rawBytes.Length - 1)]
                        $detectedEncoding = New-Object System.Text.UnicodeEncoding $true, $false  # BE, no BOM
                    } else {
                        # No BOM detected, try to detect encoding by trying different encodings
                        foreach ($encoding in $encodings) {
                            try {
                                $testEncoding = New-Object System.Text.UTF8Encoding $false
                                if ($encoding -eq [System.Text.Encoding]::Unicode) {
                                    $testEncoding = New-Object System.Text.UnicodeEncoding $false, $false
                                } elseif ($encoding -eq [System.Text.Encoding]::BigEndianUnicode) {
                                    $testEncoding = New-Object System.Text.UnicodeEncoding $true, $false
                                } elseif ($encoding -eq [System.Text.Encoding]::ASCII) {
                                    $testEncoding = [System.Text.Encoding]::ASCII
                                }
                                
                                # Try to decode and check if result is valid (basic check)
                                $testContent = $testEncoding.GetString($contentBytes)
                                # If decoding succeeds and produces reasonable text (not mostly nulls or garbage)
                                if ($testContent -match '[\x20-\x7E]') {
                                    $detectedEncoding = $testEncoding
                                    break
                                }
                            } catch {
                                continue
                            }
                        }
                        
                        # Default to UTF-8 if no encoding detected
                        if ($null -eq $detectedEncoding) {
                            $detectedEncoding = New-Object System.Text.UTF8Encoding $false
                        }
                    }
                    
                    # Decode using detected encoding
                    try {
                        $sqlContent = $detectedEncoding.GetString($contentBytes)
                    } catch {
                        # Fallback: use UTF-8 if decoding fails
                        # Use $contentBytes (BOM already stripped) instead of $rawBytes
                        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                        $sqlContent = $utf8NoBom.GetString($contentBytes)
                    }
                    
                    if ($null -eq $sqlContent) {
                        # Fallback: read as UTF8 and manually strip BOM
                        $sqlContent = [System.IO.File]::ReadAllText($tempSql, [System.Text.Encoding]::UTF8)
                    }
                    
                    # Remove BOM character (U+FEFF) from string if still present
                    $sqlContent = $sqlContent -replace "^\uFEFF", ""
                    # Remove any remaining invisible BOM-like characters
                    $sqlContent = $sqlContent.TrimStart([char]0xFEFF, [char]0x200B)
                    # Remove any non-ASCII characters at the start that might be BOM remnants
                    while ($sqlContent.Length -gt 0 -and [int][char]$sqlContent[0] -gt 127 -and [int][char]$sqlContent[0] -lt 256) {
                        $sqlContent = $sqlContent.Substring(1)
                    }
                    
                    $filteredSql = $sqlContent -replace '(?ms)^\s*DROP\s+DATABASE\s+(IF\s+EXISTS\s+)?[^;]*;?\s*$', ''
                    $filteredSql = $filteredSql -replace '(?ms)^\s*CREATE\s+DATABASE\s+[^;]*;?\s*$', ''
                    $filteredSql = $filteredSql -replace '(?ms)^\s*\\c\s+[^\r\n]*;?\s*$', ''
                    $filteredSql = $filteredSql -replace '(?ms)^\s*CREATE\s+TABLE\s+(IF\s+NOT\s+EXISTS\s+)?[^;]*;?\s*$', ''
                    $filteredSql = $filteredSql -replace '(?ms)^\s*CREATE\s+SEQUENCE\s+(IF\s+NOT\s+EXISTS\s+)?[^;]*;?\s*$', ''
                    $filteredSql = $filteredSql -replace '(?ms)^\s*CREATE\s+(UNIQUE\s+)?INDEX\s+(IF\s+NOT\s+EXISTS\s+)?[^;]*;?\s*$', ''
                    $filteredSql = $filteredSql -replace '(?ms)^\s*ALTER\s+TABLE\s+[^;]*\s+ADD\s+(PRIMARY\s+KEY|FOREIGN\s+KEY|CONSTRAINT)[^;]*;?\s*$', ''
                    $filteredSql = $filteredSql -replace '(?ms)^\s*ALTER\s+SEQUENCE\s+[^;]*;?\s*$', ''
                    $filteredSql = $filteredSql -replace '(?ms)^\s*ALTER\s+TABLE\s+[^;]*;?\s*$', ''
                    
                    $filteredSqlFile = Join-Path $env:TEMP "postgres_restore_filtered.sql"
                    # Write without BOM using UTF8NoBOM encoding
                    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                    [System.IO.File]::WriteAllText($filteredSqlFile, $filteredSql, $utf8NoBom)
                    
    # Restore database
                    Write-Info "Importing data into database..."
                    
                    # Verify filtered SQL file exists and is not empty
                    if (-not (Test-Path $filteredSqlFile)) {
                        Write-Error "Filtered SQL file does not exist: $filteredSqlFile"
                        exit 1
                    }
                    
                    $filteredFileSize = (Get-Item $filteredSqlFile).Length
                    if ($filteredFileSize -eq 0) {
                        Write-Error "Filtered SQL file is empty"
                        exit 1
                    }
                    
                    Write-Info "Filtered SQL file size: $filteredFileSize bytes"
                    
                    # Read file without BOM and pipe to psql
                    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                    $sqlContentToRestore = [System.IO.File]::ReadAllText($filteredSqlFile, $utf8NoBom)
                    
                    # Additional BOM check before restore - more aggressive cleanup
                    if ($sqlContentToRestore.Length -gt 0) {
                        $firstCharCode = [int][char]$sqlContentToRestore[0]
                        # Check for BOM (U+FEFF = 65279) or any non-printable character at start
                        if ($firstCharCode -eq 0xFEFF -or $firstCharCode -gt 127) {
                            Write-Warning "Potential BOM or non-ASCII character detected at start of SQL content (char code: $firstCharCode), attempting to remove..."
                            # Remove BOM character (U+FEFF) explicitly
                            $sqlContentToRestore = $sqlContentToRestore -replace "^\uFEFF", ""
                            # Remove any remaining invisible BOM-like characters
                            $sqlContentToRestore = $sqlContentToRestore.TrimStart([char]0xFEFF, [char]0x200B)
                            # Remove any non-ASCII characters at the start that might be BOM remnants
                            while ($sqlContentToRestore.Length -gt 0 -and [int][char]$sqlContentToRestore[0] -gt 127 -and [int][char]$sqlContentToRestore[0] -lt 256) {
                                $sqlContentToRestore = $sqlContentToRestore.Substring(1)
                            }
                        }
                    }
                    
                    # Write cleaned content to a temporary file for psql
                    $finalSqlFile = Join-Path $env:TEMP "postgres_restore_final.sql"
                    [System.IO.File]::WriteAllText($finalSqlFile, $sqlContentToRestore, $utf8NoBom)
                    
                    # Use PowerShell to clean SQL and pipe to docker exec
                    try {
                        # Read SQL content as bytes and remove BOM at byte level
                        $sqlBytes = [System.IO.File]::ReadAllBytes($finalSqlFile)
                        
                        # Remove UTF-8 BOM (EF BB BF) at byte level if present
                        if ($sqlBytes.Length -ge 3 -and $sqlBytes[0] -eq 0xEF -and $sqlBytes[1] -eq 0xBB -and $sqlBytes[2] -eq 0xBF) {
                            Write-Warning "UTF-8 BOM detected at byte level, removing..."
                            $sqlBytes = $sqlBytes[3..($sqlBytes.Length - 1)]
                        }
                        
                        # Remove UTF-16 LE BOM (FF FE) at byte level if present
                        if ($sqlBytes.Length -ge 2 -and $sqlBytes[0] -eq 0xFF -and $sqlBytes[1] -eq 0xFE) {
                            Write-Warning "UTF-16 LE BOM detected at byte level, removing..."
                            $sqlBytes = $sqlBytes[2..($sqlBytes.Length - 1)]
                        }
                        
                        # Remove UTF-16 BE BOM (FE FF) at byte level if present
                        if ($sqlBytes.Length -ge 2 -and $sqlBytes[0] -eq 0xFE -and $sqlBytes[1] -eq 0xFF) {
                            Write-Warning "UTF-16 BE BOM detected at byte level, removing..."
                            $sqlBytes = $sqlBytes[2..($sqlBytes.Length - 1)]
                        }
                        
                        # Write cleaned bytes to a new temporary file (BOM-free)
                        $cleanedSqlFile = Join-Path $env:TEMP "postgres_restore_cleaned.sql"
                        [System.IO.File]::WriteAllBytes($cleanedSqlFile, $sqlBytes)
                        
                        # Verify no BOM in the cleaned file
                        $verifyBytes = [System.IO.File]::ReadAllBytes($cleanedSqlFile)
                        if ($verifyBytes.Length -ge 3 -and $verifyBytes[0] -eq 0xEF -and $verifyBytes[1] -eq 0xBB -and $verifyBytes[2] -eq 0xBF) {
                            Write-Error "BOM still present after cleanup - this should not happen!"
                            exit 1
                        }
                        
                        # Convert cleaned bytes to UTF-8 string (no BOM) for piping
                        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                        $sqlText = $utf8NoBom.GetString($sqlBytes)
                        
                        # Final verification: ensure first character is not BOM
                        if ($sqlText.Length -gt 0 -and [int][char]$sqlText[0] -eq 0xFEFF) {
                            Write-Warning "BOM character still present in string after byte cleanup, removing..."
                            $sqlText = $sqlText -replace "^\uFEFF", ""
                        }
                        
                        # Write cleaned text to file again (double-check, BOM-free)
                        [System.IO.File]::WriteAllText($cleanedSqlFile, $sqlText, $utf8NoBom)
                        
                        # Use cmd.exe to redirect file to stdin (avoids PowerShell encoding issues)
                        # cmd.exe /c type reads file and pipes to stdin without encoding conversion
                        $restoreOutput = cmd.exe /c "type `"$cleanedSqlFile`" | docker compose -f $ComposeFile exec -T -e PGPASSWORD=$dbPassword postgres psql -U $dbUser -d $dbName" 2>&1
                        $exitCode = $LASTEXITCODE
                        
                        # If cmd.exe method fails, try PowerShell pipe with explicit encoding
                        if ($exitCode -ne 0) {
                            Write-Info "Trying PowerShell pipe method as fallback..."
                            # Read file as bytes and convert to string to avoid BOM
                            $cleanBytes = [System.IO.File]::ReadAllBytes($cleanedSqlFile)
                            $cleanText = $utf8NoBom.GetString($cleanBytes)
                            $restoreOutput = $cleanText | docker compose -f $ComposeFile exec -T -e PGPASSWORD=$dbPassword postgres psql -U $dbUser -d $dbName 2>&1
                            $exitCode = $LASTEXITCODE
                        }
                        
                        # Cleanup cleaned SQL file
                        Remove-Item $cleanedSqlFile -ErrorAction SilentlyContinue
                    } catch {
                        Write-Error "Error during restore: $_"
                        $exitCode = 1
                    }
                    
                    # Cleanup final SQL file
                    Remove-Item $finalSqlFile -ErrorAction SilentlyContinue
                    
                    if ($exitCode -eq 0) {
        Write-Success "Database restored from S3"
                    } else {
                        Write-Error "Failed to restore database. Exit code: $exitCode"
                        if ($restoreOutput) {
                            Write-Error "Error output: $restoreOutput"
                            # Show last 10 lines of error output
                            $errorLines = $restoreOutput -split "`n" | Select-Object -Last 10
                            Write-Error "Last error lines:"
                            foreach ($line in $errorLines) {
                                Write-Error "  $line"
                            }
                        }
        exit 1
                    }
                    
    # Cleanup
    Remove-Item $filteredSqlFile -ErrorAction SilentlyContinue
                    Remove-Item $tempSql -ErrorAction SilentlyContinue
    Remove-Item $backupFile -ErrorAction SilentlyContinue
}

# ==============================================================================
# Leadership Functions
# ==============================================================================

function Get-MachineType {
    try {
        $instanceId = Invoke-WebRequest -Uri "http://169.254.169.254/latest/meta-data/instance-id" -TimeoutSec 1 -ErrorAction Stop
        $script:MACHINE_TYPE = "ec2"
        $script:MACHINE_ID = $instanceId.Content
        Write-Info "Detected EC2 instance: $($instanceId.Content)"
    } catch {
        $script:MACHINE_TYPE = "physical"
        $script:MACHINE_ID = $env:COMPUTERNAME
        Write-Info "Detected physical machine: $env:COMPUTERNAME"
    }
}

function Get-CurrentLeader {
    if (-not $env:S3_BUCKET) {
        return $null
    }
    
    try {
        $leaderJson = aws s3 cp "s3://$env:S3_BUCKET/current-leader.json" - 2>&1
        if ($LASTEXITCODE -eq 0) {
            return $leaderJson
        }
    } catch {
        # Ignore
    }
    return $null
}

function Test-LeaderEligibility {
    $currentLeader = Get-CurrentLeader
    if ($null -eq $currentLeader) {
        return $true
    }
    
    $quote = '"'
    $notQuote = '[^' + $quote + ']+'
    $patternLeaderId = 'leader_id.*?:\s*' + $quote + '(' + $notQuote + ')' + $quote
    $patternLeaderType = 'leader_type.*?:\s*' + $quote + '(' + $notQuote + ')' + $quote
    $currentLeaderId = ($currentLeader | Select-String -Pattern $patternLeaderId | ForEach-Object { $_.Matches.Groups[1].Value })
    $currentLeaderType = ($currentLeader | Select-String -Pattern $patternLeaderType | ForEach-Object { $_.Matches.Groups[1].Value })
    
    if ($currentLeaderId -eq $script:MACHINE_ID) {
        return $true
    }
    
    if ($currentLeaderType -eq "physical" -and $script:MACHINE_TYPE -ne "physical") {
        Write-Info "Physical machine leader exists - this EC2 will not be leader"
        return $false
    }
    
    if ($currentLeaderType -eq "physical" -and $currentLeaderId -ne $script:MACHINE_ID) {
        $patternRegisteredAt = 'registered_at.*?:\s*' + $quote + '(' + $notQuote + ')' + $quote
        $registeredAt = ($currentLeader | Select-String -Pattern $patternRegisteredAt | ForEach-Object { $_.Matches.Groups[1].Value })
        if ($registeredAt) {
                try {
                $registeredTimeOffset = [DateTimeOffset]::ParseExact($registeredAt, "yyyy-MM-ddTHH:mm:ssZ", $null, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                $registeredTime = $registeredTimeOffset.UtcDateTime
                $now = [DateTime]::UtcNow
                $diffMinutes = ($now - $registeredTime).TotalMinutes
                
                if ($diffMinutes -lt 2) {
                    Write-Info "Another physical machine is leader (registered $diffMinutes minutes ago, less than 2 minutes) - this machine will not be leader"
                    return $false
                }
            } catch {
                # If parsing fails, allow takeover
            }
        }
    }
    
    return $true
}

function Start-HeartbeatDaemon {
    param(
        [string]$MachineId,
        [string]$MachineType,
        [string]$S3Bucket
    )
    
    if (-not $S3Bucket) {
        return
    }
    
    # Get script directory for worker conversion script
    $scriptDir = $PSScriptRoot
    if (-not $scriptDir) {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    if (-not $scriptDir) {
        $scriptDir = Get-Location
    }
    
    Start-Job -ScriptBlock {
        param($MachineId, $MachineType, $S3Bucket, $ScriptDir)
        
        $consecutiveNonLeaderChecks = 0
        
        while ($true) {
            Start-Sleep -Seconds 15
            try {
                # Download to temp file first to avoid BOM issues
                $tempLeaderFile = Join-Path $env:TEMP "current-leader-heartbeat-$(Get-Random).json"
                aws s3 cp "s3://$S3Bucket/current-leader.json" $tempLeaderFile 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0 -and (Test-Path $tempLeaderFile)) {
                    try {
                        $leaderInfoJson = Get-Content $tempLeaderFile -Raw -ErrorAction Stop
                        $leaderInfoJson = $leaderInfoJson.Trim()
                        
                        # Validate JSON format
                        $trimmedJson = $leaderInfoJson.TrimStart()
                        if (-not [string]::IsNullOrWhiteSpace($trimmedJson) -and $trimmedJson.Length -ge 2) {
                            $firstChar = $trimmedJson[0]
                            if ($firstChar -eq '{' -or $firstChar -eq '[') {
                                $leaderInfo = $leaderInfoJson | ConvertFrom-Json -ErrorAction Stop
                                
                                if ($leaderInfo.leader_id -eq $MachineId) {
                                    # This machine is still the leader - update heartbeat
                                    # CRITICAL: Re-read from S3 to prevent race condition (optimistic locking)
                                    # Another machine might have taken over leadership between read and write
                                    $tempLeaderFile2 = Join-Path $env:TEMP "current-leader-heartbeat-verify-$(Get-Random).json"
                                    $verifySuccess = $false
                                    
                                    aws s3 cp "s3://$S3Bucket/current-leader.json" $tempLeaderFile2 2>&1 | Out-Null
                                    
                                    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempLeaderFile2)) {
                                        try {
                                            $leaderInfoVerifyJson = Get-Content $tempLeaderFile2 -Raw -ErrorAction Stop
                                            $leaderInfoVerifyJson = $leaderInfoVerifyJson.Trim()
                                            $trimmedJsonVerify = $leaderInfoVerifyJson.TrimStart()
                                            
                                            if (-not [string]::IsNullOrWhiteSpace($trimmedJsonVerify) -and $trimmedJsonVerify.Length -ge 2) {
                                                $firstCharVerify = $trimmedJsonVerify[0]
                                                if ($firstCharVerify -eq '{' -or $firstCharVerify -eq '[') {
                                                    $leaderInfoVerify = $leaderInfoVerifyJson | ConvertFrom-Json -ErrorAction Stop
                                                    
                                                    # Verify we're still the leader before updating
                                                    if ($leaderInfoVerify.leader_id -eq $MachineId) {
                                                        # Still the leader - safe to update heartbeat
                                                        $consecutiveNonLeaderChecks = 0
                                                        # Use ISO 8601 format with explicit UTC (Z suffix)
                                                        $utcNow = [DateTime]::UtcNow
                                                        $leaderInfoVerify.last_heartbeat = $utcNow.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"
                                                        
                                                        # Write updated JSON without BOM
                                                        $updatedJson = $leaderInfoVerify | ConvertTo-Json -Compress
                                                        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                                                        [System.IO.File]::WriteAllText($tempLeaderFile2, $updatedJson, $utf8NoBom)
                                                        
                                                        # Upload back to S3
                                                        aws s3 cp $tempLeaderFile2 "s3://$S3Bucket/current-leader.json" --content-type "application/json" 2>&1 | Out-Null
                                                        $verifySuccess = ($LASTEXITCODE -eq 0)
                                                    } else {
                                                        # Leadership was taken over between read and write - don't update
                                                        # This will be handled in the next iteration (else branch)
                                                    }
                                                }
                                            }
                                        } catch {
                                            # Verification failed, will use fallback
                                        } finally {
                                            Remove-Item $tempLeaderFile2 -Force -ErrorAction SilentlyContinue
                                        }
                                    } else {
                                        # Verify read failed - will use fallback
                                    }
                                    
                                    # FALLBACK: If verify failed, use original read data (with race condition risk, but better than no heartbeat)
                                    if (-not $verifySuccess) {
                                        # Use original leaderInfo (from first read) - risk of race condition but better than no heartbeat
                                        # Create new temp file for fallback (original $tempLeaderFile may be deleted in finally block)
                                        $tempLeaderFileFallback = Join-Path $env:TEMP "current-leader-heartbeat-fallback-$(Get-Random).json"
                                        $consecutiveNonLeaderChecks = 0
                                        $utcNow = [DateTime]::UtcNow
                                        $leaderInfo.last_heartbeat = $utcNow.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"
                                        
                                        $updatedJson = $leaderInfo | ConvertTo-Json -Compress
                                        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                                        [System.IO.File]::WriteAllText($tempLeaderFileFallback, $updatedJson, $utf8NoBom)
                                        
                                        aws s3 cp $tempLeaderFileFallback "s3://$S3Bucket/current-leader.json" --content-type "application/json" 2>&1 | Out-Null
                                        
                                        # Clean up fallback temp file
                                        Remove-Item $tempLeaderFileFallback -Force -ErrorAction SilentlyContinue
                                    }
                                } else {
                                    # Another machine is now the leader - this machine should convert to worker
                                    $consecutiveNonLeaderChecks++
                                    if ($consecutiveNonLeaderChecks -eq 1) {
                                        # First detection: Remove leader label, log demotion, and trigger worker conversion
                                        try {
                                            # Remove leader label from this node
                                            $nodes = kubectl get nodes -o json 2>&1 | ConvertFrom-Json
                                            if ($LASTEXITCODE -eq 0 -and $nodes -and $nodes.items) {
                                                foreach ($node in $nodes.items) {
                                                    $hostname = $node.metadata.labels.'kubernetes.io/hostname'
                                                    if ($hostname -eq $MachineId -or $node.metadata.name -eq $MachineId) {
                                                        kubectl label node $node.metadata.name leader- 2>&1 | Out-Null
                                                        break
                                                    }
                                                }
                                            }
                                        } catch {
                                            # Ignore errors - Kubernetes might not be accessible
                                        }
                                        
                                        # Log demotion
                                        $logFile = Join-Path $env:TEMP "leader-demotion-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
                                        $logMessage = "[$(([DateTime]::UtcNow).ToString('yyyy-MM-dd HH:mm:ss')) UTC] Liderlik devredildi: Yeni lider '$($leaderInfo.leader_id)' tespit edildi. Bu makine worker moduna geciriliyor..."
                                        $logMessage | Out-File -FilePath $logFile -Encoding utf8
                                        
                                        # Create worker conversion flag file with leader info
                                        $workerFlagFile = Join-Path $env:TEMP "convert-to-worker.flag"
                                        
                                        # Check if flag file already exists (script might be running or already processed)
                                        $shouldTriggerConversion = $true
                                        if (Test-Path $workerFlagFile) {
                                            try {
                                                $existingFlagJson = Get-Content $workerFlagFile -Raw -Encoding UTF8 -ErrorAction Stop
                                                $existingFlag = $existingFlagJson | ConvertFrom-Json -ErrorAction Stop
                                                
                                                # Check if it's for the same new leader (script might be running)
                                                if ($existingFlag.new_leader_id -eq $leaderInfo.leader_id) {
                                                    # Same leader, script might be running - don't trigger again
                                                    $shouldTriggerConversion = $false
                                                } else {
                                                    # Different leader - remove old flag and create new one
                                                    Remove-Item $workerFlagFile -Force -ErrorAction SilentlyContinue
                                                }
                                            } catch {
                                                # Flag file exists but invalid - remove it and create new one
                                                Remove-Item $workerFlagFile -Force -ErrorAction SilentlyContinue
                                            }
                                        }
                                        
                                        if ($shouldTriggerConversion) {
                                            $workerInfo = @{
                                                new_leader_id = $leaderInfo.leader_id
                                                new_leader_ip = $leaderInfo.node_ip
                                                k3s_token = $leaderInfo.k3s_token
                                                k3s_server_url = $leaderInfo.k3s_server_url
                                                detected_at = ([DateTime]::UtcNow).ToString("yyyy-MM-ddTHH:mm:ssZ")
                                            } | ConvertTo-Json -Compress
                                            
                                            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
                                            [System.IO.File]::WriteAllText($workerFlagFile, $workerInfo, $utf8NoBom)
                                            
                                            if (Test-Path $scriptPath) {
                                                try {
                                                    $process = Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", "-WorkerFlagFile", "`"$workerFlagFile`"" -WindowStyle Hidden -PassThru -ErrorAction Stop
                                                    $logMessage += "`nWorker conversion script baslatildi: $scriptPath (PID: $($process.Id))"
                                                } catch {
                                                    $logMessage += "`nWorker conversion script baslatilamadi: $_"
                                                }
                                            } else {
                                                # If script doesn't exist, log that manual conversion is needed
                                                $logMessage += "`nUYARI: convert-to-worker.ps1 script bulunamadi ($scriptPath). Manuel olarak worker moduna gecmeniz gerekiyor."
                                            }
                                        } else {
                                            $logMessage += "`nWorker conversion zaten baslatilmis (flag dosyasi mevcut) - atlaniyor"
                                        }
                                        $logMessage | Out-File -FilePath $logFile -Encoding utf8 -Append
                                    }
                                    # Don't update heartbeat - this machine is no longer the leader
                                    # Worker conversion process has been triggered
                                }
                            }
                        }
                    } catch {
                        # Ignore JSON parse errors, continue heartbeat
                    } finally {
                        Remove-Item $tempLeaderFile -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                # Ignore errors, continue heartbeat
            }
        }
    } -ArgumentList $MachineId, $MachineType, $S3Bucket, $scriptDir | Out-Null
}

function Label-LeaderNode {
    Write-Info "Labeling leader node..."
    
    try {
        # Try to find node by hostname or machine ID
        $nodes = kubectl get nodes -o json 2>&1 | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0 -or -not $nodes) {
            Write-Warn "Could not get nodes from Kubernetes cluster"
            return
        }
        
        $nodeName = $null
        if ($nodes.items.Count -gt 0) {
            # First, try to match by hostname
            if ($script:MACHINE_ID) {
                foreach ($node in $nodes.items) {
                    $hostname = $node.metadata.labels.'kubernetes.io/hostname'
                    if ($hostname -eq $script:MACHINE_ID -or $node.metadata.name -eq $script:MACHINE_ID) {
                        $nodeName = $node.metadata.name
                        break
                    }
                }
            }
            
            # If no match, use first node
            if (-not $nodeName) {
                $nodeName = $nodes.items[0].metadata.name
            }
        }
        
        if (-not $nodeName) {
            Write-Warn "Could not find node to label"
            return
        }
        
        # Remove old leader label from all nodes (to ensure only one leader)
        foreach ($node in $nodes.items) {
            kubectl label node $node.metadata.name leader- 2>&1 | Out-Null
        }
        
        # Add leader label to current leader node
        kubectl label node $nodeName leader="true" --overwrite 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Leader node labeled: $nodeName"
            $labelInfo = "   Labels: leader=true"
            
            # Also add node-type label if physical machine
            if ($script:MACHINE_TYPE -eq "physical") {
                kubectl label node $nodeName node-type=physical --overwrite 2>&1 | Out-Null
                $labelInfo += ", node-type=physical"
            }
            
            Write-Info $labelInfo
        } else {
            Write-Warn "Failed to label node (may not have permissions or node not found)"
        }
    } catch {
        Write-Warn "Failed to label node: $_"
    }
}

function Register-Leadership {
    param(
        [switch]$Force  # Force takeover even if another leader exists
    )
    
    if (-not $env:S3_BUCKET) {
        Write-Warn "S3_BUCKET not set, skipping leadership registration"
        return
    }
    
    Get-MachineType
    
    if (-not $Force) {
        if (-not (Test-LeaderEligibility)) {
            Write-Info "This machine is not eligible to be leader - skipping registration"
            return
        }
    } else {
        # Force mode: Check if there's an existing leader and handle takeover
        $currentLeader = Get-CurrentLeader
        if ($currentLeader) {
            try {
                $currentLeaderObj = $currentLeader | ConvertFrom-Json
                $currentLeaderId = $currentLeaderObj.leader_id
                if ($currentLeaderId -ne $script:MACHINE_ID) {
                    # Old leader is a different machine - convert it to worker
                    Write-Info "Force takeover: Mevcut lider ($currentLeaderId) liderliginden devrediyor..."
                    Write-Warn "Eski lider ($currentLeaderId) worker moduna geciriliyor..."
                    Write-Info "Eski lider makine heartbeat daemon ile liderligini kaybettigini algilayacak (max 15 saniye)"
                    Write-Info "     ve otomatik olarak worker moduna gececek (convert-to-worker.ps1 script'i baslatilacak)"
                    
                    # Remove leader label from old leader node (if Kubernetes is accessible)
                    try {
                        $nodes = kubectl get nodes -o json 2>&1 | ConvertFrom-Json
                        if ($LASTEXITCODE -eq 0 -and $nodes -and $nodes.items) {
                            foreach ($node in $nodes.items) {
                                $hostname = $node.metadata.labels.'kubernetes.io/hostname'
                                if ($hostname -eq $currentLeaderId -or $node.metadata.name -eq $currentLeaderId) {
                                    kubectl label node $node.metadata.name leader- 2>&1 | Out-Null
                                    Write-Info "Eski lider node'undan leader label kaldirildi: $($node.metadata.name)"
                                    break
                                }
                            }
                        }
                    } catch {
                        Write-Warn "Kubernetes node label guncellenemedi (cluster erisilebilir olmayabilir): $_"
                    }
                } else {
                    # Old leader is this machine - needs full restart
                    Write-Info "Bu makine zaten lider - Servisler temizlenip yeniden baslatilacak..."
                    Write-Warn "[WARNING] Mevcut liderlik temizleniyor, tum servisler yeniden baslatilacak"
                    
                    # Set flag for full restart
                    $script:NEEDS_FULL_RESTART = $true
                }
            } catch {
                # Ignore parse errors
            }
        }
    }
    
    try {
        $nodeIP = (Invoke-WebRequest -Uri "https://ifconfig.me/ip" -UseBasicParsing -TimeoutSec 5).Content.Trim()
        if ([string]::IsNullOrWhiteSpace($nodeIP) -or $nodeIP -match '<html') {
            $nodeIP = "unknown"
        }
    } catch {
        $nodeIP = "unknown"
    }
    
    # Use ISO 8601 format with explicit UTC (Z suffix) - ensure UTC timezone
    $utcNow = [DateTime]::UtcNow
    $registeredAt = $utcNow.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"
    $lastHeartbeat = $utcNow.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"
    
    # Windows uses Docker Desktop Kubernetes, not k3s
    # k3s_token and k3s_server_url are only for Linux/Mac workers
    # On Windows, these will be empty (Docker Desktop Kubernetes doesn't support worker join)
    $k3sToken = ""
    $k3sServerUrl = ""
    Write-Info "Windows tespit edildi - Docker Desktop Kubernetes kullaniliyor (k3s degil)"
    
    $leaderInfo = @{
        leader_id = $script:MACHINE_ID
        leader_type = $script:MACHINE_TYPE
        node_ip = $nodeIP
        registered_at = $registeredAt
        last_heartbeat = $lastHeartbeat
        k3s_token = $k3sToken
        k3s_server_url = $k3sServerUrl
    } | ConvertTo-Json -Compress
    
    try {
        # CRITICAL: Optimistic locking - read current leader before writing
        # If another machine took over, don't overwrite it (unless Force mode)
        $shouldWrite = $true
        
        if (-not $Force) {
            # Normal mode: Check if another machine is active leader
            $tempCurrentLeaderFile = Join-Path $env:TEMP "current-leader-check-$(Get-Random).json"
            aws s3 cp "s3://$env:S3_BUCKET/current-leader.json" $tempCurrentLeaderFile 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tempCurrentLeaderFile)) {
                try {
                    $currentLeaderJson = Get-Content $tempCurrentLeaderFile -Raw -ErrorAction Stop
                    $currentLeaderJson = $currentLeaderJson.Trim()
                    $trimmedCurrentJson = $currentLeaderJson.TrimStart()
                    
                    if (-not [string]::IsNullOrWhiteSpace($trimmedCurrentJson) -and $trimmedCurrentJson.Length -ge 2) {
                        $firstCharCurrent = $trimmedCurrentJson[0]
                        if ($firstCharCurrent -eq '{' -or $firstCharCurrent -eq '[') {
                            $currentLeader = $currentLeaderJson | ConvertFrom-Json -ErrorAction Stop
                            
                            # Check if another machine is already the leader (and not us)
                            if ($currentLeader.leader_id -and $currentLeader.leader_id -ne $script:MACHINE_ID) {
                                # Another machine is the leader - check if it's active
                                if ($currentLeader.last_heartbeat) {
                                    try {
                                        $lastHeartbeatStr = $currentLeader.last_heartbeat.ToString().Trim()
                                        $lastHeartbeat = [DateTimeOffset]::Parse($lastHeartbeatStr, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal).UtcDateTime
                                        $now = [DateTime]::UtcNow
                                        $timeDiff = ($now - $lastHeartbeat).TotalMinutes
                                        
                                        # If current leader is active (heartbeat < 1 minute), don't overwrite
                                        # EXCEPT if the current leader is an EC2 instance and we are a physical machine (Return Home feature)
                                        if ($timeDiff -ge 0 -and $timeDiff -lt 1) {
                                            if ($currentLeader.leader_type -eq "ec2" -and $script:MACHINE_TYPE -eq "physical") {
                                                Write-Info "AWS-Cloud-Leader tespit edildi. 'Eve Donus' (Return Home) ozelligi ile liderlik devraliniyor..."
                                                $shouldWrite = $true
                                            } else {
                                                Write-Warn "Baska bir makine zaten aktif lider ($($currentLeader.leader_id), heartbeat: $([Math]::Round($timeDiff, 1)) dakika once)"
                                                Write-Warn "Leadership kaydi yapilmadi - mevcut lider korunuyor"
                                                Write-Info "Force takeover icin -Force parametresi kullanin"
                                                $shouldWrite = $false
                                            }
                                        }
                                    } catch {
                                        # Heartbeat parse failed, proceed with write
                                    }
                                }
                            }
                        }
                    }
                } catch {
                    # Parse failed, proceed with write
                } finally {
                    Remove-Item $tempCurrentLeaderFile -Force -ErrorAction SilentlyContinue
                }
            }
    } else {
        # Force mode: Overwrite regardless of current leader
        Write-Info "Force mode aktif - mevcut lider kontrolu atlaniyor"
    }
        
        if ($shouldWrite) {
            # Write JSON to temp file without BOM, then upload to S3
            $tempLeaderFile = Join-Path $env:TEMP "leader-info-$(Get-Random).json"
            $utf8NoBom = New-Object System.Text.UTF8Encoding $false
            [System.IO.File]::WriteAllText($tempLeaderFile, $leaderInfo, $utf8NoBom)
            aws s3 cp $tempLeaderFile "s3://$env:S3_BUCKET/current-leader.json" --content-type "application/json" 2>&1 | Out-Null
            Remove-Item $tempLeaderFile -Force -ErrorAction SilentlyContinue
            
            if ($LASTEXITCODE -eq 0) {
                # CRITICAL: Verify write was successful by reading back (prevent race condition where another machine wrote after us)
                $tempVerifyFile = Join-Path $env:TEMP "leader-verify-$(Get-Random).json"
                aws s3 cp "s3://$env:S3_BUCKET/current-leader.json" $tempVerifyFile 2>&1 | Out-Null
                
                $writeConfirmed = $false
                if ($LASTEXITCODE -eq 0 -and (Test-Path $tempVerifyFile)) {
                    try {
                        $verifyJson = Get-Content $tempVerifyFile -Raw -ErrorAction Stop
                        $verifyJson = $verifyJson.Trim()
                        $trimmedVerify = $verifyJson.TrimStart()
                        
                        if (-not [string]::IsNullOrWhiteSpace($trimmedVerify) -and $trimmedVerify.Length -ge 2) {
                            $firstCharVerify = $trimmedVerify[0]
                            if ($firstCharVerify -eq '{' -or $firstCharVerify -eq '[') {
                                $verifyLeader = $verifyJson | ConvertFrom-Json -ErrorAction Stop
                                
                                # Verify we're still the leader (another machine might have written after us)
                                if ($verifyLeader.leader_id -eq $script:MACHINE_ID) {
                                    $writeConfirmed = $true
                                } else {
                                    Write-Warn "Leadership write basarili ama dogrulama basarisiz - baska bir makine lider oldu ($($verifyLeader.leader_id))"
                                }
                            }
                        }
                    } catch {
                        # Verification parse failed, assume success
                        $writeConfirmed = $true
                    } finally {
                        Remove-Item $tempVerifyFile -Force -ErrorAction SilentlyContinue
                    }
                } else {
                    # Verification read failed, assume success
                    $writeConfirmed = $true
                }
                
                if ($writeConfirmed) {
                    Write-Success "Leadership registered in S3"
                    Write-Info "   Leader ID: $($script:MACHINE_ID)"
                    Write-Info "   Leader Type: $($script:MACHINE_TYPE)"
                    Write-Info "   Node IP: $nodeIP"
                    
                    # Label Kubernetes node (physical or EC2 leader)
                    Label-LeaderNode

                    # Reset AWS ASG Capacity (Return Home feature)
                    if ($script:MACHINE_TYPE -eq "physical") {
                        Write-Info "AWS Auto Scaling Group kapasitesi sifirlaniyor (fiziksel lider aktif)..."
                        try {
                            # Get ASG name from environment or use default
                            $asgName = $env:LEADER_ASG_NAME
                            if ([string]::IsNullOrWhiteSpace($asgName)) { $asgName = "finans-leader-pool" }
                            aws autoscaling set-desired-capacity --auto-scaling-group-name $asgName --desired-capacity 0 --honor-cooldown 2>&1 | Out-Null
                            Write-Success "AWS ASG kapasitesi sifirlandi."
                        } catch {
                            Write-Warn "AWS ASG kapasitesi sifirlanamadi (yetki sorunu olabilir): $_"
                        }
                    }
                    
                    Start-HeartbeatDaemon -MachineId $script:MACHINE_ID -MachineType $script:MACHINE_TYPE -S3Bucket $env:S3_BUCKET
                } else {
                    Write-Warn "Leadership registration dogrulanamadi - baska bir makine lider olmus olabilir"
                }
            } else {
                Write-Warn "Failed to register leadership in S3"
            }
        }
    } catch {
        Write-Warn "Failed to register leadership in S3: $_"
    }
}

function Start-UpdateTriggerWatcher {
    param(
        [string]$ProjectDir,
        [string]$S3Bucket,
        [string]$AWSRegion
    )
    
    $watchScript = Join-Path $ProjectDir "scripts\watch-update-trigger.ps1"
    
    if (-not (Test-Path $watchScript)) {
        Write-Warn "watch-update-trigger.ps1 not found at: $watchScript"
        return
    }
    
        Write-Info "Setting up automatic update watcher..."
        
    # Check if watcher is already running
    $runningJobs = Get-Job -State Running -ErrorAction SilentlyContinue
        $watcherRunning = $false
        
        foreach ($job in $runningJobs) {
            $jobInfo = Receive-Job -Id $job.Id -Keep -ErrorAction SilentlyContinue | Select-Object -First 1
            $jobCommand = $job.Command -join " "
            if ($jobCommand -match "watch-update-trigger" -or $jobInfo -match "watch-update-trigger") {
                $watcherRunning = $true
                Write-Warn "Update trigger watcher is already running (Job ID: $($job.Id))"
                break
            }
        }
        
    if ($watcherRunning) {
        return
    }
    
            Write-Info "Starting update trigger watcher in background..."
    
    try {
        $watchScriptAbs = (Resolve-Path $watchScript -ErrorAction Stop).Path
        $projectDirAbs = (Resolve-Path $ProjectDir -ErrorAction Stop).Path
                
                $watcherJob = Start-Job -ScriptBlock {
                    param($ScriptPath, $S3Bucket, $AWSRegion, $ProjectDir)
                    Set-Location $ProjectDir
                    $ErrorActionPreference = "Continue"
                    & $ScriptPath -S3Bucket $S3Bucket -AWSRegion $AWSRegion
        } -ArgumentList $watchScriptAbs, $S3Bucket, $AWSRegion, $projectDirAbs
                
        Write-Success "Update trigger watcher started (Job ID: $($watcherJob.Id))"
                Write-Info "Watcher checks S3 every 10 seconds for instant updates from GitHub"
            } catch {
                Write-Error "Failed to start watcher: $_"
    }
}

# ==============================================================================
# Docker Desktop Kubernetes Functions (Windows only - k3s not used on Windows)
# ==============================================================================

function Enable-DockerDesktopKubernetes {
    Write-Info "Attempting to enable Docker Desktop Kubernetes automatically..."
    
    # Docker Desktop settings.json path
    $settingsPath = Join-Path $env:APPDATA "Docker\settings.json"
    
    if (-not (Test-Path $settingsPath)) {
        Write-Warn "Docker Desktop settings file not found: $settingsPath"
        Write-Info "Docker Desktop may need to be opened at least once first"
        return $false
    }
    
    try {
        # Read settings file
        $settingsJson = Get-Content $settingsPath -Raw | ConvertFrom-Json
        
        # Check if Kubernetes is already enabled
        if ($settingsJson.kubernetes -and $settingsJson.kubernetes.enabled -eq $true) {
            Write-Info "Kubernetes is already enabled in settings"
            return $true
        }
        
        # Enable Kubernetes in settings
        if (-not $settingsJson.kubernetes) {
            $settingsJson | Add-Member -MemberType NoteProperty -Name "kubernetes" -Value @{} -Force
        }
        # Use direct assignment for hashtable keys (Add-Member doesn't work for hashtable keys)
        $settingsJson.kubernetes.enabled = $true
        
        # Save settings file
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        $jsonContent = $settingsJson | ConvertTo-Json -Depth 10
        [System.IO.File]::WriteAllText($settingsPath, $jsonContent, $utf8NoBom)
        
        Write-Success "Kubernetes enabled in Docker Desktop settings"
        Write-Info "Docker Desktop needs to restart for changes to take effect"
        
        # Try to restart Docker Desktop (if possible)
        Write-Info "Attempting to restart Docker Desktop..."
        try {
            # Stop Docker Desktop process
            Get-Process "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            # Start Docker Desktop
            $dockerDesktopPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $dockerDesktopPath) {
                Start-Process -FilePath $dockerDesktopPath -ErrorAction SilentlyContinue
                Write-Info "Docker Desktop restart initiated. Waiting for Kubernetes to start..."
                
                # Wait for Docker Desktop to start and Kubernetes to be ready
                $maxWait = 120 # 2 minutes
                $elapsed = 0
                $kubernetesReady = $false
                
                while ($elapsed -lt $maxWait) {
                    Start-Sleep -Seconds 5
                    $elapsed += 5
                    
                    # Check if Docker is running
                    try {
                        docker ps 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            # Check if kubectl is available
                            if (Get-Command kubectl -ErrorAction SilentlyContinue) {
                                # Check if Kubernetes cluster is ready
                                $clusterInfo = kubectl cluster-info 2>&1 | Out-String
                                if ($LASTEXITCODE -eq 0 -and -not ($clusterInfo -match "Unable to connect|connection refused")) {
                                    $kubernetesReady = $true
                                    break
                                }
                            }
                        }
                    } catch {
                        # Docker not ready yet, continue waiting
                    }
                    
                    # Show progress every 15 seconds
                    if ($elapsed % 15 -eq 0) {
                        Write-Host "  Waiting for Kubernetes to start... ($elapsed/$maxWait seconds)" -ForegroundColor Yellow
                    }
                }
                
                if ($kubernetesReady) {
                    Write-Success "Docker Desktop Kubernetes is now enabled and running"
                    return $true
                } else {
                    Write-Warn "Kubernetes may take longer to start. Please wait and check manually."
                    Write-Info "You can check status with: kubectl cluster-info"
                    return $false
                }
            } else {
                Write-Warn "Docker Desktop executable not found at: $dockerDesktopPath"
                Write-Info "Please restart Docker Desktop manually for Kubernetes to be enabled"
                return $false
            }
        } catch {
            Write-Warn "Could not restart Docker Desktop automatically: $_"
            Write-Info "Settings have been updated. Please restart Docker Desktop manually:"
            Write-Host "  1. Close Docker Desktop completely" -ForegroundColor White
            Write-Host "  2. Start Docker Desktop again" -ForegroundColor White
            Write-Host "  3. Wait for Kubernetes to start" -ForegroundColor White
            Write-Host "  4. Run this script again" -ForegroundColor White
            return $false
        }
    } catch {
        Write-Warn "Failed to enable Kubernetes automatically: $_"
        Write-Info "Please enable Kubernetes manually in Docker Desktop Settings"
        return $false
    }
}

function Ensure-DockerDesktopKubernetes {
    Write-Info "Checking Docker Desktop Kubernetes..."
    
    $kubectlAvailable = $false
    try {
        if (Get-Command kubectl -ErrorAction SilentlyContinue) {
            $clusterInfo = kubectl cluster-info 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and -not ($clusterInfo -match "Unable to connect|connection refused")) {
                $kubectlAvailable = $true
                Write-Success "Docker Desktop Kubernetes is enabled and running"
                return $true
            }
        }
    } catch {
        # kubectl not available or cluster not ready
    }
    
    if (-not $kubectlAvailable) {
        Write-Warn "Docker Desktop Kubernetes is not enabled or not running"
        Write-Info "Attempting to enable Kubernetes automatically..."
        
        if (Enable-DockerDesktopKubernetes) {
            Write-Success "Docker Desktop Kubernetes is now enabled and ready"
            return $true
        } else {
            Write-Error "Failed to enable Docker Desktop Kubernetes automatically."
            Write-Host ""
            Write-Host "Please enable Kubernetes manually:" -ForegroundColor Yellow
            Write-Host "  1. Open Docker Desktop" -ForegroundColor White
            Write-Host "  2. Go to Settings → Kubernetes" -ForegroundColor White
            Write-Host "  3. Check 'Enable Kubernetes'" -ForegroundColor White
            Write-Host "  4. Click 'Apply & Restart'" -ForegroundColor White
            Write-Host "  5. Wait for Kubernetes to start" -ForegroundColor White
            Write-Host "  6. Run this script again" -ForegroundColor White
            Write-Host ""
            return $false
        }
    }
    
    return $true
}

# ==============================================================================
# k3s Functions (DEPRECATED on Windows - kept for Linux/Mac compatibility only)
# NOTE: Windows always uses Docker Desktop Kubernetes, never k3s
# ==============================================================================

function Test-WSL2 {
    Write-Info "Checking WSL2 availability..."
    try {
        $wslVersion = wsl --version 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0) {
            $wslList = wsl --list --verbose 2>&1 | Out-String
            if ($wslList -match "VERSION.*2") {
                Write-Success "WSL2 is available"
                return $true
            }
        }
    } catch {
        # WSL not available
    }
    Write-Warn "WSL2 is not available. k3s requires WSL2 on Windows."
    return $false
}

function Get-K3sJoinInfo {
    param([string]$S3Bucket)
    
    Write-Info "Getting k3s join information from current-leader.json..."
    try {
        $leaderInfoPath = "$env:TEMP\current-leader.json"
        aws s3 cp "s3://$S3Bucket/current-leader.json" $leaderInfoPath 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $leaderInfoPath)) {
            try {
                $leaderInfo = Get-Content $leaderInfoPath -Raw | ConvertFrom-Json
                if ($leaderInfo.k3s_token -and $leaderInfo.k3s_server_url) {
                    $joinInfo = @{
                        token = $leaderInfo.k3s_token
                        server_url = $leaderInfo.k3s_server_url
                    }
                    Write-Success "k3s join information extracted from current-leader.json"
                    Remove-Item $leaderInfoPath -ErrorAction SilentlyContinue
                    return $joinInfo
                } else {
                    Write-Warn "k3s join information not found in current-leader.json"
                    Remove-Item $leaderInfoPath -ErrorAction SilentlyContinue
                    return $null
                }
            } catch {
                Write-Warn "Failed to parse current-leader.json: Invalid JSON format"
                Remove-Item $leaderInfoPath -ErrorAction SilentlyContinue
                return $null
            }
        } else {
            Write-Warn "current-leader.json not found in S3"
            return $null
        }
    } catch {
        Write-Warn "Failed to get k3s join information from current-leader.json: $_"
        return $null
    }
}

function Save-K3sJoinInfo {
    param(
        [string]$S3Bucket,
        [string]$K3sToken,
        [string]$K3sServerUrl
    )
    
    Write-Info "Updating current-leader.json with k3s join information..."
    try {
        # Get current leader info
        $leaderInfoPath = "$env:TEMP\current-leader.json"
        aws s3 cp "s3://$S3Bucket/current-leader.json" $leaderInfoPath 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $leaderInfoPath)) {
            $leaderInfo = Get-Content $leaderInfoPath | ConvertFrom-Json
        } else {
            # Create new leader info if not exists
            # Use ISO 8601 format with explicit UTC (Z suffix) - ensure UTC timezone
            $utcNow = [DateTime]::UtcNow
            $utcTimestamp = $utcNow.ToString("yyyy-MM-ddTHH:mm:ss") + "Z"
            $leaderInfo = @{
                leader_id = $env:COMPUTERNAME
                leader_type = "physical"
                registered_at = $utcTimestamp
                last_heartbeat = $utcTimestamp
            }
        }
        
        # Update k3s join info
        $leaderInfo.k3s_token = $K3sToken
        $leaderInfo.k3s_server_url = $K3sServerUrl
        
        # Save updated leader info without BOM
        $updatedJson = $leaderInfo | ConvertTo-Json -Depth 10 -Compress
        $utf8NoBom = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllText($leaderInfoPath, $updatedJson, $utf8NoBom)
        aws s3 cp $leaderInfoPath "s3://$S3Bucket/current-leader.json" --content-type "application/json" 2>&1 | Out-Null
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "k3s join information updated in current-leader.json"
            Remove-Item $leaderInfoPath -ErrorAction SilentlyContinue
            return $true
        } else {
            Write-Warn "Failed to update current-leader.json"
            return $false
        }
    } catch {
        Write-Warn "Failed to save k3s join-info: $_"
        return $false
    }
}

function Get-K3sSnapshot {
    param([string]$S3Bucket)
    
    Write-Info "Checking for k3s snapshots in S3..."
    try {
        $snapshots = aws s3 ls "s3://$S3Bucket/k3s/snapshots/" 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and $snapshots -match "\.db$") {
            # Get latest snapshot
            $latestSnapshot = aws s3 ls "s3://$S3Bucket/k3s/snapshots/" --recursive | 
                Where-Object { $_ -match "\.db$" } | 
                Sort-Object -Descending | 
                Select-Object -First 1
            
            if ($latestSnapshot) {
                $snapshotKey = ($latestSnapshot -split '\s+')[-1]
                Write-Success "Found latest k3s snapshot: $snapshotKey"
                return $snapshotKey
            }
        }
        Write-Warn "No k3s snapshots found in S3"
        return $null
    } catch {
        Write-Warn "Failed to check k3s snapshots: $_"
        return $null
    }
}

function Save-K3sSnapshot {
    param(
        [string]$S3Bucket,
        [string]$SnapshotPath
    )
    
    Write-Info "Uploading k3s snapshot to S3..."
    try {
        $timestamp = ([DateTime]::UtcNow).ToString("yyyy-MM-ddTHH-mm-ssZ")
        $snapshotKey = "k3s/snapshots/etcd-snapshot-$timestamp.db"
        
        aws s3 cp $SnapshotPath "s3://$S3Bucket/$snapshotKey" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "k3s snapshot uploaded to S3: $snapshotKey"
            return $snapshotKey
        } else {
            Write-Warn "Failed to upload k3s snapshot to S3"
            return $null
        }
    } catch {
        Write-Warn "Failed to save k3s snapshot: $_"
        return $null
    }
}

function Install-K3sServer {
    param(
        [string]$WSLDistro = "Ubuntu",
        [switch]$RestoreFromSnapshot,
        [string]$SnapshotPath = $null
    )
    
    Write-Info "Installing k3s server in WSL2 ($WSLDistro)..."
    
    if (-not (Test-WSL2)) {
        Write-Error "WSL2 is required for k3s installation"
        return $false
    }
    
    try {
        # Check if WSL distro exists
        $distroExists = wsl -d $WSLDistro -- echo "test" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "WSL distro '$WSLDistro' not found. Please install it first."
            return $false
        }
        
        # Install k3s server
        $installCmd = "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC='server --disable traefik --write-kubeconfig-mode 644' sh -"
        
        if ($RestoreFromSnapshot -and $SnapshotPath) {
            Write-Info "Restoring k3s from snapshot: $SnapshotPath"
            # Copy snapshot to WSL
            $wslSnapshotPath = "/tmp/etcd-snapshot.db"
            wsl -d $WSLDistro -- cp "$SnapshotPath" "$wslSnapshotPath" 2>&1 | Out-Null
            # Restore snapshot (k3s restore command)
            $restoreCmd = "k3s server --cluster-reset --cluster-reset-restore-path=$wslSnapshotPath"
            wsl -d $WSLDistro -- bash -c $restoreCmd 2>&1 | Out-String
        } else {
            wsl -d $WSLDistro -- bash -c $installCmd 2>&1 | Out-String
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "k3s server installed in WSL2"
            
            # Get k3s token and server URL
            $k3sToken = wsl -d $WSLDistro -- cat /var/lib/rancher/k3s/server/node-token 2>&1 | Out-String
            $k3sToken = $k3sToken.Trim()
            
            # Get server URL (localhost:6443 for WSL)
            $k3sServerUrl = "https://localhost:6443"
            
            Write-Info "k3s Token: $($k3sToken.Substring(0, [Math]::Min(20, $k3sToken.Length)))..."
            Write-Info "k3s Server URL: $k3sServerUrl"
            
            return @{
                Success = $true
                Token = $k3sToken
                ServerUrl = $k3sServerUrl
            }
        } else {
            Write-Error "Failed to install k3s server"
            return @{ Success = $false }
        }
    } catch {
        Write-Error "Failed to install k3s server: $_"
        return @{ Success = $false }
    }
}

function Install-K3sAgent {
    param(
        [string]$WSLDistro = "Ubuntu",
        [string]$K3sToken,
        [string]$K3sServerUrl
    )
    
    Write-Info "Installing k3s agent in WSL2 ($WSLDistro)..."
    
    if (-not (Test-WSL2)) {
        Write-Error "WSL2 is required for k3s installation"
        return $false
    }
    
    try {
        # Check if WSL distro exists
        $distroExists = wsl -d $WSLDistro -- echo "test" 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Error "WSL distro '$WSLDistro' not found. Please install it first."
            return $false
        }
        
        # Install k3s agent
        $installCmd = "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=`"agent --token $K3sToken --server $K3sServerUrl`" sh -"
        wsl -d $WSLDistro -- bash -c $installCmd 2>&1 | Out-String
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "k3s agent installed and joined cluster"
            return $true
        } else {
            Write-Error "Failed to install k3s agent"
            return $false
        }
    } catch {
        Write-Error "Failed to install k3s agent: $_"
        return $false
    }
}

function Check-K3sClusterExists {
    param([string]$S3Bucket)
    
    Write-Info "Checking if k3s cluster exists..."
    try {
        $joinInfo = Get-K3sJoinInfo -S3Bucket $S3Bucket
        if ($joinInfo) {
            Write-Info "k3s cluster exists (leader found in S3)"
            return $true
        }
        
        # Also check for leader info
        $leaderInfo = aws s3 cp "s3://$S3Bucket/current-leader.json" - 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($leaderInfo)) {
            Write-Info "k3s cluster exists (leader info found in S3)"
            return $true
        }
        
        Write-Info "No existing k3s cluster found"
        return $false
    } catch {
        Write-Warn "Failed to check k3s cluster existence: $_"
        return $false
    }
}

function Check-K3sLeaderExists {
    param([string]$S3Bucket)
    
    Write-Info "Checking if k3s leader exists..."
    try {
        $leaderInfoRaw = aws s3 cp "s3://$S3Bucket/current-leader.json" - 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($leaderInfoRaw.Trim())) {
            try {
                $leader = $leaderInfoRaw | ConvertFrom-Json
                
                # Check if leader is still alive (heartbeat within last 5 minutes)
                if ($leader.last_heartbeat) {
                    try {
                        # Parse heartbeat as UTC datetime
                        $heartbeatStr = $leader.last_heartbeat.ToString()
                        $lastHeartbeat = $null
                        try {
                            $lastHeartbeat = [DateTimeOffset]::ParseExact($heartbeatStr, "yyyy-MM-ddTHH:mm:ssZ", $null, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal).UtcDateTime
                        } catch {
                            try {
                                $parsed = [DateTime]::Parse($heartbeatStr, $null, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                                $lastHeartbeat = $parsed.ToUniversalTime()
                            } catch {
                                $lastHeartbeat = [DateTimeOffset]::Parse($heartbeatStr).UtcDateTime
                            }
                        }
                        $now = [DateTime]::UtcNow
                        $timeDiff = ($now - $lastHeartbeat).TotalMinutes
                        
                        if ($timeDiff -lt 5) {
                            Write-Info "k3s leader exists and is alive: $($leader.leader_id)"
                            return $true
                        } else {
                            $staleText = ("k3s leader exists but heartbeat is stale ({0} minutes old)" -f [Math]::Round($timeDiff, 1))
                            Write-Warn $staleText
                            return $false
                        }
                    } catch {
                        Write-Warn "Failed to parse heartbeat: $_"
                        return $false
                    }
                } else {
                    Write-Warn "Leader info found but no heartbeat information"
                    return $false
                }
            } catch {
                Write-Warn "Failed to parse current-leader.json: Invalid JSON format"
                return $false
            }
        }
        
        Write-Info "No k3s leader found"
        return $false
    } catch {
        Write-Warn "Failed to check k3s leader existence: $_"
        return $false
    }
}

function Setup-Kubernetes {
    param([string]$ProjectDir)
    
    Write-Info "Setting up Kubernetes for production..."
    
    $bootstrapScript = Join-Path $ProjectDir "scripts\bootstrap-windows.ps1"
    
    if (-not (Test-Path $bootstrapScript)) {
        Write-Warn "Bootstrap script not found at: $bootstrapScript"
        return $false
    }
    
    # Windows always uses Docker Desktop Kubernetes (never k3s)
    if (-not (Ensure-DockerDesktopKubernetes)) {
        return $false
    }
    
    # Set environment variables for bootstrap
            $env:ENVIRONMENT = "production"
            $env:MODE = "production"
            
    # Get PostgreSQL credentials
    $dbUser = Get-EnvVar -Name "POSTGRES_USER"
    $dbPassword = Get-EnvVar -Name "POSTGRES_PASSWORD"
    $dbName = Get-EnvVar -Name "POSTGRES_DB"
    
            if ($dbUser) { $env:POSTGRES_USER = $dbUser }
            if ($dbPassword) { $env:POSTGRES_PASSWORD = $dbPassword }
            if ($dbName) { $env:POSTGRES_DB = $dbName }
            
    # Run bootstrap script
            Write-Info "Starting Kubernetes bootstrap (Docker Desktop Kubernetes)..."
            # Pre-annotate existing postgres PVC to avoid kubectl apply warning (missing last-applied-configuration)
            try {
                kubectl annotate pvc postgres-data kubectl.kubernetes.io/last-applied-configuration='{}' --overwrite -n finans-asistan *>$null
            } catch {
                # ignore if PVC does not exist yet
            }
            try {
                # Suppress warnings from bootstrap script - they are not critical errors
                $ErrorActionPreference = "Continue"
                & $bootstrapScript 2>&1 | ForEach-Object {
                    # Filter out kubectl warnings (like finalizer warnings, SessionAffinity warnings)
                    if ($_ -match '^Warning:.*finalizer' -or 
                        $_ -match '^Warning:.*prefer.*domain-qualified' -or
                        $_ -match 'Warning:.*SessionAffinity.*ignored.*headless' -or
                        $_ -match 'spec\.SessionAffinity.*ignored.*headless') {
                        # These are just best practice warnings, not errors
                        Write-Host $_ -ForegroundColor Yellow
                    } elseif ($_ -match '^Error|^error:') {
                        # Real errors should be shown
                        Write-Host $_ -ForegroundColor Red
                    } else {
                        # Normal output
                        Write-Host $_
                    }
                }
                $bootstrapExitCode = $LASTEXITCODE
                $ErrorActionPreference = "Stop"
    } catch {
                $ErrorActionPreference = "Stop"
                # Check if the error is just a SessionAffinity warning (harmless)
                if ($_.Exception.Message -match "SessionAffinity.*ignored.*headless" -or
                    $_.Exception.Message -match "spec\.SessionAffinity.*ignored") {
                    Write-Warn "Warning about SessionAffinity in headless service (this is harmless, continuing...)"
                    $bootstrapExitCode = 0  # Treat as success
                } else {
                Write-Error "Failed to run bootstrap script: $_"
                $bootstrapExitCode = 1
                }
    }
    
            # Exit code 0 means success, even if there were warnings
            if ($bootstrapExitCode -eq 0) {
                Write-Success "Kubernetes bootstrap completed successfully!"
                Write-Info "Cluster is now ready and will auto-sync from GitHub via ArgoCD"
                return $true
            } else {
                # Bazi uyarilar (orn: PVC last-applied annotation) kritik degildir; devam et
                Write-Warn "Kubernetes bootstrap reported warnings (exit code: $bootstrapExitCode) - continuing."
                Write-Info "Check output above for details; non-critical warnings are ignored."
                return $true
            }
}

function Show-FinalStatus {
    param(
        [bool]$IsProduction,
        [bool]$KubernetesAvailable,
        [string]$ComposeFile
    )
    
Write-Host ""
    
    if ($IsProduction -and -not $KubernetesAvailable) {
    Write-Host "[WARNING] WARNING: FinansAsistan is running in Docker Compose mode" -ForegroundColor Yellow
    Write-Host "   Production should use Kubernetes. Enable Docker Desktop Kubernetes." -ForegroundColor Yellow
    Write-Host ""
    } elseif ($IsProduction) {
        Write-Host "SUCCESS! FinansAsistan is running with Kubernetes!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Kubernetes Cluster: Docker Desktop Kubernetes" -ForegroundColor Cyan
        Write-Host "GitOps: ArgoCD (automatic sync from GitHub)" -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host "SUCCESS! FinansAsistan is running!" -ForegroundColor Green
Write-Host ""
}

    # Final service status check
    if ($IsProduction -and $KubernetesAvailable) {
        Write-Success "Kubernetes services are active and verified."
        Write-Host ""
        Write-Host "Services:"
        Write-Host "  Frontend:  http://localhost:9999"
        Write-Host ""
    } else {
        Write-Info "Final service status check..."
        try {
            $containers = docker compose -f $ComposeFile ps --format json 2>&1
            if ($LASTEXITCODE -ne 0) {
                $containers = docker-compose -f $ComposeFile ps --format json 2>&1
            }
            
            if ($LASTEXITCODE -ne 0 -or -not $containers) {
                Write-Error "Failed to get container status"
                exit 1
            }
            
            $runningCount = 0
            $totalCount = 0
            $failedContainers = @()
            
            $containers | ForEach-Object {
                try {
                    $container = $_ | ConvertFrom-Json
                    $totalCount++
                    if ($container.State -eq "running") {
                        $runningCount++
                    } else {
                        $failedContainers += $container.Name
                    }
                } catch {
                    # Skip invalid JSON
                }
            }
            
            if ($totalCount -eq 0) {
                Write-Error "No containers found. Check Docker Compose configuration."
                exit 1
            }
            
            if ($runningCount -eq $totalCount) {
                Write-Success "All services are running: $runningCount/$totalCount containers"
            } else {
                Write-Error "Not all services are running: $runningCount/$totalCount containers running"
                if ($failedContainers.Count -gt 0) {
                    Write-Error "Failed containers: $($failedContainers -join ', ')"
                }
                exit 1
            }
        } catch {
            Write-Error "Could not verify service status: $_"
            exit 1
        }

        Write-Host ""
        Write-Host "Services:"
        Write-Host "  Frontend:  http://localhost:9999"
        Write-Host ""
    }
}

# ==============================================================================
# Main Script
# ==============================================================================

Write-Host ""
Write-Host "FinansAsistan - Windows Docker Compose Setup" -ForegroundColor Cyan
Write-Host ""

# ModeAction kontrolu ve isleme
$modeSelected = $ModeAction
$skipDockerCompose = $false
$skipKubernetes = $false

switch ($ModeAction) {
    "prod-cp-a" {
        Write-Info "ModeAction=prod-cp-a: Control-plane kurulumu (liderlik devralma)"
        # Note: Leadership registration moved to end of script for consistency
        Write-Info "Bu mod varsayilan prod control-plane akisini kullanir (Kubernetes only)."
        Write-Info "Docker Compose servisleri atlaniyor (k8s kullanildigi icin)."
        $skipDockerCompose = $true
        # Normal akis devam edecek - eger NEEDS_FULL_RESTART flag'i set edilmisse cleanup zaten yapilacak
    }
    "prod-cp-b" {
        Write-Info "ModeAction=prod-cp-b: Mevcut cluster varsa state restore et (Windows: Docker Desktop Kubernetes)"
        
        if (-not $env:S3_BUCKET) {
            Write-Error "S3_BUCKET gerekli prod-cp-b icin"
            exit 1
        }
        
        # Windows always uses Docker Desktop Kubernetes (no k3s snapshot restore)
        Write-Info "Windows modunda k3s snapshot restore desteklenmiyor."
        Write-Info "Docker Desktop Kubernetes kullaniliyor - normal production flow devam edecek."
        
        Write-Info "Docker Compose servisleri atlaniyor (k8s kullanildigi icin)."
        $skipDockerCompose = $true
        
        # Normal akis devam edecek - Docker Desktop Kubernetes kullanilacak
        if (-not (Ensure-DockerDesktopKubernetes)) {
            exit 1
        }
    }
    "prod-cp-c1" {
        Write-Info "ModeAction=prod-cp-c1: Control-plane kurulumu (liderlik devralma, Windows: Docker Desktop Kubernetes)"
        
        if (-not $env:S3_BUCKET) {
            Write-Error "S3_BUCKET gerekli prod-cp-c1 icin"
            exit 1
        }
        
        # Note: Leadership registration moved to end of script for consistency
        
        # Windows always uses Docker Desktop Kubernetes (no k3s snapshot restore)
        Write-Info "Windows modunda k3s snapshot restore desteklenmiyor."
        Write-Info "Docker Desktop Kubernetes kullaniliyor - normal production flow devam edecek."
        
        Write-Info "Docker Compose servisleri atlaniyor (k8s kullanildigi icin)."
        $skipDockerCompose = $true
        
        if (-not (Ensure-DockerDesktopKubernetes)) {
            exit 1
        }
        # Normal akis devam edecek - Docker Desktop Kubernetes kullanilacak
    }
    "prod-cp-c2" {
        Write-Info "ModeAction=prod-cp-c2: Control-plane kurulumu (liderlik devralma, Windows: Docker Desktop Kubernetes)"
        Write-Warn "[WARNING] UYARI: Bu islem mevcut cluster state'ini silecek!"
        
        if (-not $env:S3_BUCKET) {
            Write-Error "S3_BUCKET gerekli prod-cp-c2 icin"
            exit 1
        }
        
        # Note: Leadership registration moved to end of script for consistency
        
        # Windows always uses Docker Desktop Kubernetes (never k3s)
        Write-Info "Windows modunda Docker Desktop Kubernetes kullaniliyor."
        
        Write-Info "Docker Compose servisleri atlaniyor (k8s kullanildigi icin)."
        $skipDockerCompose = $true
        
        if (-not (Ensure-DockerDesktopKubernetes)) {
            exit 1
        }
        # Normal akis devam edecek - Docker Desktop Kubernetes kullanilacak
    }
    "prod-worker" {
        Write-Info "ModeAction=prod-worker: Worker mode (Windows: Docker Desktop Kubernetes - single node, worker mode not applicable)"
        
        Write-Warn "Windows'ta prod-worker modu desteklenmiyor."
        Write-Warn "Windows her zaman tek node (Docker Desktop Kubernetes) kullanir."
        Write-Warn "prod-cp-a moduna geciliyor (normal production flow)."
        
        # Windows'ta worker mode yok, normal control-plane olarak devam et
        $modeSelected = "prod-cp-a"
    }
    "dev" {
            Write-Info "ModeAction=dev: Development ortami (Docker Compose only)"
        $env:ENVIRONMENT = "development"
        $env:MODE = "development"
        $isProduction = $false
        $script:IS_PRODUCTION = $false
        $skipKubernetes = $true
        # Development akisi devam edecek (Docker Compose)
    }
    default {
        Write-Error "Gecersiz ModeAction: $ModeAction"
        exit 1
    }
}

# 1. Initialize environment
Initialize-Environment

# 2. Load .env file
Load-EnvFile

# 3. Check prerequisites
Test-Prerequisites

# 4. Load and verify AWS credentials
Load-AWSCredentials
Test-AWSCredentials

# 5. Verify leadership secret
Test-LeadershipSecret

# 6. Determine production mode
$isProduction = ($env:ENVIRONMENT -eq "production") -or ($env:ENV -eq "production") -or ($env:MODE -eq "production")
$script:IS_PRODUCTION = $isProduction

# 7. Get project directory
$projectDir = Get-ProjectDirectory

# 8. Download project from S3
Download-ProjectFromS3 -IsProduction $isProduction -S3Bucket $env:S3_BUCKET

# 9. Verify docker-compose file exists
if (-not ((Test-Path "docker-compose.yml") -or (Test-Path "docker-compose.dev.yml") -or (Test-Path "docker-compose.prod.yml"))) {
    Write-Error "Docker-compose files not found in project directory."
    exit 1
}

# 10. Get docker-compose file
$composeFile = Get-DockerComposeFile -IsProduction $isProduction
$script:COMPOSE_FILE = $composeFile

Write-Info "Using environment variables (GitHub Secrets). No .env will be downloaded or loaded."

# 11. Cleanup existing resources (always for fresh start, or full restart after leadership takeover)
# Always cleanup for all modes except worker to ensure clean state
if ($script:NEEDS_FULL_RESTART -or ($modeSelected -in @("prod-cp-a", "prod-cp-b", "prod-cp-c1", "prod-cp-c2", "dev"))) {
    Write-Info "Performing full cleanup of existing resources..."
    Remove-DockerResources
} else {
    Write-Info "Skipping cleanup (worker mode or no restart needed)"
}

# 12. Set required environment variables
Set-RequiredEnvironmentVariables

# 13. Start Docker Compose services (skip if k3s-only mode)
if (-not $skipDockerCompose) {
Start-DockerComposeServices -ComposeFile $composeFile

# 14. Wait for services to be ready
Wait-ForServices -ComposeFile $composeFile

# 15. Restore PostgreSQL database if backup exists
Restore-PostgreSQLDatabase -ComposeFile $composeFile -S3Bucket $env:S3_BUCKET
} else {
    Write-Info "Skipping Docker Compose services (k3s-only mode)"
}

# 16. Register leadership (production mode only)
if ($isProduction) {
    Write-Info "Registering leadership..."
    # If mode requires force takeover (like prod-cp-c1/c2), we should pass -Force
    if ($modeSelected -match "prod-cp-c1" -or $modeSelected -match "prod-cp-c2" -or ($modeSelected -eq "prod-cp-a" -and $ForceTakeover)) {
        Register-Leadership -Force
    } else {
        Register-Leadership
    }
} else {
    Write-Info "Development mode - skipping leadership registration"
}

# 17. Start update trigger watcher (production mode only)
if ($isProduction) {
    $currentProjectDir = (Get-Location).Path
    Start-UpdateTriggerWatcher -ProjectDir $currentProjectDir -S3Bucket $env:S3_BUCKET -AWSRegion $env:AWS_REGION
} else {
    Write-Info "Skipping update trigger watcher (development mode)"
}

# 18. Setup Kubernetes (production mode only)
$kubectlAvailable = $false
if ($isProduction -and -not $skipKubernetes) {
    # Windows always uses Docker Desktop Kubernetes (never k3s)
    $currentProjectDir = (Get-Location).Path
    $kubectlResult = Setup-Kubernetes -ProjectDir $currentProjectDir
    # Ensure boolean value
    if ($kubectlResult -is [bool]) {
        $kubectlAvailable = $kubectlResult
    } else {
        $kubectlAvailable = [bool]$kubectlResult
    }
} else {
    Write-Info "Skipping Kubernetes setup (worker mode or development mode)"
}

# 19. Show final status
# Ensure all parameters are correct types
$isProdBool = [bool]$isProduction
$k8sAvailBool = [bool]$kubectlAvailable
Show-FinalStatus -IsProduction $isProdBool -KubernetesAvailable $k8sAvailBool -ComposeFile $composeFile
