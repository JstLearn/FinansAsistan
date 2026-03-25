# ════════════════════════════════════════════════════════════
# FinansAsistan - Watch Update Trigger from S3 (PowerShell)
# S3'teki update-trigger.json dosyasını izler ve anında güncelleme yapar
# ════════════════════════════════════════════════════════════

param(
    [string]$S3Bucket = $env:S3_BUCKET,
    [string]$AWSRegion = $env:AWS_REGION,
    [int]$CheckInterval = 10
)

$ErrorActionPreference = "Continue"

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $(([DateTime]::UtcNow).ToString('yyyy-MM-dd HH:mm:ss')) UTC - $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $(([DateTime]::UtcNow).ToString('yyyy-MM-dd HH:mm:ss')) UTC - $Message" -ForegroundColor Green
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] $(([DateTime]::UtcNow).ToString('yyyy-MM-dd HH:mm:ss')) UTC - $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $(([DateTime]::UtcNow).ToString('yyyy-MM-dd HH:mm:ss')) UTC - $Message" -ForegroundColor Red
}

# Script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$AutoUpdateScript = Join-Path $ScriptDir "auto-update-from-s3.sh"
$TriggerFile = Join-Path $ProjectDir ".last-trigger-commit"

# Check AWS CLI
if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Error "AWS CLI not found. Please install AWS CLI first."
    exit 1
}

# Check AWS credentials
try {
    aws sts get-caller-identity 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Error "AWS credentials not found or invalid!"
        exit 1
    }
} catch {
    Write-Error "AWS credentials not found or invalid!"
    exit 1
}

if (-not $S3Bucket) {
    $S3Bucket = "finans-asistan-backups"
}
if (-not $AWSRegion) {
    $AWSRegion = "eu-central-1"
}

$TriggerKey = "update-trigger.json"

Write-Info "Starting update trigger watcher..."
Write-Info "S3 Bucket: $S3Bucket"
Write-Info "Trigger Key: $TriggerKey"
Write-Info "Check Interval: ${CheckInterval}s"

# Read last processed commit
$LastCommit = ""
if (Test-Path $TriggerFile) {
    $LastCommit = Get-Content $TriggerFile -ErrorAction SilentlyContinue
}

# Main loop
while ($true) {
    try {
        # Download trigger file
        $TempTrigger = [System.IO.Path]::GetTempFileName()
        $S3Path = "s3://${S3Bucket}/${TriggerKey}"
        
        $downloadOutput = aws s3 cp $S3Path $TempTrigger 2>&1
        if ($LASTEXITCODE -eq 0) {
            # Parse trigger file
            $TriggerContent = Get-Content $TempTrigger -Raw | ConvertFrom-Json
            
            $TriggerCommit = $TriggerContent.commit
            $TriggerTimestamp = $TriggerContent.timestamp
            $Triggered = $TriggerContent.triggered
            
            # Check if trigger is set and commit is different
            if ($Triggered -eq $true -and $TriggerCommit -and $TriggerCommit -ne $LastCommit) {
                Write-Info "Update trigger detected!"
                Write-Info "  New commit: $($TriggerCommit.Substring(0, [Math]::Min(7, $TriggerCommit.Length)))"
                Write-Info "  Timestamp: $TriggerTimestamp"
                Write-Info "  Last processed: $(if ($LastCommit) { $LastCommit.Substring(0, [Math]::Min(7, $LastCommit.Length)) } else { 'none' })"
                
                # Run auto-update script
                if (Test-Path $AutoUpdateScript) {
                    Write-Info "Running auto-update script..."
                    
                    # For Windows, we need to use WSL or Git Bash
                    # Ensure production mode is used (unset USE_DEV_MODE)
                    # Convert Windows path to WSL path if needed
                    $updateOutput = $null
                    if (Get-Command wsl -ErrorAction SilentlyContinue) {
                        # Convert Windows path to WSL path
                        $wslPath = $AutoUpdateScript -replace '^([A-Z]):', '/mnt/$1' -replace '\\', '/'
                        $wslPath = $wslPath.ToLower()
                        # Unset USE_DEV_MODE to ensure production compose file is used
                        $updateOutput = wsl bash -c "unset USE_DEV_MODE; cd '$ProjectDir' && bash '$wslPath'" 2>&1
                    } elseif (Get-Command bash -ErrorAction SilentlyContinue) {
                        # Unset USE_DEV_MODE to ensure production compose file is used
                        # Change to project directory before running script
                        $updateOutput = bash -c "unset USE_DEV_MODE; cd '$ProjectDir' && bash '$AutoUpdateScript'" 2>&1
                    } else {
                        Write-Error "Neither WSL nor bash found. Cannot run auto-update script."
                        Remove-Item $TempTrigger -ErrorAction SilentlyContinue
                        Start-Sleep -Seconds $CheckInterval
                        continue
                    }
                    
                    # Show output for debugging
                    if ($updateOutput) {
                        $updateOutput | ForEach-Object {
                            if ($_ -match "ERROR|error|Error|FAILED|Failed|failed") {
                                Write-Host "  $_" -ForegroundColor Red
                            } elseif ($_ -match "SUCCESS|Success|success|completed|Completed") {
                                Write-Host "  $_" -ForegroundColor Green
                            } else {
                                Write-Host "  $_" -ForegroundColor Gray
                            }
                        }
                    }
                    
                    if ($LASTEXITCODE -eq 0) {
                        Write-Success "Update completed successfully!"
                        # Save processed commit
                        $TriggerCommit | Out-File $TriggerFile -Encoding UTF8 -NoNewline
                        $LastCommit = $TriggerCommit
                    } else {
                        Write-Error "Update failed with exit code: $LASTEXITCODE"
                    }
                } else {
                    Write-Error "Auto-update script not found: $AutoUpdateScript"
                }
            }
            
            Remove-Item $TempTrigger -ErrorAction SilentlyContinue
        } else {
            # File doesn't exist or download failed - this is normal if no update has been pushed
            # Only log if it's an actual error (not just file not found)
            if ($downloadOutput -match "error|Error|ERROR|failed|Failed|FAILED") {
                Write-Warn "Error downloading trigger file: $downloadOutput"
            }
        }
    } catch {
        Write-Warn "Error checking trigger: $_"
    }
    
    # Wait before next check
    Start-Sleep -Seconds $CheckInterval
}

