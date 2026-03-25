# ════════════════════════════════════════════════════════════
# FinansAsistan - Frontend Image Check and ArgoCD Sync Script
# Image ID değişikliğini tespit edip ArgoCD sync tetikler
# ════════════════════════════════════════════════════════════

param(
    [string]$Namespace = "finans-asistan",
    [string]$Deployment = "frontend",
    [string]$ArgoCDApp = "finans-asistan",
    [string]$ImageRepo = "finans-asistan-frontend-production",
    [string]$ImageTag = "latest",
    [string]$AWSRegion = "eu-central-1"
)

Write-Host "🔍 Frontend image ID kontrolü ve ArgoCD sync tetikleme..." -ForegroundColor Cyan

# 1. Mevcut pod'daki image ID'sini al
Write-Host "`n📦 Mevcut pod'daki image ID alınıyor..." -ForegroundColor Yellow
$currentPod = kubectl get pods -n $Namespace -l app=$Deployment -o jsonpath='{.items[0].metadata.name}' 2>$null

if (-not $currentPod) {
    Write-Host "❌ Pod bulunamadı! Deployment çalışmıyor olabilir." -ForegroundColor Red
    exit 1
}

$currentImageId = kubectl get pod $currentPod -n $Namespace -o jsonpath='{.status.containerStatuses[0].imageID}' 2>$null

if (-not $currentImageId) {
    Write-Host "⚠️  Pod'daki image ID alınamadı. Pod henüz hazır olmayabilir." -ForegroundColor Yellow
    Write-Host "   Pod durumu kontrol ediliyor..." -ForegroundColor Yellow
    kubectl get pod $currentPod -n $Namespace
    exit 1
}

# Image ID format: docker-pullable://<repo>@<digest> veya <repo>@<digest>
$currentDigest = if ($currentImageId -match '@(sha256:[a-f0-9]+)') { $matches[1] } else { $null }

Write-Host "   Pod: $currentPod" -ForegroundColor Gray
Write-Host "   Image ID: $currentImageId" -ForegroundColor Gray
if ($currentDigest) {
    Write-Host "   Digest: $currentDigest" -ForegroundColor Gray
}

# 2. ECR'deki en son image digest'ini al
Write-Host "`n☁️  ECR'deki en son image digest alınıyor..." -ForegroundColor Yellow

$ecrDigest = $null
try {
    $ecrManifestJson = aws ecr describe-images --repository-name $ImageRepo --image-ids imageTag=$ImageTag --region $AWSRegion --query 'sort_by(imageDetails,& imagePushedAt)[-1]' --output json 2>$null
    
    if ($ecrManifestJson) {
        $ecrManifest = $ecrManifestJson | ConvertFrom-Json
        $ecrDigest = $ecrManifest.imageDigest
        $ecrPushedAt = $ecrManifest.imagePushedAt
        
        Write-Host "   ECR Digest: $ecrDigest" -ForegroundColor Gray
        Write-Host "   Push Time: $ecrPushedAt" -ForegroundColor Gray
    } else {
        Write-Host "⚠️  ECR'den image bilgisi alınamadı." -ForegroundColor Yellow
        Write-Host "   AWS CLI veya credentials kontrol edin." -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  ECR kontrolü başarısız: $_" -ForegroundColor Yellow
    Write-Host "   AWS CLI kurulu ve yapılandırılmış olmalı." -ForegroundColor Yellow
}

# 3. Image digest'lerini karşılaştır
if ($currentDigest -and $ecrDigest) {
    Write-Host "`n🔍 Image digest karşılaştırması:" -ForegroundColor Cyan
    Write-Host "   Pod Digest:    $currentDigest" -ForegroundColor Gray
    Write-Host "   ECR Digest:   $ecrDigest" -ForegroundColor Gray
    
    if ($currentDigest -eq $ecrDigest) {
        Write-Host "`n✅ Image'ler aynı. ArgoCD sync gerekmiyor." -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n🔄 Image değişmiş! ArgoCD sync tetikleniyor..." -ForegroundColor Yellow
    }
} else {
    if (-not $currentDigest) {
        Write-Host "`n⚠️  Pod'daki digest alınamadı." -ForegroundColor Yellow
    }
    if (-not $ecrDigest) {
        Write-Host "`n⚠️  ECR'deki digest alınamadı." -ForegroundColor Yellow
    }
    Write-Host "`n🔄 Güvenli tarafta kalarak ArgoCD sync tetikleniyor..." -ForegroundColor Yellow
}

# 4. ArgoCD Application'ı refresh et ve sync tetikle
Write-Host "`n🚀 ArgoCD sync tetikleniyor..." -ForegroundColor Cyan

# ArgoCD Application annotation'ını güncelle (refresh tetiklemek için)
Write-Host "   ArgoCD application refresh annotation güncelleniyor..." -ForegroundColor Gray
kubectl annotate application $ArgoCDApp -n $Namespace argocd.argoproj.io/refresh=hard --overwrite 2>&1 | Out-Null

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ ArgoCD refresh annotation eklendi" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  ArgoCD annotation eklenemedi (ArgoCD kurulu olmayabilir)" -ForegroundColor Yellow
}

# ArgoCD sync komutu ile manuel sync tetikle
Write-Host "   ArgoCD sync komutu çalıştırılıyor..." -ForegroundColor Gray
$syncResult = kubectl patch application $ArgoCDApp -n $Namespace --type merge -p '{"operation":{"initiatedBy":{"username":"image-check-script"},"sync":{"revision":"HEAD"}}}' 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "   ✅ ArgoCD sync tetiklendi" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  ArgoCD sync tetiklenemedi, alternatif yöntem deneniyor..." -ForegroundColor Yellow
    
    # Alternatif: ArgoCD CLI kullan (eğer kuruluysa)
    $argocdCli = Get-Command argocd -ErrorAction SilentlyContinue
    if ($argocdCli) {
        Write-Host "   ArgoCD CLI ile sync yapılıyor..." -ForegroundColor Gray
        argocd app sync $ArgoCDApp --core 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ ArgoCD CLI sync başarılı" -ForegroundColor Green
        }
    } else {
        Write-Host "   ⚠️  ArgoCD CLI bulunamadı" -ForegroundColor Yellow
    }
}

# 5. ArgoCD sync durumunu kontrol et
Write-Host "`n⏳ ArgoCD sync durumu kontrol ediliyor..." -ForegroundColor Cyan

Start-Sleep -Seconds 3

$appStatus = kubectl get application $ArgoCDApp -n $Namespace -o jsonpath='{.status.sync.status}' 2>$null
$appHealth = kubectl get application $ArgoCDApp -n $Namespace -o jsonpath='{.status.health.status}' 2>$null

Write-Host "   Sync Status: $appStatus" -ForegroundColor $(if ($appStatus -eq "Synced") { "Green" } else { "Yellow" })
Write-Host "   Health Status: $appHealth" -ForegroundColor $(if ($appHealth -eq "Healthy") { "Green" } else { "Yellow" })

# 6. Deployment'ın güncellenmesini bekle (ArgoCD sync sonrası)
Write-Host "`n⏳ Deployment'ın güncellenmesi bekleniyor (max 2 dakika)..." -ForegroundColor Cyan

$maxWait = 120  # 2 dakika
$waited = 0
$checkInterval = 5

while ($waited -lt $maxWait) {
    Start-Sleep -Seconds $checkInterval
    $waited += $checkInterval
    
    $newPod = kubectl get pods -n $Namespace -l app=$Deployment -o jsonpath='{.items[0].metadata.name}' 2>$null
    if ($newPod -and $newPod -ne $currentPod) {
        $newImageId = kubectl get pod $newPod -n $Namespace -o jsonpath='{.status.containerStatuses[0].imageID}' 2>$null
        if ($newImageId) {
            Write-Host "`n✅ Yeni pod oluşturuldu!" -ForegroundColor Green
            Write-Host "   Yeni Pod: $newPod" -ForegroundColor Gray
            Write-Host "   Yeni Image ID: $newImageId" -ForegroundColor Gray
            
            if ($ecrDigest) {
                $newDigest = if ($newImageId -match '@(sha256:[a-f0-9]+)') { $matches[1] } else { $null }
                if ($newDigest -eq $ecrDigest) {
                    Write-Host "   ✅ Image digest eşleşiyor!" -ForegroundColor Green
                } else {
                    Write-Host "   ⚠️  Image digest henüz eşleşmiyor (pod henüz yeni image'i çekiyor olabilir)" -ForegroundColor Yellow
                }
            }
            
            exit 0
        }
    }
    
    Write-Host "   Bekleniyor... ($waited/$maxWait saniye)" -ForegroundColor Gray
}

Write-Host "`n⚠️  Timeout! Deployment henüz güncellenmedi." -ForegroundColor Yellow
Write-Host "   ArgoCD sync durumunu kontrol edin:" -ForegroundColor Yellow
Write-Host "   kubectl get application $ArgoCDApp -n $Namespace" -ForegroundColor Gray

exit 1

