$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  FinansAsistan - Baslatma Menusu (Windows)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1) Production (Prod)" -ForegroundColor Yellow
Write-Host "2) Development (Dev)" -ForegroundColor Yellow
Write-Host ""
$envChoice = Read-Host "Ortam seciniz [1-2] (varsayilan: 1)"
$envChoice = if ([string]::IsNullOrWhiteSpace($envChoice)) { "1" } else { $envChoice }

if ($envChoice -ne "1" -and $envChoice -ne "2") {
    Write-Host "[ERROR] Gecersiz secim, cikiliyor." -ForegroundColor Red
    exit 1
}

$envFile = Join-Path $scriptDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
        }
    }
}

if ($envChoice -eq "1") {
    $env:ENVIRONMENT = "production"
    $env:MODE = "production"
} else {
    $env:ENVIRONMENT = "development"
    $env:MODE = "development"
}

$modeAction = "prod-cp-a"
$script:forceTakeover = $false

if ($envChoice -eq "1") {
    Write-Host ""
    Write-Host "  [1] Control-plane islemleri" -ForegroundColor White
    Write-Host "  [2] Mevcut kumeye worker olarak katil" -ForegroundColor White
    Write-Host ""
    $prodChoice = Read-Host "Seciminiz [1-2] (varsayilan: 1)"
    $prodChoice = if ([string]::IsNullOrWhiteSpace($prodChoice)) { "1" } else { $prodChoice }
    
    if ($prodChoice -eq "2") {
        $modeAction = "prod-worker"
        Write-Host "[INFO] Worker join secildi" -ForegroundColor Green
    } else {
        $modeAction = "prod-cp-a"
    }
} else {
    $modeAction = "dev"
}

$setupScript = Join-Path $scriptDir "..\scripts\setup-windows-docker.ps1"
if ($script:forceTakeover) {
    & $setupScript -ModeAction $modeAction -ForceTakeover
} else {
    & $setupScript -ModeAction $modeAction
}
