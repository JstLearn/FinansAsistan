# FinansAsistan - One-Line Windows Installer
# GitHub'dan script'i indirir, tüm bağımlılıkları kurar ve çalıştırır

param(
    [Parameter(Mandatory=$true)]
    [string]$GithubToken,
    [Parameter(Mandatory=$false)]
    [string]$AwsToken,
    [Parameter(Mandatory=$false)]
    [string]$AwsProfile = "default",
    [Parameter(Mandatory=$false)]
    [string]$S3Bucket
)

$ErrorActionPreference = "Stop"

# Normalize GitHub token input
$GithubToken = $GithubToken -replace '^GITHUB_ACCESS_TOKEN\s*=\s*', ''
$GithubToken = $GithubToken -replace '^token\s+', ''
$GithubToken = $GithubToken.Trim()

if ([string]::IsNullOrWhiteSpace($GithubToken)) {
    Write-LogError "GitHub token is required"
    Write-Host ""
    exit 1
}

# Helper function to flush console output
function Flush-Output {
    [Console]::Out.Flush()
}

# Progress bar helper
function Show-Progress {
    param(
        [int]$PercentComplete,
        [string]$Activity,
        [string]$Status,
        [string]$CurrentOperation
    )
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete -CurrentOperation $CurrentOperation
}

# Improved logging functions with better formatting
function Write-LogInfo {
    param([string]$Message)
    $timestamp = ([DateTime]::UtcNow).ToString("HH:mm:ss")
    Write-Host "[$timestamp UTC] [INFO] $Message" -ForegroundColor Blue
    [Console]::Out.Flush()
}

function Write-LogSuccess {
    param([string]$Message)
    $timestamp = ([DateTime]::UtcNow).ToString("HH:mm:ss")
    Write-Host "[$timestamp UTC] [SUCCESS] $Message" -ForegroundColor Green
    [Console]::Out.Flush()
}

function Write-LogWarn {
    param([string]$Message)
    $timestamp = ([DateTime]::UtcNow).ToString("HH:mm:ss")
    Write-Host "[$timestamp UTC] [WARN] $Message" -ForegroundColor Yellow
    [Console]::Out.Flush()
}

function Write-LogError {
    param([string]$Message)
    $timestamp = ([DateTime]::UtcNow).ToString("HH:mm:ss")
    Write-Host "[$timestamp UTC] [ERROR] $Message" -ForegroundColor Red
    [Console]::Out.Flush()
}

# Function to hydrate AWS credentials from base64 encoded JSON token
function Set-AwsCredentialsFromToken {
    param(
        [string]$Token,
        [string]$Profile
    )

    if ([string]::IsNullOrWhiteSpace($Token)) {
        return
    }

    $cleanToken = $Token.Trim()
    $cleanToken = $cleanToken -replace '^AWS_TOKEN\s*=\s*', ''
    $cleanToken = $cleanToken -replace '\s+', ''

    try {
        $decodedBytes = [System.Convert]::FromBase64String($cleanToken)
        $decodedJson = [System.Text.Encoding]::UTF8.GetString($decodedBytes)
        $awsCredentials = $decodedJson | ConvertFrom-Json

        if ([string]::IsNullOrWhiteSpace($awsCredentials.accessKeyId) -or [string]::IsNullOrWhiteSpace($awsCredentials.secretAccessKey)) {
            throw "AWS credential JSON must include accessKeyId and secretAccessKey"
        }

        $env:AWS_ACCESS_KEY_ID = $awsCredentials.accessKeyId
        $env:AWS_SECRET_ACCESS_KEY = $awsCredentials.secretAccessKey

        if (-not [string]::IsNullOrWhiteSpace($awsCredentials.sessionToken)) {
            $env:AWS_SESSION_TOKEN = $awsCredentials.sessionToken
        }

        if (-not [string]::IsNullOrWhiteSpace($awsCredentials.region)) {
            $env:AWS_DEFAULT_REGION = $awsCredentials.region
        }

        # Ensure USERPROFILE is set
        if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
            $env:USERPROFILE = [System.Environment]::GetFolderPath("UserProfile")
        }

        if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) {
            Write-LogError "Cannot determine user profile directory"
            exit 1
        }

        $awsDir = Join-Path $env:USERPROFILE ".aws"
        if ([string]::IsNullOrWhiteSpace($awsDir)) {
            Write-LogError "Failed to create AWS directory path"
            exit 1
        }

        if (-not (Test-Path $awsDir)) {
            New-Item -ItemType Directory -Path $awsDir -Force | Out-Null
        }

        $credentialsPath = Join-Path $awsDir "credentials"
        if ([string]::IsNullOrWhiteSpace($credentialsPath)) {
            Write-LogError "Failed to create credentials file path"
            exit 1
        }

        $profileLines = @(
            "[$Profile]"
            "aws_access_key_id=$($awsCredentials.accessKeyId)"
            "aws_secret_access_key=$($awsCredentials.secretAccessKey)"
        )

        if (-not [string]::IsNullOrWhiteSpace($awsCredentials.sessionToken)) {
            $profileLines += "aws_session_token=$($awsCredentials.sessionToken)"
        }

        if (-not [string]::IsNullOrWhiteSpace($awsCredentials.region)) {
            $profileLines += "region=$($awsCredentials.region)"
        }

        $profileLines += ""

        if (Test-Path $credentialsPath) {
            $existingContent = Get-Content $credentialsPath -Raw
            $regexPattern = "(?ms)^\[$Profile\].*?(?=^\[|\Z)"

            if ($existingContent -match $regexPattern) {
                $updatedContent = $existingContent -replace $regexPattern, ($profileLines -join "`n")
            } else {
                $updatedContent = $existingContent.TrimEnd() + "`n`n" + ($profileLines -join "`n")
            }

            Set-Content -Path $credentialsPath -Value $updatedContent -Encoding UTF8
        } else {
            Set-Content -Path $credentialsPath -Value ($profileLines -join "`n") -Encoding UTF8
        }

        Write-LogSuccess "AWS credentials injected from token"
    } catch {
        Write-LogError "Failed to parse AWS token: $_"
        Write-LogInfo "Expected a base64 encoded JSON with accessKeyId and secretAccessKey fields"
        exit 1
    }
}

if (-not [string]::IsNullOrWhiteSpace($AwsToken)) {
    Set-AwsCredentialsFromToken -Token $AwsToken -Profile $AwsProfile
}

if (-not [string]::IsNullOrWhiteSpace($S3Bucket)) {
    $env:S3_BUCKET = $S3Bucket
}

Write-Host ""
Write-Host "FinansAsistan - One-Line Installer"
Write-Host ""

# Function to check if command exists
function Test-Command {
    param([string]$Command)
    $null = Get-Command $Command -ErrorAction SilentlyContinue
    return $?
}

# Function to install Git
function Install-Git {
    Write-LogInfo "Installing Git..."
    
    # Try winget first
    if (Test-Command "winget") {
        Write-LogInfo "Using winget to install Git..."
        winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Git installed via winget"
            # Refresh PATH
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return $true
        }
    }
    
    # Try Chocolatey
    if (Test-Command "choco") {
        Write-LogInfo "Using Chocolatey to install Git..."
        choco install git -y --force
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Git installed via Chocolatey"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return $true
        }
    }
    
    Write-LogError "Failed to install Git automatically"
    Write-LogInfo "Please install Git manually from: https://git-scm.com/download/win"
    return $false
}

# Function to install Docker Desktop
function Install-DockerDesktop {
    Write-LogInfo "Installing Docker Desktop..."
    
    # Try winget first
    if (Test-Command "winget") {
        Write-LogInfo "Using winget to install Docker Desktop..."
        winget install --id Docker.DockerDesktop -e --source winget --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Docker Desktop installed via winget"
            Write-LogInfo "Please start Docker Desktop manually and wait for it to fully start"
            Write-LogInfo "Then restart PowerShell and run the installer again"
            return $true
        }
    }
    
    # Try Chocolatey
    if (Test-Command "choco") {
        Write-LogInfo "Using Chocolatey to install Docker Desktop..."
        choco install docker-desktop -y --force
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "Docker Desktop installed via Chocolatey"
            Write-LogInfo "Please start Docker Desktop manually and wait for it to fully start"
            Write-LogInfo "Then restart PowerShell and run the installer again"
            return $true
        }
    }
    
    Write-LogError "Failed to install Docker Desktop automatically"
    Write-LogInfo "Please install Docker Desktop manually from: https://www.docker.com/products/docker-desktop"
    return $false
}

# Function to install AWS CLI
function Install-AWSCLI {
    Write-LogInfo "Installing AWS CLI..."
    
    # Try winget first
    if (Test-Command "winget") {
        Write-LogInfo "Using winget to install AWS CLI..."
        winget install --id Amazon.AWSCLI -e --source winget --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "AWS CLI installed via winget"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return $true
        }
    }
    
    # Try Chocolatey
    if (Test-Command "choco") {
        Write-LogInfo "Using Chocolatey to install AWS CLI..."
        choco install awscli -y --force
        if ($LASTEXITCODE -eq 0) {
            Write-LogSuccess "AWS CLI installed via Chocolatey"
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return $true
        }
    }
    
    Write-LogWarn "Failed to install AWS CLI automatically"
    Write-LogInfo "AWS CLI will be installed later if needed"
    return $false
}

# Function to install ArgoCD CLI
function Install-ArgoCDCLI {
    Write-LogInfo "Installing ArgoCD CLI..."
    
    # Check if already installed
    if (Test-Command "argocd") {
        try {
            $argocdVersion = argocd version --client 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "ArgoCD CLI already installed"
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
        Write-LogInfo "Fetching latest ArgoCD CLI version..."
        $releaseInfo = Invoke-RestMethod -Uri "https://api.github.com/repos/argoproj/argo-cd/releases/latest" -ErrorAction Stop
        $version = $releaseInfo.tag_name
        Write-LogInfo "Latest version: $version"
        
        # Download ArgoCD CLI
        $downloadUrl = "https://github.com/argoproj/argo-cd/releases/download/$version/argocd-windows-amd64.exe"
        $outputPath = Join-Path $installDir "argocd.exe"
        
        Write-LogInfo "Downloading ArgoCD CLI from GitHub..."
        Invoke-WebRequest -Uri $downloadUrl -OutFile $outputPath -ErrorAction Stop
        
        if (Test-Path $outputPath) {
            Write-LogSuccess "ArgoCD CLI downloaded successfully"
            
            # Add to PATH if not already there
            $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
            if ($userPath -notlike "*$installDir*") {
                [Environment]::SetEnvironmentVariable("Path", "$userPath;$installDir", "User")
                $env:Path += ";$installDir"
                Write-LogSuccess "ArgoCD CLI added to PATH"
            }
            
            # Verify installation
            if (Test-Command "argocd") {
                $argocdVersion = argocd version --client 2>&1 | Out-String
                Write-LogSuccess "ArgoCD CLI installed successfully"
                return $true
            }
        }
    } catch {
        Write-LogWarn "Failed to install ArgoCD CLI automatically: $_"
        Write-LogInfo "You can install ArgoCD CLI manually from: https://argo-cd.readthedocs.io/en/stable/cli_installation/"
        return $false
    }
    
    return $false
}

# Function to install WSL2
function Install-WSL2 {
    Write-LogInfo "Checking WSL2 installation..."
    
    # Check if WSL is available
    $wslAvailable = $false
    try {
        $wslCheck = wsl --list --quiet 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $wslAvailable = $true
        }
    } catch {
        $wslAvailable = $false
    }
    
    # Check if Linux distribution is installed
    $distroInstalled = $false
    if ($wslAvailable) {
        try {
            # Check with UTF-8 encoding - use --list (without --quiet) to get better output
            $OutputEncoding = [System.Text.Encoding]::UTF8
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            
            # First try --list (more reliable than --quiet)
            $distros = wsl --list 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -or $distros) {
                # Check for any Linux distribution (case-insensitive, various encodings)
                # Look for distribution names even if there are encoding issues
                if ($distros -match "Ubuntu|ubuntu|Debian|debian|SUSE|suse|Kali|kali|Alpine|alpine" -or
                    $distros -match "U.*b.*u.*n.*t.*u|D.*e.*b.*i.*a.*n") {
                    $distroInstalled = $true
                    Write-LogSuccess "WSL2 is installed with a Linux distribution"
                    
                    # Determine distribution name
                    $distroName = ""
                    if ($distros -match "Ubuntu|ubuntu|U.*b.*u.*n.*t.*u") {
                        $distroName = "Ubuntu"
                    } elseif ($distros -match "Debian|debian|D.*e.*b.*i.*a.*n") {
                        $distroName = "Debian"
                    }
                    
                    # If Ubuntu is found but stopped, try to launch it
                    if ($distroName -eq "Ubuntu" -and $distros -match "Stopped|stopped") {
                        Write-LogInfo "Ubuntu is installed but stopped. Attempting to start it..."
                        [Console]::Out.Flush()
                        try {
                            wsl -d Ubuntu -e bash -c "exit 0" 2>&1 | Out-Null
                            Start-Sleep -Seconds 3
                        } catch {
                            # Start failed, continue
                        }
                    }
                    
                    # Test bash to ensure it's working
                    Write-LogInfo "Verifying bash is available..."
                    [Console]::Out.Flush()
                    $bashAvailable = $false
                    
                    # Try default bash first
                    try {
                        $bashTest = wsl bash -c "echo test" 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            $bashAvailable = $true
                            Write-LogSuccess "bash is available via 'wsl bash'"
                            [Console]::Out.Flush()
                        }
                    } catch {
                        # Default bash failed
                    }
                    
                    # If default failed and we have Ubuntu, try explicit
                    if (-not $bashAvailable -and $distroName -eq "Ubuntu") {
                        try {
                            $bashTestUbuntu = wsl -d Ubuntu bash -c "echo test" 2>&1 | Out-Null
                            if ($LASTEXITCODE -eq 0) {
                                $bashAvailable = $true
                                Write-LogSuccess "bash is available via 'wsl -d Ubuntu bash'"
                                [Console]::Out.Flush()
                            }
                        } catch {
                            # Ubuntu bash failed
                        }
                    }
                    
                    # If bash is available, return true
                    if ($bashAvailable) {
                        return $true
                    } else {
                        Write-LogWarn "Linux distribution found but bash test failed. It may need manual initialization."
                        Write-LogInfo "Try running: wsl -d Ubuntu (first time setup may be required)"
                        [Console]::Out.Flush()
                        # Still return true if distribution exists, bash setup can be done later
                        return $true
                    }
                }
            }
            
            # Fallback: try --list --quiet if --list failed
            if (-not $distroInstalled) {
                $distrosQuiet = wsl --list --quiet 2>&1 | Out-String
                if ($LASTEXITCODE -eq 0 -or $distrosQuiet) {
                    if ($distrosQuiet -match "Ubuntu|ubuntu|Debian|debian|SUSE|suse|Kali|kali|Alpine|alpine" -or
                        $distrosQuiet -match "U.*b.*u.*n.*t.*u") {
                        $distroInstalled = $true
                        Write-LogSuccess "WSL2 is installed with a Linux distribution"
                        return $true
                    }
                }
            }
        } catch {
            # Could not check distributions
        }
        
        # Also try direct bash test (in case distribution exists but wasn't detected)
        try {
            # Try with default distribution first
            $bashTest = wsl bash -c "echo test" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $distroInstalled = $true
                Write-LogSuccess "WSL2 with bash detected (distribution may be installed)"
                return $true
            }
            
            # If default failed, try with Ubuntu explicitly
            $bashTestUbuntu = wsl -d Ubuntu bash -c "echo test" 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                $distroInstalled = $true
                Write-LogSuccess "WSL2 with Ubuntu and bash detected"
                return $true
            }
        } catch {
            # Bash test failed
        }
    }
    
    # WSL2 installed but no Linux distribution - install default (Ubuntu)
    if ($wslAvailable -and -not $distroInstalled) {
        Write-Host ""
        [Console]::Out.Flush()
        Write-LogWarn "WSL2 framework is installed but no Linux distribution found"
        Write-Host "  Why Ubuntu is needed:" -ForegroundColor Cyan
        [Console]::Out.Flush()
        Write-Host "    • WSL2 is just a framework (like a virtual machine)" -ForegroundColor Gray
        [Console]::Out.Flush()
        Write-Host "    • k3s (Kubernetes) requires a Linux OS to run" -ForegroundColor Gray
        [Console]::Out.Flush()
        Write-Host "    • bootstrap.sh installs k3s using 'curl | sh' (Linux only)" -ForegroundColor Gray
        [Console]::Out.Flush()
        Write-Host "    • Without Linux distribution, 'wsl bash' command won't work" -ForegroundColor Gray
        [Console]::Out.Flush()
        Write-Host ""
        [Console]::Out.Flush()
        
        Write-LogInfo "Installing Ubuntu Linux distribution..."
        Write-Host "  Estimated time: 2-5 minutes" -ForegroundColor Yellow
        [Console]::Out.Flush()
        Write-Host "  Please wait, this is a one-time setup..." -ForegroundColor Yellow
        [Console]::Out.Flush()
        Write-Host ""
        [Console]::Out.Flush()
        
        try {
            # Show progress
            Show-Progress -PercentComplete 10 -Activity "Installing Ubuntu" -Status "Starting installation..." -CurrentOperation "Downloading Ubuntu..."
            
            # Install Ubuntu distribution (this may require user interaction or take time)
            # Use UTF-8 encoding for proper Turkish character handling
            $OutputEncoding = [System.Text.Encoding]::UTF8
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            
            # Run installation directly (not in a job) to better capture output
            Show-Progress -PercentComplete 20 -Activity "Installing Ubuntu" -Status "Starting installation..." -CurrentOperation "This may take 2-5 minutes..."
            
            # Run installation with proper encoding
            $installOutput = ""
            try {
                $process = Start-Process -FilePath "wsl.exe" -ArgumentList "--install", "-d", "Ubuntu", "--no-launch" -NoNewWindow -Wait -PassThru -RedirectStandardOutput "$env:TEMP\wsl-install-stdout.txt" -RedirectStandardError "$env:TEMP\wsl-install-stderr.txt"
                
                # Read output files with UTF-8 encoding
                if (Test-Path "$env:TEMP\wsl-install-stdout.txt") {
                    $installOutput += [System.IO.File]::ReadAllText("$env:TEMP\wsl-install-stdout.txt", [System.Text.Encoding]::UTF8)
                }
                if (Test-Path "$env:TEMP\wsl-install-stderr.txt") {
                    $stderr = [System.IO.File]::ReadAllText("$env:TEMP\wsl-install-stderr.txt", [System.Text.Encoding]::UTF8)
                    # stderr often contains success messages in WSL
                    if ($stderr) {
                        $installOutput += "`n" + $stderr
                    }
                }
                
                # Cleanup temp files
                Remove-Item "$env:TEMP\wsl-install-stdout.txt" -ErrorAction SilentlyContinue
                Remove-Item "$env:TEMP\wsl-install-stderr.txt" -ErrorAction SilentlyContinue
            } catch {
                $installOutput = "Error: $_"
            }
            
            Show-Progress -PercentComplete 90 -Activity "Installing Ubuntu" -Status "Installation complete!" -CurrentOperation "Verifying installation..."
            Start-Sleep -Seconds 3
            Write-Progress -Activity "Installing Ubuntu" -Completed
            Flush-Output
            
            # Check if Ubuntu is now installed (multiple attempts with retry logic)
            $maxRetries = 5
            $retryDelay = 3
            $ubuntuInstalled = $false
            
            for ($retry = 1; $retry -le $maxRetries; $retry++) {
                Start-Sleep -Seconds $retryDelay
                
                try {
                    # Check WSL list with UTF-8 encoding
                    $distrosOutput = wsl --list --quiet 2>&1 | Out-String
                    
                    # Check for Ubuntu in various encodings and languages
                    # Turkish: "Ubuntu", "yüklendi", "başarıyla", "ba_lat1labilir"
                    # English: "Ubuntu", "installed", "successfully"
                    if ($distrosOutput -match "Ubuntu" -or 
                        $distrosOutput -match "ubuntu" -or
                        $installOutput -match "Ubuntu" -or
                        $installOutput -match "y[³3]klendi" -or
                        $installOutput -match "ba[_\s]*ar[1ı]yla" -or
                        $installOutput -match "ba[_\s]*lat[1ı]labilir" -or
                        $installOutput -match "installed" -or
                        $installOutput -match "successfully") {
                        $ubuntuInstalled = $true
                        break
                    }
                    
                    # Also try direct wsl bash test
                    try {
                        $bashTest = wsl bash --version 2>&1 | Out-String
                        if ($bashTest -match "bash" -or $LASTEXITCODE -eq 0) {
                            $ubuntuInstalled = $true
                            break
                        }
                    } catch {
                        # Bash test failed, continue
                    }
                } catch {
                    # List check failed, continue
                }
            }
            
            # Check if Ubuntu already exists (from error message)
            # Check multiple encodings and patterns for "already exists" message
            $alreadyExists = $false
            if ($installOutput -match "ERROR_ALREADY_EXISTS|already exists|zaten var|da[1ı]t[1ı]m.*zaten|distribution.*already") {
                $alreadyExists = $true
            } else {
                # Also check for Turkish characters in various encodings
                $installOutputLower = $installOutput.ToLower()
                if ($installOutputLower -match "zaten|already|exists|hata.*kod|error.*code") {
                    $alreadyExists = $true
                }
            }
            
            if ($alreadyExists) {
                Write-Host ""
                [Console]::Out.Flush()
                Write-LogInfo "Ubuntu distribution already exists. Verifying..."
                [Console]::Out.Flush()
                Start-Sleep -Seconds 3
                
                # Verify it's actually working - try multiple methods
                $bashWorking = $false
                try {
                    # Method 1: Direct bash test
                    $bashTest = wsl bash -c "echo test" 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        $bashWorking = $true
                    }
                } catch {
                    # Method 1 failed, try method 2
                    try {
                        # Method 2: Check wsl list
                        $distrosList = wsl --list --quiet 2>&1 | Out-String
                        if ($distrosList -match "Ubuntu|ubuntu") {
                            # Method 3: Try bash version
                            $bashVersion = wsl bash --version 2>&1 | Out-Null
                            if ($LASTEXITCODE -eq 0) {
                                $bashWorking = $true
                            }
                        }
                    } catch {
                        # All methods failed
                    }
                }
                
                if ($bashWorking) {
                    Write-LogSuccess "Ubuntu distribution found and working"
                    Write-LogInfo "WSL2 setup is complete. bash is now available via 'wsl bash'"
                    Write-Host ""
                    [Console]::Out.Flush()
                    return $true
                } else {
                    Write-LogWarn "Ubuntu exists but bash test failed. It may need to be launched first."
                    Write-LogInfo "Trying to launch Ubuntu to initialize it..."
                    [Console]::Out.Flush()
                    
                    # Try to launch Ubuntu (non-interactive) to initialize it
                    try {
                        wsl -d Ubuntu -e bash -c "exit 0" 2>&1 | Out-Null
                        Start-Sleep -Seconds 2
                        
                        # Test bash again
                        $bashTest2 = wsl bash -c "echo test" 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-LogSuccess "Ubuntu initialized and working"
                            Write-LogInfo "WSL2 setup is complete. bash is now available via 'wsl bash'"
                            Write-Host ""
                            [Console]::Out.Flush()
                            return $true
                        }
                    } catch {
                        # Launch failed, continue
                    }
                }
            }
            
            if ($ubuntuInstalled) {
                Write-Host ""
                Write-LogSuccess "Ubuntu distribution installed successfully"
                Write-LogInfo "WSL2 setup is complete. bash is now available via 'wsl bash'"
                Write-Host ""
                return $true
            } else {
                Write-Host ""
                [Console]::Out.Flush()
                Write-LogWarn "Ubuntu installation verification failed"
                Write-Host "  Installation output (first 500 chars): $($installOutput.Substring(0, [Math]::Min(500, $installOutput.Length)))" -ForegroundColor Gray
                [Console]::Out.Flush()
                Write-LogInfo "The installation may have completed but verification failed."
                Write-LogInfo "Please verify manually: wsl --list"
                Write-LogInfo "If Ubuntu is listed, you can proceed. Otherwise, run: wsl --install -d Ubuntu"
                Write-Host ""
                [Console]::Out.Flush()
                
                # Check if Ubuntu already exists (from error message) - return true if it does
                # Check multiple encodings and patterns
                $alreadyExists = $false
                if ($installOutput -match "ERROR_ALREADY_EXISTS|already exists|zaten var|da[1ı]t[1ı]m.*zaten|distribution.*already") {
                    $alreadyExists = $true
                } else {
                    $installOutputLower = $installOutput.ToLower()
                    if ($installOutputLower -match "zaten|already|exists|hata.*kod|error.*code") {
                        $alreadyExists = $true
                    }
                }
                
                if ($alreadyExists) {
                    Write-LogInfo "Ubuntu appears to already be installed. Proceeding..."
                    [Console]::Out.Flush()
                    # Try to verify it works before returning true
                    try {
                        $bashTest = wsl bash -c "echo test" 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-LogSuccess "Ubuntu is working. bash available via 'wsl bash'"
                            [Console]::Out.Flush()
                        }
                    } catch {
                        # Bash test failed, but proceed anyway since it exists
                    }
                    return $true
                }
                
                # Still return true if output suggests success
                if ($installOutput -match "y[³3]klendi|ba[_\s]*ar[1ı]yla|installed|successfully") {
                    Write-LogInfo "Installation output suggests success. Proceeding..."
                    return $true
                }
                return $false
            }
        } catch {
            Write-Progress -Activity "Installing Ubuntu" -Completed
            Write-Host ""
            Write-LogWarn "Failed to install Linux distribution automatically: $_"
            Write-LogInfo "Please install a Linux distribution manually: wsl --install -d Ubuntu"
            Write-Host ""
            return $false
        }
    }
    
    # WSL2 not installed - try to install
    if (-not $wslAvailable) {
        Write-LogInfo "WSL2 not found. Attempting installation..."
        
        # Try winget first
        if (Test-Command "winget") {
            Write-LogInfo "Using winget to install WSL..."
            Show-Progress -PercentComplete 50 -Activity "Installing WSL2" -Status "Installing WSL2..." -CurrentOperation "Please wait..."
            winget install --id Microsoft.WindowsSubsystemLinux -e --source winget --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
            Write-Progress -Activity "Installing WSL2" -Completed
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "WSL installed via winget"
                Write-LogInfo "Please run 'wsl --install' as Administrator and restart your computer"
                return $true
            }
        }
        
        # Try direct wsl install (requires admin)
        try {
            Write-LogInfo "Attempting to install WSL2 via wsl --install..."
            Show-Progress -PercentComplete 50 -Activity "Installing WSL2" -Status "Installing WSL2..." -CurrentOperation "This may require Administrator privileges..."
            Start-Process powershell -ArgumentList "-Command", "wsl --install" -Verb RunAs -Wait -ErrorAction SilentlyContinue
            Write-Progress -Activity "Installing WSL2" -Completed
            Write-LogSuccess "WSL2 installation initiated"
            Write-LogInfo "Please restart your computer after WSL2 installation completes"
            return $true
        } catch {
            Write-Progress -Activity "Installing WSL2" -Completed
            Write-LogWarn "Failed to install WSL2 automatically. Requires Administrator privileges."
            Write-LogInfo "Please install WSL2 manually: wsl --install (run as Administrator)"
            return $false
        }
    }
    
    return $false
}

# Function to check if bash is available (via Git Bash or WSL)
function Test-Bash {
    # First try direct bash (Git Bash)
    try {
        $bashVersion = bash --version 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            return $true
        }
    } catch {
        # bash not found directly
    }
    
    # If bash not found directly, try WSL2
    try {
        # Check if WSL is available
        $OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        
        # Use --list (without --quiet) for better detection
        $distrosList = wsl --list 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -or $distrosList) {
            # Check if any Linux distribution is installed
            $hasDistro = $false
            $distroName = ""
            
            if ($distrosList -match "Ubuntu|ubuntu|U.*b.*u.*n.*t.*u") {
                $hasDistro = $true
                $distroName = "Ubuntu"
            } elseif ($distrosList -match "Debian|debian|D.*e.*b.*i.*a.*n") {
                $hasDistro = $true
                $distroName = "Debian"
            } elseif ($distrosList -match "SUSE|suse") {
                $hasDistro = $true
                $distroName = "SUSE"
            } elseif ($distrosList -match "Kali|kali") {
                $hasDistro = $true
                $distroName = "Kali"
            } elseif ($distrosList -match "Alpine|alpine") {
                $hasDistro = $true
                $distroName = "Alpine"
            }
            
            if ($hasDistro) {
                # Check if distribution is stopped and try to start it
                if ($distrosList -match "Stopped|stopped") {
                    Write-LogInfo "Linux distribution ($distroName) is stopped. Attempting to start it..."
                    try {
                        if ($distroName -eq "Ubuntu") {
                            wsl -d Ubuntu -e bash -c "exit 0" 2>&1 | Out-Null
                        } else {
                            wsl -d $distroName -e bash -c "exit 0" 2>&1 | Out-Null
                        }
                        Start-Sleep -Seconds 2
                    } catch {
                        # Start failed, continue with test
                    }
                }
                
                # Test with a simple command that should work
                $wslTest = wsl bash -c "echo test" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-LogInfo "WSL2 detected - bash available via 'wsl bash'"
                    return $true
                } else {
                    # Try with explicit distribution name
                    if ($distroName -eq "Ubuntu") {
                        $wslTestUbuntu = wsl -d Ubuntu bash -c "echo test" 2>&1 | Out-Null
                        if ($LASTEXITCODE -eq 0) {
                            Write-LogInfo "WSL2 Ubuntu detected - bash available via 'wsl -d Ubuntu bash'"
                            return $true
                        }
                    }
                    
                    # Try bash --version as fallback
                    $wslBash = wsl bash --version 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-LogInfo "WSL2 detected - bash available via 'wsl bash'"
                        return $true
                    }
                }
            }
        }
        
        # Fallback: try --list --quiet if --list failed
        $distrosListQuiet = wsl --list --quiet 2>&1 | Out-String
        if ($LASTEXITCODE -eq 0 -or $distrosListQuiet) {
            if ($distrosListQuiet -match "Ubuntu|ubuntu|Debian|debian|SUSE|suse|Kali|kali|Alpine|alpine" -or
                $distrosListQuiet -match "U.*b.*u.*n.*t.*u") {
                # Distribution exists, try bash test
                $wslTest = wsl bash -c "echo test" 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) {
                    Write-LogInfo "WSL2 detected - bash available via 'wsl bash'"
                    return $true
                } else {
                    # Try Ubuntu explicitly
                    $wslTestUbuntu = wsl -d Ubuntu bash -c "echo test" 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-LogInfo "WSL2 Ubuntu detected - bash available via 'wsl -d Ubuntu bash'"
                        return $true
                    }
                }
            }
        }
    } catch {
        # WSL not available
    }
    
    return $false
}

# 1. Check and install Git
Write-LogInfo "Checking Git installation..."
if (-not (Test-Command "git")) {
    Write-LogWarn "Git not found. Installing..."
    Show-Progress -PercentComplete 50 -Activity "Installing Git" -Status "Installing Git..." -CurrentOperation "Please wait..."
    if (-not (Install-Git)) {
        Write-Progress -Activity "Installing Git" -Completed
        Write-LogError "Git installation failed. Cannot continue."
        Write-Host ""
        exit 1
    }
    Write-Progress -Activity "Installing Git" -Completed
    # Wait a moment for PATH to update
    Start-Sleep -Seconds 2
    # Refresh PATH again
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
} else {
    $gitVersion = git --version
    Write-LogSuccess "Git found: $gitVersion"
}

# 2. Check and install Docker Desktop
Write-LogInfo "Checking Docker Desktop installation..."
if (-not (Test-Command "docker")) {
    Write-LogWarn "Docker Desktop not found. Installing..."
    Show-Progress -PercentComplete 50 -Activity "Installing Docker Desktop" -Status "Installing Docker Desktop..." -CurrentOperation "This may take 5-10 minutes..."
    if (Install-DockerDesktop) {
        Write-Progress -Activity "Installing Docker Desktop" -Completed
        Write-Host ""
        Write-LogInfo "Docker Desktop installation started. Please:"
        Write-Host "  1. Start Docker Desktop" -ForegroundColor White
        [Console]::Out.Flush()
        Write-Host "  2. Wait for it to fully start" -ForegroundColor White
        [Console]::Out.Flush()
        Write-Host "  3. Restart PowerShell" -ForegroundColor White
        [Console]::Out.Flush()
        Write-Host "  4. Run the installer again" -ForegroundColor White
        [Console]::Out.Flush()
        Write-Host ""
        [Console]::Out.Flush()
        exit 0
    } else {
        Write-Progress -Activity "Installing Docker Desktop" -Completed
        Write-LogError "Docker Desktop installation failed. Cannot continue."
        Write-Host ""
        exit 1
    }
} else {
    $dockerVersion = docker --version
    Write-LogSuccess "Docker found: $dockerVersion"
    
    # Check if Docker is running
    Write-LogInfo "Checking if Docker is running..."
    try {
        docker ps 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-LogWarn "Docker Desktop is not running!"
            Write-LogInfo "Please start Docker Desktop and wait for it to fully start"
            Write-LogInfo "Then run the installer again"
            Write-Host ""
            exit 0
        }
        Write-LogSuccess "Docker is running"
    } catch {
        Write-LogWarn "Docker Desktop is not running!"
        Write-LogInfo "Please start Docker Desktop and wait for it to fully start"
        Write-LogInfo "Then run the installer again"
        Write-Host ""
        exit 0
    }
}

# 3. Check and install AWS CLI
Write-LogInfo "Checking AWS CLI installation..."
if (-not (Test-Command "aws")) {
    Write-LogWarn "AWS CLI not found. Installing..."
    Show-Progress -PercentComplete 50 -Activity "Installing AWS CLI" -Status "Installing AWS CLI..." -CurrentOperation "Please wait..."
    Install-AWSCLI | Out-Null
    Write-Progress -Activity "Installing AWS CLI" -Completed
    # Refresh PATH
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    Start-Sleep -Seconds 2
}

# Function to enable Docker Desktop Kubernetes
function Enable-DockerDesktopKubernetes {
    Write-LogInfo "Attempting to enable Docker Desktop Kubernetes automatically..."
    
    # Docker Desktop settings.json path
    $settingsPath = Join-Path $env:APPDATA "Docker\settings.json"
    
    if (-not (Test-Path $settingsPath)) {
        Write-LogWarn "Docker Desktop settings file not found: $settingsPath"
        Write-LogInfo "Docker Desktop may need to be opened at least once first"
        return $false
    }
    
    try {
        # Read settings file
        $settingsJson = Get-Content $settingsPath -Raw | ConvertFrom-Json
        
        # Check if Kubernetes is already enabled
        if ($settingsJson.kubernetes -and $settingsJson.kubernetes.enabled -eq $true) {
            Write-LogInfo "Kubernetes is already enabled in settings"
            return $true
        }
        
        # Enable Kubernetes in settings
        if (-not $settingsJson.kubernetes) {
            $settingsJson | Add-Member -MemberType NoteProperty -Name "kubernetes" -Value @{} -Force
        }
        $settingsJson.kubernetes | Add-Member -MemberType NoteProperty -Name "enabled" -Value $true -Force
        
        # Save settings file
        $settingsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $settingsPath -Encoding UTF8 -Force
        
        Write-LogSuccess "Kubernetes enabled in Docker Desktop settings"
        Write-LogInfo "Docker Desktop needs to restart for changes to take effect"
        
        # Try to restart Docker Desktop (if possible)
        Write-LogInfo "Attempting to restart Docker Desktop..."
        try {
            # Stop Docker Desktop process
            Get-Process "Docker Desktop" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            
            # Start Docker Desktop
            $dockerDesktopPath = "${env:ProgramFiles}\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $dockerDesktopPath) {
                Start-Process -FilePath $dockerDesktopPath -ErrorAction SilentlyContinue
                Write-LogInfo "Docker Desktop restart initiated. Waiting for Kubernetes to start..."
                [Console]::Out.Flush()
                
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
                        [Console]::Out.Flush()
                    }
                }
                
                if ($kubernetesReady) {
                    Write-LogSuccess "Docker Desktop Kubernetes is now enabled and running"
                    return $true
                } else {
                    Write-LogWarn "Kubernetes may take longer to start. Please wait and check manually."
                    Write-LogInfo "You can check status with: kubectl cluster-info"
                    return $false
                }
            } else {
                Write-LogWarn "Docker Desktop executable not found at: $dockerDesktopPath"
                Write-LogInfo "Please restart Docker Desktop manually for Kubernetes to be enabled"
                return $false
            }
        } catch {
            Write-LogWarn "Could not restart Docker Desktop automatically: $_"
            Write-LogInfo "Settings have been updated. Please restart Docker Desktop manually:"
            Write-Host "  1. Close Docker Desktop completely" -ForegroundColor White
            [Console]::Out.Flush()
            Write-Host "  2. Start Docker Desktop again" -ForegroundColor White
            [Console]::Out.Flush()
            Write-Host "  3. Wait for Kubernetes to start" -ForegroundColor White
            [Console]::Out.Flush()
            Write-Host "  4. Run this script again" -ForegroundColor White
            [Console]::Out.Flush()
            return $false
        }
    } catch {
        Write-LogWarn "Failed to enable Kubernetes automatically: $_"
        Write-LogInfo "Please enable Kubernetes manually in Docker Desktop Settings"
        return $false
    }
}

# 3.5. Check Docker Desktop Kubernetes (required for production)
if ($env:ENVIRONMENT -eq "production" -or $env:MODE -eq "production") {
    Write-Host ""
    Write-LogInfo "Production mode detected. Checking Docker Desktop Kubernetes..."
    Write-Host ""
    
    # Check kubectl
    $kubectlAvailable = $false
    if (Get-Command kubectl -ErrorAction SilentlyContinue) {
        $kubectlAvailable = $true
        Write-LogSuccess "kubectl found"
        
        # Check if Kubernetes is enabled and running
        try {
            $clusterInfo = kubectl cluster-info 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and -not ($clusterInfo -match "Unable to connect|connection refused")) {
                Write-LogSuccess "Docker Desktop Kubernetes is enabled and running"
                Write-LogInfo "Kubernetes bootstrap can proceed"
                Write-Host ""
            } else {
                Write-LogWarn "Docker Desktop Kubernetes is not enabled or not running"
                Write-LogInfo "Attempting to enable Kubernetes automatically..."
                [Console]::Out.Flush()
                
                # Try to enable Kubernetes automatically
                if (Enable-DockerDesktopKubernetes) {
                    Write-LogSuccess "Kubernetes has been enabled and is ready"
                    Write-Host ""
                } else {
                    Write-LogWarn "Automatic enable failed. Please enable manually:"
                    Write-LogInfo "  1. Open Docker Desktop"
                    Write-LogInfo "  2. Go to Settings → Kubernetes"
                    Write-LogInfo "  3. Check 'Enable Kubernetes'"
                    Write-LogInfo "  4. Click 'Apply & Restart'"
                    Write-LogInfo "  5. Wait for Kubernetes to start"
                    Write-LogInfo "  6. Run this script again"
                    Write-Host ""
                    [Console]::Out.Flush()
                    exit 0
                }
            }
        } catch {
            Write-LogWarn "Docker Desktop Kubernetes is not available"
            Write-LogInfo "Attempting to enable Kubernetes automatically..."
            [Console]::Out.Flush()
            
            # Try to enable Kubernetes automatically
            if (Enable-DockerDesktopKubernetes) {
                Write-LogSuccess "Kubernetes has been enabled and is ready"
                Write-Host ""
            } else {
                Write-LogWarn "Automatic enable failed. Please enable manually in Docker Desktop Settings → Kubernetes"
                Write-Host ""
                exit 0
            }
        }
    } else {
        Write-LogWarn "kubectl not found. Docker Desktop Kubernetes may not be enabled."
        Write-LogInfo "Attempting to enable Kubernetes automatically..."
        [Console]::Out.Flush()
        
        # Try to enable Kubernetes automatically
        if (Enable-DockerDesktopKubernetes) {
            Write-LogSuccess "Kubernetes has been enabled and is ready"
            Write-Host ""
        } else {
            Write-LogWarn "Automatic enable failed. Please enable manually:"
            Write-LogInfo "  1. Open Docker Desktop"
            Write-LogInfo "  2. Go to Settings → Kubernetes"
            Write-LogInfo "  3. Check 'Enable Kubernetes'"
            Write-LogInfo "  4. Click 'Apply & Restart'"
            Write-LogInfo "  5. Wait for Kubernetes to start"
            Write-LogInfo "  6. Run this script again"
            Write-Host ""
            [Console]::Out.Flush()
            exit 0
        }
    }
    
    # Check and install ArgoCD CLI (both dev and production mode)
    Write-Host ""
    Write-LogInfo "Checking ArgoCD CLI installation..."
    if (Test-Command "argocd") {
        try {
            $argocdVersion = argocd version --client 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0) {
                Write-LogSuccess "ArgoCD CLI found"
            } else {
                Write-LogWarn "ArgoCD CLI found but not working properly. Attempting to reinstall..."
                Install-ArgoCDCLI | Out-Null
            }
        } catch {
            Write-LogWarn "ArgoCD CLI found but not working properly. Attempting to reinstall..."
            Install-ArgoCDCLI | Out-Null
        }
    } else {
        Write-LogWarn "ArgoCD CLI not found. Installing..."
        if (-not (Install-ArgoCDCLI)) {
            Write-LogWarn "Failed to install ArgoCD CLI automatically"
            Write-LogInfo "ArgoCD CLI will be needed for deployments"
            Write-LogInfo "You can install it manually later if needed"
        }
    }
    Write-Host ""
}

if (Test-Command "aws") {
    $awsVersion = aws --version
    Write-LogSuccess "AWS CLI found: $awsVersion"
} else {
    Write-LogWarn "AWS CLI not found. Will be installed by setup script if needed."
}

# 4. Download setup script from GitHub using API
Write-Host ""
Write-LogInfo "Downloading setup script from GitHub..."

$headers = @{
    "Authorization" = "token $GithubToken"
    "Accept" = "application/vnd.github.v3+json"
}

$scriptUrl = "https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/setup-windows-docker.ps1"

# Always use TEMP directory for setup script to avoid leaving files in project directory
if ([string]::IsNullOrWhiteSpace($env:TEMP)) {
    $env:TEMP = [System.IO.Path]::GetTempPath()
}

if ([string]::IsNullOrWhiteSpace($env:TEMP)) {
    Write-LogError "Cannot determine temporary directory"
    exit 1
}

$setupScript = Join-Path $env:TEMP "setup-windows-docker.ps1"

if ([string]::IsNullOrWhiteSpace($setupScript)) {
    Write-LogError "Failed to create setup script path"
    exit 1
}

try {
    Show-Progress -PercentComplete 50 -Activity "Downloading setup script" -Status "Connecting to GitHub..." -CurrentOperation "Please wait..."
    $response = Invoke-RestMethod -Uri $scriptUrl -Headers $headers -Method Get
    Show-Progress -PercentComplete 75 -Activity "Downloading setup script" -Status "Downloading script content..." -CurrentOperation "Please wait..."
    # GitHub API returns base64 encoded content in JSON response
    $scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($response.content))
    
    if ([string]::IsNullOrWhiteSpace($scriptContent)) {
        Write-LogError "Downloaded script content is empty"
        exit 1
    }
    
    Show-Progress -PercentComplete 90 -Activity "Downloading setup script" -Status "Saving script..." -CurrentOperation "Please wait..."
    $scriptContent | Out-File -FilePath $setupScript -Encoding UTF8 -Force
    Write-Progress -Activity "Downloading setup script" -Completed
    Write-LogSuccess "Setup script downloaded"
} catch {
    Write-Progress -Activity "Downloading setup script" -Completed
    Write-LogError "Failed to download setup script: $_"
    Write-LogInfo "Make sure your token has 'repo' scope"
    exit 1
}

# 5. Run setup script (it will download project from S3)
Write-Host ""
Write-LogInfo "Running setup script..."
Write-LogInfo "Setup script will download project from S3..."
Write-Host ""

# Final validation before execution
if ([string]::IsNullOrWhiteSpace($setupScript)) {
    Write-LogError "Setup script path is null or empty"
    exit 1
}

if (-not (Test-Path $setupScript)) {
    Write-LogError "Setup script file does not exist: $setupScript"
    exit 1
}

# Pass S3_BUCKET environment variable if provided
if (-not [string]::IsNullOrWhiteSpace($S3Bucket)) {
    $env:S3_BUCKET = $S3Bucket
}

# Run setup script from temp location
try {
    & $setupScript
    $exitCode = $LASTEXITCODE
} catch {
    Write-LogError "Failed to execute installer script: $_"
    Write-LogError "Script path: $setupScript"
    if (Test-Path $setupScript) {
        Write-LogInfo "Script file exists, checking permissions..."
    } else {
        Write-LogError "Script file does not exist!"
    }
    exit 1
}

# Cleanup - always remove setup script after execution
if (Test-Path $setupScript) {
    Remove-Item $setupScript -ErrorAction SilentlyContinue
}
