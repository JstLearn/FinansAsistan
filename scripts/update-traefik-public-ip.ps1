# ============================================================
# Traefik LoadBalancer Public IP'yi S3'e Kaydetme
# ============================================================

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Traefik Public IP S3'e Kaydediliyor" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Public IP'yi al
Write-Host "🔍 Public IP alınıyor..." -ForegroundColor Yellow
try {
    $publicIP = (Invoke-WebRequest -Uri 'https://api.ipify.org' -UseBasicParsing).Content.Trim()
    Write-Host "✅ Public IP bulundu: $publicIP" -ForegroundColor Green
} catch {
    Write-Host "❌ Public IP alınamadı: $_" -ForegroundColor Red
    exit 1
}

# 2. .env'den S3 bucket'ı oku
$envFile = Join-Path $PSScriptRoot "..\QUICK_START\.env"
if (-not (Test-Path $envFile)) {
    Write-Host "❌ .env dosyası bulunamadı: $envFile" -ForegroundColor Red
    exit 1
}

$s3Bucket = ""
$awsRegion = "eu-central-1"
Get-Content $envFile | ForEach-Object {
    if ($_ -match '^S3_BUCKET=(.+)$') {
        $s3Bucket = $matches[1].Trim()
    }
    if ($_ -match '^AWS_REGION=(.+)$') {
        $awsRegion = $matches[1].Trim()
    }
}

if ([string]::IsNullOrEmpty($s3Bucket)) {
    Write-Host "❌ S3_BUCKET .env'de bulunamadı" -ForegroundColor Red
    exit 1
}

Write-Host "✅ S3 Bucket: $s3Bucket" -ForegroundColor Green
Write-Host "✅ AWS Region: $awsRegion" -ForegroundColor Green

# 3. IP bilgisini JSON olarak hazırla
$ipInfo = @{
    public_ip = $publicIP
    timestamp = ([DateTime]::UtcNow).ToString('o')
    service = 'traefik-loadbalancer'
    region = $awsRegion
} | ConvertTo-Json

# 4. S3'e kaydet
Write-Host ""
Write-Host "📤 S3'e kaydediliyor..." -ForegroundColor Yellow
try {
    $ipInfo | aws s3 cp - "s3://$s3Bucket/traefik-public-ip.json" --content-type "application/json" --region $awsRegion
    Write-Host "✅ Public IP S3'e kaydedildi: s3://$s3Bucket/traefik-public-ip.json" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Kaydedilen bilgiler:" -ForegroundColor Cyan
    Write-Host $ipInfo -ForegroundColor White
} catch {
    Write-Host "❌ S3'e kayıt başarısız: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ İşlem tamamlandı!" -ForegroundColor Green


