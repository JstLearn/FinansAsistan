# FinansAsistan - Hızlı Başlangıç Rehberi

Projeyi hızlıca başlatmak için bu rehberi kullanın.

---

## 🚀 Hızlı Başlatma (Önerilen)

### Windows

**Development (Geliştirme):**
- `start-windows-dev.bat` dosyasına çift tıklayın

**Production (Canlı):**
- `start-windows-prod.bat` dosyasına çift tıklayın

### Linux

**Development (Geliştirme):**
```bash
./QUICK_START/start-linux-dev.sh
```

**Production (Canlı):**
  ```bash
./QUICK_START/start-linux-prod.sh
```

### macOS

**Development (Geliştirme):**
```bash
./QUICK_START/start-mac-dev.sh
```

**Production (Canlı):**
```bash
./QUICK_START/start-mac-prod.sh
```

> **Not:** Bu dosyalar GitHub'dan en son versiyonu indirir ve otomatik olarak kurar. Docker Desktop'ın çalıştığından emin olun.

---

## 🔄 Development vs Production

### Development (Geliştirme) - Docker Compose
- **Orchestration:** Docker Compose (local development için ideal)
- **S3 Bucket:** `finans-asistan-backups`
- **Bağımsız çalışır:** Prod sürümünden tamamen ayrı
- **Test için:** Geliştirme ve test işlemleri için kullanılır
- **Akıllı kurulum:** Lokalde proje varsa mevcut projeyi kullanır, yoksa GitHub'dan indirir
- **Auto-update:** S3'ten manifest.json kontrolü ile otomatik güncelleme

### Production (Canlı) - Kubernetes
- **Orchestration:** Kubernetes (k3s) with ArgoCD
- **S3 Bucket:** `finans-asistan-backups` (veri yedeği için)
- **Kurulum:** Kubernetes cluster kurulumu (bootstrap.sh)
- **Auto-update:** ArgoCD otomatik olarak GitHub'dan sync yapar
- **Scaling:** Horizontal Pod Autoscaler ile otomatik ölçeklenme
- **High Availability:** Multi-node cluster desteği
- **Canlı veriler:** Gerçek kullanıcı verileri ile çalışır

> **Önemli:** 
> - Lokalde proje varsa, mevcut projeyi kullanır (hızlı başlatma)
> - Lokalde proje yoksa, GitHub'dan en son versiyonu indirir ve kurar
> - Dev sürümünü GitHub'a pushladığınızda, prod sürümü bir sonraki başlatıldığında (lokalde yoksa) yeni versiyonu kullanır

---

## 📋 Ne Yapıyor?

### Development Scripts (Docker Compose)
Başlatma dosyaları şunları otomatik yapar:

1. ✅ AWS credentials'ı ayarlar (`~/.aws/credentials`)
2. ✅ `.env` dosyasını oluşturur (yoksa)
3. ✅ Docker Compose servislerini başlatır (`docker-compose.dev.yml`)
4. ✅ Tüm servisleri hazır hale getirir

**Servisler:**
- Frontend: http://localhost:9999
- Backend: http://localhost:5000

### Production Scripts (Kubernetes)
Production için Kubernetes kurulumu yapılır:

1. ✅ k3s Kubernetes cluster kurulumu
2. ✅ ArgoCD kurulumu (GitOps)
3. ✅ Kubernetes deployment'ları (k8s/ klasöründen)
4. ✅ Otomatik sync: ArgoCD GitHub'dan otomatik sync yapar

**Production Deployment:**
- Kubernetes cluster otomatik olarak GitHub'dan sync yapar
- ArgoCD dashboard: http://localhost:8080 (port-forward ile)
- Servisler: Kubernetes Service ve Ingress üzerinden erişilir

---

## 🔧 Manuel Kurulum (İlk Kez)

Eğer başlatma dosyaları çalışmazsa, manuel kurulum yapabilirsiniz:

> **Önemli:** Manuel kurulum için gerekli environment variable'ları ayarlamanız gerekir. Tüm bilgiler GitHub Secrets'ten alınır.

### Windows Development (PowerShell)

```powershell
# GitHub Token script içinde hardcode olarak bulunur
# AWS bilgileri GitHub Secrets'ten otomatik alınır (environment variables)
# Gerekirse manuel olarak ayarlayabilirsiniz:
# $env:AWS_ACCESS_KEY_ID = "your_access_key"
# $env:AWS_SECRET_ACCESS_KEY = "your_secret_key"
# $env:AWS_REGION = "eu-central-1"
# $env:S3_BUCKET = "your_s3_bucket"

# Install script'ini indir ve çalıştır
$githubToken = "ghp_REDACTED_EXAMPLE_TOKEN_REPLACE_WITH_YOUR_OWN"
$response = Invoke-RestMethod -Uri "https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-windows.ps1" -Headers @{Authorization="token $githubToken"}
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($response.content)) | Out-File -FilePath "$env:TEMP\install.ps1" -Encoding UTF8

# AWS token oluştur (varsa)
if ($env:AWS_ACCESS_KEY_ID -and $env:AWS_SECRET_ACCESS_KEY) {
    $awsToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("{\"accessKeyId\":\"$env:AWS_ACCESS_KEY_ID\",\"secretAccessKey\":\"$env:AWS_SECRET_ACCESS_KEY\",\"region\":\"$env:AWS_REGION\"}"))
    & "$env:TEMP\install.ps1" -GithubToken $githubToken -AwsToken $awsToken -S3Bucket $env:S3_BUCKET
} else {
    & "$env:TEMP\install.ps1" -GithubToken $githubToken -AwsToken "" -S3Bucket ""
}
```

### Windows Production (PowerShell)

```powershell
# GitHub Token script içinde hardcode olarak bulunur
# AWS bilgileri GitHub Secrets'ten otomatik alınır (environment variables)
# Gerekirse manuel olarak ayarlayabilirsiniz:
# $env:AWS_ACCESS_KEY_ID = "your_access_key"
# $env:AWS_SECRET_ACCESS_KEY = "your_secret_key"
# $env:AWS_REGION = "eu-central-1"
# $env:S3_BUCKET = "your_s3_bucket"

# Install script'ini indir ve çalıştır
$githubToken = "ghp_REDACTED_EXAMPLE_TOKEN_REPLACE_WITH_YOUR_OWN"
$response = Invoke-RestMethod -Uri "https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-windows.ps1" -Headers @{Authorization="token $githubToken"}
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($response.content)) | Out-File -FilePath "$env:TEMP\install.ps1" -Encoding UTF8

# AWS token oluştur (varsa)
if ($env:AWS_ACCESS_KEY_ID -and $env:AWS_SECRET_ACCESS_KEY) {
    $awsToken = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("{\"accessKeyId\":\"$env:AWS_ACCESS_KEY_ID\",\"secretAccessKey\":\"$env:AWS_SECRET_ACCESS_KEY\",\"region\":\"$env:AWS_REGION\"}"))
    & "$env:TEMP\install.ps1" -GithubToken $githubToken -AwsToken $awsToken -S3Bucket $env:S3_BUCKET
} else {
    & "$env:TEMP\install.ps1" -GithubToken $githubToken -AwsToken "" -S3Bucket ""
}
```

### Linux Development

```bash
# GitHub Token script içinde hardcode olarak bulunur
# AWS bilgileri GitHub Secrets'ten otomatik alınır (environment variables)
# Gerekirse manuel olarak ayarlayabilirsiniz:
# export AWS_ACCESS_KEY_ID="your_access_key"
# export AWS_SECRET_ACCESS_KEY="your_secret_key"
# export AWS_REGION="eu-central-1"
# export S3_BUCKET="your_s3_bucket"

# AWS token oluştur (varsa)
GITHUB_TOKEN="ghp_REDACTED_EXAMPLE_TOKEN_REPLACE_WITH_YOUR_OWN"
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    AWS_TOKEN_BASE64=$(echo -n "{\"accessKeyId\":\"$AWS_ACCESS_KEY_ID\",\"secretAccessKey\":\"$AWS_SECRET_ACCESS_KEY\",\"region\":\"${AWS_REGION:-eu-central-1}\"}" | base64 -w 0)
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-linux.sh | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -d | bash -s "$GITHUB_TOKEN" "$AWS_TOKEN_BASE64" "$S3_BUCKET"
else
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-linux.sh | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -d | bash -s "$GITHUB_TOKEN" "" ""
fi
```

### Linux Production

```bash
# GitHub Token script içinde hardcode olarak bulunur
# AWS bilgileri GitHub Secrets'ten otomatik alınır (environment variables)
# Gerekirse manuel olarak ayarlayabilirsiniz:
# export AWS_ACCESS_KEY_ID="your_access_key"
# export AWS_SECRET_ACCESS_KEY="your_secret_key"
# export AWS_REGION="eu-central-1"
# export S3_BUCKET="your_s3_bucket"

# AWS token oluştur (varsa)
GITHUB_TOKEN="ghp_REDACTED_EXAMPLE_TOKEN_REPLACE_WITH_YOUR_OWN"
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    AWS_TOKEN_BASE64=$(echo -n "{\"accessKeyId\":\"$AWS_ACCESS_KEY_ID\",\"secretAccessKey\":\"$AWS_SECRET_ACCESS_KEY\",\"region\":\"${AWS_REGION:-eu-central-1}\"}" | base64 -w 0)
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-linux.sh | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -d | bash -s "$GITHUB_TOKEN" "$AWS_TOKEN_BASE64" "$S3_BUCKET"
else
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-linux.sh | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -d | bash -s "$GITHUB_TOKEN" "" ""
fi
```

### macOS Development

```bash
# GitHub Token script içinde hardcode olarak bulunur
# AWS bilgileri GitHub Secrets'ten otomatik alınır (environment variables)
# Gerekirse manuel olarak ayarlayabilirsiniz:
# export AWS_ACCESS_KEY_ID="your_access_key"
# export AWS_SECRET_ACCESS_KEY="your_secret_key"
# export AWS_REGION="eu-central-1"
# export S3_BUCKET="your_s3_bucket"

# AWS token oluştur (varsa)
GITHUB_TOKEN="ghp_REDACTED_EXAMPLE_TOKEN_REPLACE_WITH_YOUR_OWN"
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    AWS_TOKEN_BASE64=$(echo -n "{\"accessKeyId\":\"$AWS_ACCESS_KEY_ID\",\"secretAccessKey\":\"$AWS_SECRET_ACCESS_KEY\",\"region\":\"${AWS_REGION:-eu-central-1}\"}" | base64)
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-mac.sh | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -D | bash -s "$GITHUB_TOKEN" "$AWS_TOKEN_BASE64" "$S3_BUCKET"
else
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-mac.sh | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -D | bash -s "$GITHUB_TOKEN" "" ""
fi
```

### macOS Production

```bash
# GitHub Token script içinde hardcode olarak bulunur
# AWS bilgileri GitHub Secrets'ten otomatik alınır (environment variables)
# Gerekirse manuel olarak ayarlayabilirsiniz:
# export AWS_ACCESS_KEY_ID="your_access_key"
# export AWS_SECRET_ACCESS_KEY="your_secret_key"
# export AWS_REGION="eu-central-1"
# export S3_BUCKET="your_s3_bucket"

# AWS token oluştur (varsa)
GITHUB_TOKEN="ghp_REDACTED_EXAMPLE_TOKEN_REPLACE_WITH_YOUR_OWN"
if [ -n "$AWS_ACCESS_KEY_ID" ] && [ -n "$AWS_SECRET_ACCESS_KEY" ]; then
    AWS_TOKEN_BASE64=$(echo -n "{\"accessKeyId\":\"$AWS_ACCESS_KEY_ID\",\"secretAccessKey\":\"$AWS_SECRET_ACCESS_KEY\",\"region\":\"${AWS_REGION:-eu-central-1}\"}" | base64)
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-mac.sh | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -D | bash -s "$GITHUB_TOKEN" "$AWS_TOKEN_BASE64" "$S3_BUCKET"
else
    curl -s -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/JstLearn/FinansAsistan/contents/scripts/install-mac.sh | grep -o '"content":"[^"]*"' | cut -d'"' -f4 | sed 's/\\n//g' | base64 -D | bash -s "$GITHUB_TOKEN" "" ""
fi
```

---

## 🛠️ Servis Yönetimi

### Servis Durumu

```bash
# Development
docker compose -f docker-compose.dev.yml ps

# Production
docker compose -f docker-compose.yml ps
```

### Logları Görüntüle

```bash
# Tüm servisler
docker compose -f docker-compose.dev.yml logs -f

# Belirli servis
docker compose -f docker-compose.dev.yml logs -f backend
docker compose -f docker-compose.dev.yml logs -f frontend
```

### Servisleri Durdur/Başlat

```bash
# Durdur
docker compose -f docker-compose.dev.yml down

# Başlat
docker compose -f docker-compose.dev.yml up -d

# Yeniden başlat
docker compose -f docker-compose.dev.yml restart
```

---

## 💾 Veritabanı Yedekleme

### Otomatik Yedekleme

Otomatik yedekleme her 5 dakikada bir çalışır (`BACKUP_INTERVAL=300`).

### Manuel Yedekleme

```bash
docker compose -f docker-compose.dev.yml exec postgres-backup /scripts/backup-postgres.sh
```

### Geri Yükleme

```bash
# En son yedeği geri yükle
docker compose -f docker-compose.dev.yml exec postgres-backup /scripts/restore-postgres.sh LATEST
```

---

## ⚠️ Sorun Giderme

### Docker Desktop çalışmıyor

**Windows:**
- Docker Desktop'ı başlatın
- Sistem tepsisinde balina ikonunun göründüğünden emin olun

**Linux/macOS:**
- Docker servisinin çalıştığından emin olun: `sudo systemctl status docker`

### Port zaten kullanılıyor

```bash
# Mevcut servisleri durdur
docker compose -f docker-compose.dev.yml down

# Port'u kullanan servisi bul
netstat -ano | findstr :9999  # Windows
lsof -i :9999                 # Linux/macOS
```

### .env dosyası bulunamıyor

Başlatma dosyaları otomatik oluşturur. Eğer sorun varsa:

```bash
# .env dosyasını manuel oluştur
cp .env.example .env
```

---

## 📚 Daha Fazla Bilgi

- **Mimari:** `docs/ARCHITECTURE.md`
- **Veritabanı:** `docs/DATABASE.md`
- **Klasör Yapısı:** `docs/folderStructure.md`

---

## 🛠️ Gerekli Uygulamalar

Başlatma script'leri otomatik olarak gerekli uygulamaları kontrol eder ve yoksa kurar:

### Otomatik Kurulan Uygulamalar

**Tüm Modlar için:**
- ✅ Git
- ✅ Docker / Docker Desktop
- ✅ AWS CLI (opsiyonel, S3 kullanımı için)

**Production Mode için (ek olarak):**
- ✅ kubectl (Docker Desktop Kubernetes ile birlikte gelir)
- ✅ ArgoCD CLI (otomatik kurulur)

### ArgoCD CLI Kurulumu

Production mode'da ArgoCD CLI otomatik olarak kurulur. Manuel kurulum gerekirse:

**Windows:**
- Install script otomatik olarak GitHub'dan indirir
- Kurulum konumu: `%USERPROFILE%\Tools\ArgoCD\argocd.exe`
- PATH'e otomatik eklenir

**Linux:**
```bash
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

**macOS:**
```bash
# Homebrew ile (önerilen)
brew install argocd

# Veya manuel
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

**Kurulum kontrolü:**
```bash
argocd version --client
```

---

## 🔑 Gerekli Token'lar ve Environment Variables

> **Önemli:** QUICK_START dosyalarında `GITHUB_TOKEN` hardcode olarak bulunur. Diğer tüm bilgiler (AWS credentials, S3 bucket) GitHub Secrets'ten (environment variables) alınır.

### Gerekli Environment Variables

**Opsiyonel (AWS özellikleri için):**
- `AWS_ACCESS_KEY_ID`: AWS Access Key ID
- `AWS_SECRET_ACCESS_KEY`: AWS Secret Access Key
- `AWS_REGION`: AWS Region (varsayılan: `eu-central-1`)
- `S3_BUCKET`: S3 Bucket adı (backup restore için)

> **Not:** `GITHUB_TOKEN` QUICK_START script'lerinde hardcode olarak bulunur. AWS bilgileri environment variable'lardan alınır.

### Environment Variable Ayarlama

**Linux/macOS:**
```bash
export AWS_ACCESS_KEY_ID="your_access_key"  # Opsiyonel
export AWS_SECRET_ACCESS_KEY="your_secret_key"  # Opsiyonel
export AWS_REGION="eu-central-1"  # Opsiyonel
export S3_BUCKET="your_s3_bucket"  # Opsiyonel
```

**Windows (PowerShell):**
```powershell
$env:AWS_ACCESS_KEY_ID = "your_access_key"  # Opsiyonel
$env:AWS_SECRET_ACCESS_KEY = "your_secret_key"  # Opsiyonel
$env:AWS_REGION = "eu-central-1"  # Opsiyonel
$env:S3_BUCKET = "your_s3_bucket"  # Opsiyonel
```

**Windows (CMD):**
```cmd
set AWS_ACCESS_KEY_ID=your_access_key
set AWS_SECRET_ACCESS_KEY=your_secret_key
set AWS_REGION=eu-central-1
set S3_BUCKET=your_s3_bucket
```

> **Not:** `GITHUB_TOKEN` QUICK_START script'lerinde hardcode olarak bulunur, environment variable olarak ayarlamanıza gerek yoktur.

### Token Oluşturma

**GitHub Token:**
- GitHub → Settings → Developer settings → Personal access tokens → Generate new token (classic)
- Gerekli yetkiler: `repo` (tüm repo yetkileri)
- **Not:** GitHub token QUICK_START script'lerinde hardcode olarak bulunur

**AWS Credentials:**
- AWS Console → IAM → Users → Security credentials → Create access key
- S3 bucket erişimi için gerekli IAM policy'leri ayarlayın
- Environment variable olarak ayarlanmalıdır

**ArgoCD CLI (Production Mode için):**
- Production mode'da otomatik olarak kurulur
- Manuel kurulum gerekirse:
  - **Windows:** Install script otomatik olarak GitHub'dan indirir ve `%USERPROFILE%\Tools\ArgoCD\` klasörüne kurar
  - **Linux:** `curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && chmod +x argocd && sudo mv argocd /usr/local/bin/`
  - **macOS:** `brew install argocd` veya manuel olarak GitHub'dan indirilebilir
- Kurulum kontrolü: `argocd version --client`

---

**Son Güncelleme:** 2025-01-12
