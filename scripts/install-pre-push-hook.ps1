# Install pre-push git hook to automatically sync k8s files
# This prevents merge conflicts when GitHub Actions workflow updates k8s files

Write-Host "🔧 Installing pre-push git hook..." -ForegroundColor Cyan

$HookSource = Join-Path $PSScriptRoot "pre-push-hook"
$HookTarget = Join-Path (Split-Path (git rev-parse --git-dir)) "hooks\pre-push"

if (-not (Test-Path $HookSource)) {
    Write-Host "❌ Hook source file not found: $HookSource" -ForegroundColor Red
    exit 1
}

# Copy hook to .git/hooks
Copy-Item $HookSource $HookTarget -Force

# Make it executable (for Linux/Mac compatibility)
if ($IsLinux -or $IsMacOS) {
    chmod +x $HookTarget
} else {
    # Windows: Set execute permissions
    icacls $HookTarget /grant Everyone:RX 2>&1 | Out-Null
}

if (Test-Path $HookTarget) {
    Write-Host "✅ Pre-push hook installed successfully!" -ForegroundColor Green
    Write-Host "📍 Location: $HookTarget" -ForegroundColor Gray
    Write-Host ""
    Write-Host "💡 The hook will automatically sync k8s files before pushing to master/main" -ForegroundColor Yellow
} else {
    Write-Host "❌ Failed to install hook" -ForegroundColor Red
    exit 1
}

