$ErrorActionPreference = "Stop"

# Set UTF-8 encoding for console output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Basit menu: Ortam (Prod / Dev)
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

# .env yukle (varsa)
$envFile = Join-Path $scriptDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^#=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1].Trim(), $matches[2].Trim(), "Process")
        }
    }
}

# Ortam degiskenleri
if ($envChoice -eq "1") {
    [Environment]::SetEnvironmentVariable("ENVIRONMENT", "production", "Process")
    [Environment]::SetEnvironmentVariable("MODE", "production", "Process")
    $env:ENVIRONMENT = "production"
    $env:MODE = "production"
} else {
    [Environment]::SetEnvironmentVariable("ENVIRONMENT", "development", "Process")
    [Environment]::SetEnvironmentVariable("MODE", "development", "Process")
    $env:ENVIRONMENT = "development"
    $env:MODE = "development"
}

# Prod alt menu: Control-plane / Worker
$modeAction = "prod-cp-a"
$script:forceTakeover = $false  # Force takeover flag
if ($envChoice -eq "1") {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "  Production Islemi Secimi" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
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
        # Control-plane islemleri: Durum tespiti ve kullanici secimi
        Write-Host ""
        Write-Host "[INFO] Control-plane durumu tespit ediliyor..." -ForegroundColor Cyan
        
        # S3 bucket kontrolu
        if (-not $env:S3_BUCKET) {
            Write-Host "[WARN] S3_BUCKET bulunamadi. Yeni kurulum yapilacak (prod-cp-a)" -ForegroundColor Yellow
            $modeAction = "prod-cp-a"
        } elseif (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
            Write-Host "[WARN] AWS CLI bulunamadi. Yeni kurulum yapilacak (prod-cp-a)" -ForegroundColor Yellow
            $modeAction = "prod-cp-a"
        } else {
            # Kume var mi kontrol et
            $clusterExists = $false
            $leaderExists = $false
            $snapshotExists = $false
            $script:isCurrentMachineLeader = $false  # Store leader info at script scope
            $script:storedLeaderInfo = $null
            
            try {
                # Leader info kontrolu - geçici dosyaya indirerek AWS CLI çıktısını filtrele
                $tempLeaderFile = Join-Path $env:TEMP "current-leader.json"
                try {
                    aws s3 cp "s3://$env:S3_BUCKET/current-leader.json" $tempLeaderFile 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $tempLeaderFile)) {
                        try {
                            $fileInfo = Get-Item $tempLeaderFile -ErrorAction Stop
                            if ($fileInfo.Length -eq 0) {
                                Write-Host "[INFO] Kume bulunamadi (current-leader.json bos)" -ForegroundColor Cyan
                                Remove-Item $tempLeaderFile -ErrorAction SilentlyContinue
                            } else {
                                $leaderInfoJson = Get-Content $tempLeaderFile -Raw -ErrorAction Stop
                                $leaderInfoJson = $leaderInfoJson.Trim()
                                
                                # JSON format kontrolü: en azından { veya [ ile başlamalı
                                $trimmedJson = $leaderInfoJson.TrimStart()
                                $isValidJsonFormat = $false
                                if (-not [string]::IsNullOrWhiteSpace($trimmedJson) -and $trimmedJson.Length -ge 2) {
                                    $firstChar = $trimmedJson[0]
                                    if ($firstChar -eq '{' -or $firstChar -eq '[') {
                                        $isValidJsonFormat = $true
                                    }
                                }
                                
                                if (-not $isValidJsonFormat) {
                                    Write-Host "[INFO] Kume bulunamadi (current-leader.json gecersiz format)" -ForegroundColor Cyan
                                    Remove-Item $tempLeaderFile -ErrorAction SilentlyContinue
                                } else {
                                    try {
                                        $leaderInfo = $leaderInfoJson | ConvertFrom-Json -ErrorAction Stop
                                        $clusterExists = $true
                                        $script:storedLeaderInfo = $leaderInfo  # Store for later use
                                        
                                        # Check if current machine is the leader
                                        $currentMachineId = $env:COMPUTERNAME
                                        $script:isCurrentMachineLeader = ($leaderInfo.leader_id -eq $currentMachineId)
                                        
                                        # Leader heartbeat kontrolu (son 5 dakika icinde)
                                        if ($leaderInfo.last_heartbeat) {
                                            try {
                                                # Try multiple datetime formats for compatibility
                                                $lastHeartbeat = $null
                                                $heartbeatStr = $leaderInfo.last_heartbeat.ToString().Trim()
                                                
                                                # Try multiple formats in order of likelihood
                                                $formats = @(
                                                    "yyyy-MM-ddTHH:mm:ssZ",
                                                    "yyyy-MM-ddTHH:mm:ss.fffZ",
                                                    "yyyy-MM-ddTHH:mm:ss",
                                                    "yyyy-MM-dd HH:mm:ss",
                                                    "yyyy/MM/dd HH:mm:ss"
                                                )
                                                
                                                $parseSuccess = $false
                                                foreach ($format in $formats) {
                                                    try {
                                                        if ($format.EndsWith("Z")) {
                                                            # Z format - explicitly UTC
                                                            $lastHeartbeat = [DateTimeOffset]::ParseExact($heartbeatStr, $format, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal).UtcDateTime
                                                        } else {
                                                            # No Z - treat as UTC explicitly
                                                            $parsed = [DateTime]::ParseExact($heartbeatStr, $format, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                                                            $lastHeartbeat = $parsed.ToUniversalTime()
                                                        }
                                                        $parseSuccess = $true
                                                        break
                                                    } catch {
                                                        # Continue to next format
                                                        continue
                                                    }
                                                }
                                                
                                                # Fallback: Try DateTimeOffset.Parse (handles most ISO 8601 variations)
                                                if (-not $parseSuccess) {
                                                    try {
                                                        $dtOffset = [DateTimeOffset]::Parse($heartbeatStr, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                                                        $lastHeartbeat = $dtOffset.UtcDateTime
                                                        $parseSuccess = $true
                                                    } catch {
                                                        # Last fallback: Try DateTime.Parse
                                                        try {
                                                            $parsed = [DateTime]::Parse($heartbeatStr, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal)
                                                            $lastHeartbeat = $parsed.ToUniversalTime()
                                                            $parseSuccess = $true
                                                        } catch {
                                                            throw "Could not parse heartbeat with any method: $heartbeatStr. Error: $_"
                                                        }
                                                    }
                                                }
                                                
                                                if (-not $parseSuccess -or $null -eq $lastHeartbeat) {
                                                    throw "Heartbeat parsing failed for: $heartbeatStr"
                                                }
                                                
                                                # Ensure we're comparing UTC times
                                                $now = [DateTime]::UtcNow
                                                $timeDiff = ($now - $lastHeartbeat).TotalMinutes
                                                
                                                if ($timeDiff -ge 0 -and $timeDiff -lt 5) {
                                                    $leaderExists = $true
                                                    if ($script:isCurrentMachineLeader) {
                                                        Write-Host "[INFO] Kume mevcut ve bu makine lider (heartbeat: $([Math]::Round($timeDiff, 1)) dakika once)" -ForegroundColor Green
                                                    } else {
                                                        Write-Host "[INFO] Kume mevcut ve lider aktif (heartbeat: $([Math]::Round($timeDiff, 1)) dakika once, lider: $($leaderInfo.leader_id))" -ForegroundColor Green
                                                    }
                                                } elseif ($timeDiff -ge 0) {
                                                    Write-Host "[INFO] Kume mevcut ama lider aktif degil (heartbeat: $([Math]::Round($timeDiff, 1)) dakika once)" -ForegroundColor Yellow
                                                } else {
                                                    # Negative time means heartbeat is in the future - this should not happen
                                                    # Check if it's a timezone issue: if difference is close to a round hour (like 60, 120, 180 minutes), it's likely timezone
                                                    $absDiff = [Math]::Abs($timeDiff)
                                                    if ($absDiff -ge 55 -and $absDiff -le 65) {
                                                        Write-Host "[WARN] Lider heartbeat ~1 saat farkli (timezone sorunu olabilir) - lider aktif degil olarak kabul ediliyor" -ForegroundColor Yellow
                                                    } elseif ($absDiff -ge 115 -and $absDiff -le 125) {
                                                        Write-Host "[WARN] Lider heartbeat ~2 saat farkli (timezone sorunu olabilir) - lider aktif degil olarak kabul ediliyor" -ForegroundColor Yellow
                                                    } else {
                                                        Write-Host "[WARN] Lider heartbeat tarihi gelecekte (negatif: $([Math]::Round($timeDiff, 1)) dakika) - zaman farki olabilir, lider aktif degil olarak kabul ediliyor" -ForegroundColor Yellow
                                                    }
                                                }
                                            } catch {
                                                Write-Host "[WARN] Heartbeat parse hatasi: $_" -ForegroundColor Yellow
                                                Write-Host "[INFO] Lider aktif degil olarak kabul ediliyor" -ForegroundColor Yellow
                                            }
                                        } else {
                                            Write-Host "[INFO] Kume mevcut ama lider heartbeat bilgisi yok" -ForegroundColor Yellow
                                        }
                                    } catch {
                                        Write-Host "[WARN] Gecersiz JSON formati: current-leader.json okunamadi - $_" -ForegroundColor Yellow
                                        Write-Host "[INFO] Kume bulunamadi olarak kabul ediliyor" -ForegroundColor Cyan
                                        $clusterExists = $false
                                        $leaderExists = $false
                                    } finally {
                                        Remove-Item $tempLeaderFile -ErrorAction SilentlyContinue
                                    }
                                }
                            }
                        } catch {
                            Write-Host "[WARN] Dosya okunamadi: $_" -ForegroundColor Yellow
                            Write-Host "[INFO] Kume bulunamadi olarak kabul ediliyor" -ForegroundColor Cyan
                            $clusterExists = $false
                            $leaderExists = $false
                            Remove-Item $tempLeaderFile -ErrorAction SilentlyContinue
                        }
                    } else {
                        Write-Host "[INFO] Kume bulunamadi (current-leader.json yok)" -ForegroundColor Cyan
                    }
                } catch {
                    Write-Host "[WARN] S3'ten dosya indirilemedi: $_" -ForegroundColor Yellow
                    Write-Host "[INFO] Kume bulunamadi olarak kabul ediliyor" -ForegroundColor Cyan
                    $clusterExists = $false
                    $leaderExists = $false
                }
                
                # Snapshot kontrolu
                try {
                    $snapshotList = aws s3 ls "s3://$env:S3_BUCKET/k3s/snapshots/" --recursive 2>&1 | Out-String
                    if ($LASTEXITCODE -eq 0 -and ($snapshotList -match "\.db$")) {
                        $snapshotExists = $true
                        $snapshotCount = ([regex]::Matches($snapshotList, "\.db$")).Count
                        Write-Host "[INFO] Snapshot bulundu ($snapshotCount adet)" -ForegroundColor Green
                    } else {
                        Write-Host "[INFO] Snapshot bulunamadi" -ForegroundColor Yellow
                    }
                } catch {
                    Write-Host "[WARN] Snapshot kontrolu basarisiz: $_" -ForegroundColor Yellow
                }
            } catch {
                Write-Host "[WARN] S3 kontrolu basarisiz: $_" -ForegroundColor Yellow
                Write-Host "[INFO] Yeni kurulum yapilacak" -ForegroundColor Cyan
                $clusterExists = $false
                $leaderExists = $false
                $snapshotExists = $false
            }
            
            # Otomatik aksiyon secimi
            if (-not $clusterExists) {
                # a. Kume yoksa: yeni control-plane kur
                Write-Host ""
                Write-Host "[AUTO] Secilen aksiyon: Yeni control-plane kurulumu (prod-cp-a)" -ForegroundColor Green
                Write-Host "  - Kume bulunamadi" -ForegroundColor White
                Write-Host "  - Tum servisler baslatilacak (leader+worker bu makine)" -ForegroundColor White
                $modeAction = "prod-cp-a"
            } elseif ($clusterExists -and -not $leaderExists) {
                # b. Kume varsa ama lider yoksa: Lider olarak katil (snapshot varsa restore, yoksa yeni kur)
                if ($snapshotExists) {
                    Write-Host ""
                    Write-Host "[AUTO] Secilen aksiyon: Lider olarak katil - Snapshot'tan restore (prod-cp-c1)" -ForegroundColor Green
                    Write-Host "  - Kume mevcut ama lider aktif degil" -ForegroundColor White
                    Write-Host "  - Bu makine lider olarak katilacak" -ForegroundColor White
                    Write-Host "  - Snapshot bulundu, state korunarak restore edilecek" -ForegroundColor White
                    $modeAction = "prod-cp-c1"
                } else {
                    Write-Host ""
                    Write-Host "[AUTO] Secilen aksiyon: Lider olarak katil - Yeni control-plane kurulumu (prod-cp-c2)" -ForegroundColor Yellow
                    Write-Host "  - Kume mevcut ama lider aktif degil" -ForegroundColor White
                    Write-Host "  - Bu makine lider olarak katilacak" -ForegroundColor White
                    Write-Host "  - Snapshot bulunamadi, yeni kurulum yapilacak (veri kaybi riski)" -ForegroundColor White
                    $modeAction = "prod-cp-c2"
                }
            } elseif ($clusterExists -and $leaderExists) {
                # c. Kume varsa ve lider aktifse: Force takeover yap
                $leaderId = if ($script:storedLeaderInfo) { $script:storedLeaderInfo.leader_id } else { "unknown" }
                if ($script:isCurrentMachineLeader) {
                    # Bu makine zaten lider: snapshot varsa state restore, yoksa yeni kurulum
                    if ($snapshotExists) {
                        Write-Host ""
                        Write-Host "[AUTO] Secilen aksiyon: State tasima ve restore (prod-cp-b)" -ForegroundColor Green
                        Write-Host "  - Kume mevcut ve bu makine lider" -ForegroundColor White
                        Write-Host "  - State S3'ten tasinacak, snapshot'tan restore edilecek" -ForegroundColor White
                        Write-Host "  - Mevcut node'lar yeni control-plane'e baglanacak (state korunur)" -ForegroundColor White
                        $modeAction = "prod-cp-b"
                    } else {
                        Write-Host ""
                        Write-Host "[AUTO] Secilen aksiyon: Control-plane yeniden kurulumu (prod-cp-a)" -ForegroundColor Yellow
                        Write-Host "  - Kume mevcut ve bu makine lider" -ForegroundColor White
                        Write-Host "  - Snapshot bulunamadi, yeni kurulum yapilacak (veri kaybi riski)" -ForegroundColor White
                        Write-Host "  - Control-plane yeniden kurulacak (leader+worker bu makine)" -ForegroundColor White
                        $modeAction = "prod-cp-a"
                    }
                } else {
                    # Bu makine lider degil: Force takeover yap
                    Write-Host ""
                    Write-Host "[AUTO] Secilen aksiyon: Force Takeover - Liderligi devral (prod-cp-a)" -ForegroundColor Yellow
                    Write-Host "  - Kume mevcut ve lider aktif (lider: $leaderId)" -ForegroundColor White
                    Write-Host "  - Force takeover yapilacak: Mevcut lider devre disi birakilacak" -ForegroundColor Yellow
                    Write-Host "  - Eski lider worker moduna gecirilecek" -ForegroundColor Yellow
                    Write-Host "  - Bu makine yeni lider olacak" -ForegroundColor Yellow
                    $modeAction = "prod-cp-a"
                    $script:forceTakeover = $true  # Force takeover flag
                }
            }
        }
        
        # Force takeover durumunda onay iste
        if ($script:forceTakeover) {
            Write-Host ""
            Write-Host "⚠️  UYARI: Force takeover islemi yapilacak!" -ForegroundColor Red
            Write-Host "  - Mevcut lider devre disi birakilacak" -ForegroundColor Yellow
            Write-Host "  - Eski lider worker moduna gecirilecek" -ForegroundColor Yellow
            Write-Host "  - Bu makine yeni lider olacak" -ForegroundColor Yellow
            Write-Host ""
            $confirm = Read-Host "Devam etmek istediginizden emin misiniz? (E/H)"
            if ($confirm -ne "E" -and $confirm -ne "e") {
                Write-Host "[INFO] Islem iptal edildi." -ForegroundColor Cyan
                exit 0
            }
        } else {
            Write-Host ""
            Write-Host "Devam etmek icin Enter'a basin..." -ForegroundColor Cyan
            Read-Host | Out-Null
        }
    }
} else {
    # Dev icin basit mod
    $modeAction = "dev"
}

# Leadership kaydi: Sadece control-plane modlarinda bilgilendir (worker modunda YAPMA!)
# Leadership kaydini setup script'e birak - orada daha kapsamli bilgi (k3s_token, node_ip vs) eklenir
$controlPlaneModes = @("prod-cp-a", "prod-cp-b", "prod-cp-c1", "prod-cp-c2")
if ($envChoice -eq "1" -and $modeAction -in $controlPlaneModes -and $env:S3_BUCKET -and $env:AWS_ACCESS_KEY_ID -and $env:AWS_SECRET_ACCESS_KEY -and (Get-Command aws -ErrorAction SilentlyContinue)) {
    Write-Host "[INFO] Control-plane modu - Leadership setup script'te kaydedilecek..." -ForegroundColor Blue
} elseif ($modeAction -eq "prod-worker") {
    Write-Host "[INFO] Worker modu - Leadership kaydi atlanıyor (mevcut lider korunuyor)" -ForegroundColor Blue
}

# Setup script'ini cagir
$setupScript = Join-Path $scriptDir "..\scripts\setup-windows-docker.ps1"

# Force takeover durumunda -ForceTakeover parametresi ekle
if ($script:forceTakeover) {
    & $setupScript -ModeAction $modeAction -ForceTakeover
} else {
    & $setupScript -ModeAction $modeAction
}
