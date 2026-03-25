# ============================================================
# Route53 Hosted Zone Oluşturma Script'i (PowerShell)
# finansasistan.com için dinamik DNS yönetimi
# ============================================================

$ErrorActionPreference = "Stop"

$DOMAIN = "finansasistan.com"
$REGION = "eu-central-1"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Route53 Hosted Zone Oluşturma" -ForegroundColor Cyan
Write-Host "Domain: $DOMAIN" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# AWS credentials kontrolü
if (-not $env:AWS_ACCESS_KEY_ID -or -not $env:AWS_SECRET_ACCESS_KEY) {
    Write-Host "❌ AWS credentials bulunamadı!" -ForegroundColor Red
    Write-Host "Lütfen AWS_ACCESS_KEY_ID ve AWS_SECRET_ACCESS_KEY environment variable'larını ayarlayın." -ForegroundColor Yellow
    exit 1
}

# Mevcut hosted zone kontrolü
Write-Host "🔍 Mevcut hosted zone kontrol ediliyor..." -ForegroundColor Yellow
try {
    $existingZones = aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN}.']" --output json | ConvertFrom-Json
    
    if ($existingZones.Count -gt 0) {
        Write-Host "✅ Hosted zone zaten mevcut!" -ForegroundColor Green
        $zoneId = ($existingZones[0].Id -replace '/hostedzone/', '')
        Write-Host "Zone ID: $zoneId" -ForegroundColor Cyan
        Write-Host ""
        
        $zoneInfo = aws route53 get-hosted-zone --id $zoneId --output json | ConvertFrom-Json
        Write-Host "📋 Name Server'lar:" -ForegroundColor Cyan
        $zoneInfo.DelegationSet.NameServers | ForEach-Object {
            Write-Host "   $_" -ForegroundColor White
        }
        Write-Host ""
        Write-Host "✅ Bu name server'ları Odeaweb'e ekleyin!" -ForegroundColor Green
        exit 0
    }
} catch {
    # Zone yok, devam et
}

# Yeni hosted zone oluştur
Write-Host "📝 Yeni hosted zone oluşturuluyor..." -ForegroundColor Yellow
$callerRef = "finans-asistan-$(([DateTime]::UtcNow).ToString('yyyyMMddHHmmss'))"
$zoneResponse = aws route53 create-hosted-zone `
    --name $DOMAIN `
    --caller-reference $callerRef `
    --hosted-zone-config "Comment=FinansAsistan Dynamic DNS" `
    --output json | ConvertFrom-Json

$zoneId = $zoneResponse.HostedZone.Id -replace '/hostedzone/', ''
$nameServers = $zoneResponse.DelegationSet.NameServers

Write-Host ""
Write-Host "✅ Hosted zone başarıyla oluşturuldu!" -ForegroundColor Green
Write-Host "Zone ID: $zoneId" -ForegroundColor Cyan
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "📋 ODEAWEB'E EKLENECEK NAME SERVER'LAR:" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
foreach ($ns in $nameServers) {
    Write-Host "$ns" -ForegroundColor White
}
Write-Host ""
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "ℹ️  Bu name server'ları Odeaweb panelinden ekleyin:" -ForegroundColor Yellow
Write-Host "   Odeaweb → Domain → finansasistan.com → İsim Sunucuları" -ForegroundColor Yellow
Write-Host ""
Write-Host "⏱️  DNS yayılımı 5 dakika - 24 saat sürebilir." -ForegroundColor Yellow

