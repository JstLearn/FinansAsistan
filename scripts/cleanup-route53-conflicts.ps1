# ============================================================
# Route53 Çakışmalarını Temizleme
# External-DNS'in çalışması için gereken temizlik
# ============================================================

$ErrorActionPreference = "Stop"

$DOMAIN = "finansasistan.com"
$REGION = "eu-central-1"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Route53 Çakışmaları Temizleniyor" -ForegroundColor Cyan
Write-Host "Domain: $DOMAIN" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Hosted zone ID'yi bul
Write-Host "🔍 Hosted zone bulunuyor..." -ForegroundColor Yellow
try {
    $zones = aws route53 list-hosted-zones --query "HostedZones[?Name=='${DOMAIN}.']" --output json | ConvertFrom-Json
    if ($zones.Count -eq 0) {
        Write-Host "❌ Hosted zone bulunamadı: $DOMAIN" -ForegroundColor Red
        exit 1
    }
    $zoneId = ($zones[0].Id -replace '/hostedzone/', '')
    Write-Host "✅ Zone ID: $zoneId" -ForegroundColor Green
} catch {
    Write-Host "❌ Hosted zone bulunamadı: $_" -ForegroundColor Red
    exit 1
}

# Mevcut kayıtları listele
Write-Host ""
Write-Host "📋 Mevcut DNS kayıtları kontrol ediliyor..." -ForegroundColor Yellow
try {
    $records = aws route53 list-resource-record-sets --hosted-zone-id $zoneId --output json | ConvertFrom-Json
    $conflicts = @()
    
    foreach ($record in $records.ResourceRecordSets) {
        $name = $record.Name -replace '\.$', ''
        
        # Çakışan kayıtları bul
        if ($name -match '^(api|app|www)\.finansasistan\.com$' -or $name -eq 'finansasistan.com') {
            if ($record.Type -eq 'CNAME' -or $record.Type -eq 'TXT') {
                $conflicts += $record
                Write-Host "⚠️  Çakışan kayıt: $($record.Type) $name" -ForegroundColor Yellow
            }
        }
    }
    
    if ($conflicts.Count -eq 0) {
        Write-Host "✅ Çakışan kayıt bulunamadı" -ForegroundColor Green
        exit 0
    }
    
    Write-Host ""
    Write-Host "🗑️  $($conflicts.Count) çakışan kayıt silinecek..." -ForegroundColor Yellow
    
    # Her çakışan kaydı sil
    foreach ($record in $conflicts) {
        $name = $record.Name -replace '\.$', ''
        Write-Host "   Siliniyor: $($record.Type) $name" -ForegroundColor Cyan
        
        $changeBatch = @{
            Changes = @(
                @{
                    Action = "DELETE"
                    ResourceRecordSet = @{
                        Name = $record.Name
                        Type = $record.Type
                        TTL = $record.TTL
                        ResourceRecords = $record.ResourceRecords
                    }
                }
            )
        } | ConvertTo-Json -Depth 10
        
        try {
            $changeBatch | aws route53 change-resource-record-sets --hosted-zone-id $zoneId --change-batch file:///dev/stdin --output json | Out-Null
            Write-Host "   ✅ Silindi: $($record.Type) $name" -ForegroundColor Green
        } catch {
            Write-Host "   ⚠️  Silinemedi (zaten yok olabilir): $name" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "✅ Temizlik tamamlandı!" -ForegroundColor Green
    
} catch {
    Write-Host "❌ Hata: $_" -ForegroundColor Red
    exit 1
}


