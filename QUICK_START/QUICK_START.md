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

---

## 🔑 Gerekli Token'lar ve Environment Variables

> **Önemli:** QUICK_START dosyalarında `GITHUB_TOKEN` .env dosyasından okunur.

### Gerekli Environment Variables

**Zorunlu:**
- `ACCESS_TOKEN_GITHUB`: GitHub Personal Access Token

**Opsiyonel (AWS özellikleri için):**
- `AWS_ACCESS_KEY_ID`: AWS Access Key ID
- `AWS_SECRET_ACCESS_KEY`: AWS Secret Access Key
- `AWS_REGION`: AWS Region (varsayılan: `eu-central-1`)
- `S3_BUCKET`: S3 Bucket adı (backup restore için)

---

**Son Güncelleme:** 2025-01-12
