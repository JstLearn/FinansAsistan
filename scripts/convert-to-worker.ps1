# FinansAsistan - Convert Leader to Worker Script
# Bu script eski lider makineyi worker moduna gecirir
# Windows: Docker Desktop Kubernetes kullanilir (worker join desteklenmez, servisler durdurulur)
# Linux/Mac: k3s agent kurulur ve yeni liderin cluster'ina baglanir

param(
    [string]$WorkerFlagFile = "$env:TEMP\convert-to-worker.flag"
)

$ErrorActionPreference = "Stop"

# UTF-8 encoding
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

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

# Detect OS (use automatic variables, don't reassign readonly variables)
$runningOnWindows = if ($IsWindows) { $true } elseif ($env:OS -match "Windows") { $true } else { $false }
$runningOnMacOS = if ($IsMacOS) { $true } elseif ($PSVersionTable.OS -match "Darwin") { $true } else { $false }
$runningOnLinux = if ($IsLinux) { $true } elseif (-not $runningOnWindows -and -not $runningOnMacOS) { $true } else { $false }

# Check if flag file exists
if (-not (Test-Path $WorkerFlagFile)) {
    Write-Error "Worker flag file not found: $WorkerFlagFile"
    exit 1
}

# Read worker info from flag file
try {
    $workerInfoJson = Get-Content $WorkerFlagFile -Raw -Encoding UTF8
    $workerInfo = $workerInfoJson | ConvertFrom-Json
    
    $newLeaderId = $workerInfo.new_leader_id
    $newLeaderIP = $workerInfo.new_leader_ip
    $k3sToken = $workerInfo.k3s_token
    $k3sServerUrl = $workerInfo.k3s_server_url
    $detectedAt = $workerInfo.detected_at
    
    Write-Info "Worker conversion baslatiliyor..."
    Write-Info "  Yeni lider: $newLeaderId"
    Write-Info "  Lider IP: $newLeaderIP"
    Write-Info "  Tespit zamani: $detectedAt"
    Write-Info "  Isletim Sistemi: $(if ($runningOnWindows) { 'Windows' } elseif ($runningOnMacOS) { 'macOS' } else { 'Linux' })"
    
} catch {
    Write-Error "Worker flag file okunamadi: $_"
    exit 1
}

if ($runningOnWindows) {
    # Windows: Docker Desktop Kubernetes kullanilir (worker join desteklenmez)
    Write-Info "Windows tespit edildi - Docker Desktop Kubernetes kullaniliyor"
    Write-Warn "Docker Desktop Kubernetes tek node cluster'dir ve worker join desteklemez"
    Write-Info "Eski lider makinedeki servisler durdurulacak..."
    
    # Stop Docker Compose services if running
    try {
        $projectDir = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $composeFile = Join-Path $projectDir "docker-compose.yml"
        
        if (Test-Path $composeFile) {
            Write-Info "Docker Compose servisleri durduruluyor..."
            docker compose -f $composeFile down 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Docker Compose servisleri durduruldu"
            }
        }
    } catch {
        Write-Warn "Docker Compose servisleri durdurulamadi: $_"
    }
    
    # Stop Kubernetes workloads (optional - Docker Desktop Kubernetes will continue running)
    try {
        if (Get-Command kubectl -ErrorAction SilentlyContinue) {
            Write-Info "Kubernetes namespace'lerindeki workload'lar kontrol ediliyor..."
            $namespaces = kubectl get namespaces -o jsonpath='{.items[*].metadata.name}' 2>&1
            if ($LASTEXITCODE -eq 0 -and $namespaces) {
                foreach ($ns in $namespaces.Split(' ')) {
                    if ($ns -and $ns -ne "kube-system" -and $ns -ne "kube-public" -and $ns -ne "kube-node-lease") {
                        Write-Info "Namespace '$ns' temizleniyor..."
                        kubectl delete all --all -n $ns --timeout=30s 2>&1 | Out-Null
                    }
                }
            }
        }
    } catch {
        Write-Warn "Kubernetes workload'lari temizlenemedi: $_"
    }
    
    Write-Warn "Windows'ta Docker Desktop Kubernetes worker join desteklemez"
    Write-Info "Bu makine artik lider degil. Servisler durduruldu."
    Write-Info "Yeni lider makine ($newLeaderId) cluster'i yonetiyor."
    Write-Info ""
    Write-Info "Not: Docker Desktop Kubernetes bu makinede calismaya devam edebilir,"
    Write-Info "     ancak production workload'lari yeni lider makinede calisiyor."
    
} elseif ($runningOnLinux -or $runningOnMacOS) {
    # Linux/Mac: k3s agent kurulur
    Write-Info "$(if ($runningOnMacOS) { 'macOS' } else { 'Linux' }) tespit edildi - k3s kullaniliyor"
    
    # Check if k3s token and server URL are available
    if ([string]::IsNullOrWhiteSpace($k3sToken) -or [string]::IsNullOrWhiteSpace($k3sServerUrl)) {
        Write-Error "k3s_token veya k3s_server_url bulunamadi. Worker join yapilamiyor."
        Write-Info "Manuel olarak worker moduna gecmek icin setup script'ini 'prod-worker' modu ile calistirin."
        exit 1
    }
    
    # Check if k3s server is running (need to stop it first)
    try {
        if ($runningOnLinux) {
            $null = systemctl is-active k3s 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Info "k3s server durduruluyor..."
                $null = sudo systemctl stop k3s 2>&1
                Write-Success "k3s server durduruldu"
            }
        } elseif ($runningOnMacOS) {
            # macOS: Check if k3s is running via launchd or as process
            $k3sProcess = Get-Process -Name k3s -ErrorAction SilentlyContinue
            if ($k3sProcess) {
                Write-Info "k3s server durduruluyor..."
                # Try to stop via launchctl or kill process
                $null = launchctl unload ~/Library/LaunchAgents/k3s.plist 2>&1
                $null = pkill -f k3s 2>&1
                Write-Success "k3s server durduruldu"
            }
        }
    } catch {
        Write-Warn "k3s server durdurulamadi (zaten durmus olabilir): $_"
    }
    
    # Install k3s agent
    Write-Info "k3s agent kuruluyor..."
    try {
        $installCmd = "curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC=`"agent --token $k3sToken --server $k3sServerUrl`" sh -"
        
        if ($runningOnLinux) {
            $output = bash -c $installCmd 2>&1 | Out-String
        } else {
            # macOS
            $output = sh -c $installCmd 2>&1 | Out-String
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Success "k3s agent kuruldu ve cluster'a baglandi"
            
            # Wait a bit for agent to stabilize
            Start-Sleep -Seconds 5
            
            # Verify connection
            Write-Info "Cluster baglantisi dogrulaniyor..."
            $verifyCmd = "sudo kubectl get nodes 2>&1"
            
            if ($runningOnLinux) {
                $null = bash -c $verifyCmd 2>&1 | Out-String
            } else {
                $null = sh -c $verifyCmd 2>&1 | Out-String
            }
            
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Cluster baglantisi basarili!"
                Write-Info "Bu makine artik worker node olarak calisiyor"
            } else {
                Write-Warn "Cluster baglantisi dogrulanamadi, ancak agent kuruldu"
            }
        } else {
            Write-Error "k3s agent kurulumu basarisiz: $output"
            exit 1
        }
    } catch {
        Write-Error "k3s agent kurulumu sirasinda hata: $_"
        exit 1
    }
} else {
    Write-Error "Desteklenmeyen isletim sistemi"
    exit 1
}

# Remove flag file after successful conversion
if (Test-Path $WorkerFlagFile) {
    Remove-Item $WorkerFlagFile -Force -ErrorAction SilentlyContinue
    Write-Info "Worker flag dosyasi temizlendi"
}

Write-Success "Worker conversion islemi tamamlandi"

