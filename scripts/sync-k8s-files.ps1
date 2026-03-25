# Sync k8s deployment files from remote to avoid merge conflicts
# This script pulls the latest k8s files updated by GitHub Actions workflow

param(
    [string]$Branch = "master"
)

Write-Host "🔄 Syncing k8s deployment files from remote..." -ForegroundColor Yellow

# Fetch latest changes
Write-Host "📥 Fetching latest changes from remote..." -ForegroundColor Gray
git fetch origin $Branch 2>&1 | Out-Null

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Failed to fetch from remote" -ForegroundColor Red
    exit 1
}

# K8s deployment files that are updated by GitHub Actions workflow
$K8SFiles = @(
    "k8s/04-backend-deployment.yaml",
    "k8s/05-frontend-deployment.yaml",
    "k8s/11-event-processor.yaml",
    "k8s/13-argocd-application.yaml"
)

$NeedsUpdate = $false

# Check if files have changed on remote
foreach ($file in $K8SFiles) {
    if (Test-Path $file) {
        $remoteFile = "origin/$Branch`:$file"
        $hasChanges = git diff --quiet "HEAD" $remoteFile 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            $NeedsUpdate = $true
            Write-Host "⚠️  $file has been updated on remote" -ForegroundColor Yellow
        }
    }
}

if ($NeedsUpdate) {
    Write-Host "📥 Pulling latest k8s deployment files..." -ForegroundColor Yellow
    
    # Stash any local changes to k8s files
    $hasStash = $false
    foreach ($file in $K8SFiles) {
        if (Test-Path $file) {
            $status = git status --porcelain $file 2>&1
            if ($status -match "^ M|^M ") {
                Write-Host "💾 Stashing local changes to $file..." -ForegroundColor Gray
                git stash push -m "Auto-stash: sync k8s files" $file 2>&1 | Out-Null
                $hasStash = $true
            }
        }
    }
    
    # Pull latest k8s files from remote
    foreach ($file in $K8SFiles) {
        $remoteFile = "origin/$Branch`:$file"
        $checkRemote = git show $remoteFile 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ Updating $file" -ForegroundColor Green
            git checkout $remoteFile -- $file 2>&1 | Out-Null
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "   ✅ $file updated successfully" -ForegroundColor Green
            } else {
                Write-Host "   ⚠️  Failed to update $file" -ForegroundColor Yellow
            }
        }
    }
    
    if ($hasStash) {
        Write-Host "`n💡 Local changes were stashed. Use 'git stash pop' to restore them if needed." -ForegroundColor Yellow
    }
    
    Write-Host "`n✅ K8s files synced successfully!" -ForegroundColor Green
    Write-Host "💡 Review changes with: git diff" -ForegroundColor Cyan
} else {
    Write-Host "✅ K8s files are already up to date" -ForegroundColor Green
}

