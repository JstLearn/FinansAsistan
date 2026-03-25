# 🏦 FinansAsistan
> **Otonom, Hibrit ve Akıllı Finansal Yönetim Platformu**

FinansAsistan, sadece bir harcama takip uygulaması değil; **kendi kendini yöneten (autonomous)**, fiziksel makineleriniz ile bulutu (AWS) harmanlayan bir mühendislik harikasıdır.

---

## 🌟 Neden FinansAsistan?

Geleneksel uygulamaların aksine, FinansAsistan **"Ölümsüzlük"** ilkesiyle tasarlanmıştır:
- 🏠 **Hibrit Mimari:** Evdeki eski bir laptop veya güçlü bir sunucu fark etmez; sistem fiziksel donanımınızı bulutla birleştirir.
- 🤖 **Otonom Yönetim:** Sistem kapalı mı? AWS otomatik fark eder, kendini kurar ve ayağa kalkar.
- 🔙 **Eve Dönüş (Return Home):** Siz evdeki makinenizi açtığınız an, buluttaki liderliği sessizce devralır ve maliyetinizi sıfırlar.
- 🛡️ **S3-Centric Veri:** Her şey S3'te! Veritabanı yedeğinden Kubernetes konfigürasyonuna kadar her şey bulutta güvende.

---

## 🛠️ Teknoloji Radarı

### 🚀 Core
- **Kubernetes (k3s):** Hafif ve güçlü konteyner orkestrasyonu.
- **Apache Kafka:** Tüm servisler event-driven mimariyle konuşur.
- **PostgreSQL 16:** Güvenilir veri deposu (S3'e sürekli yedekleme).

### ☁️ Cloud & Edge
- **AWS Lambda:** Sistemin "kalp atışını" izleyen gözlemci.
- **AWS EC2 (Graviton):** İhtiyaç anında devreye giren ARM tabanlı ekonomik güç.
- **Cloudflare Tunnel:** Port yönlendirme yok, statik IP yok. Zero Trust güvenlik.

### 💻 Frontend & API
- **React Native Web:** Modern, hızlı ve her cihaza uyumlu arayüz.
- **Node.js Express:** Yüksek performanslı API gateway.

---

## 📊 Sistem Durumu ve Mimari

### 1. Liderlik Hiyerarşisi
Sistemde her zaman bir **"Lider"** (Control-Plane) vardır:
1. **Fiziksel Lider:** Evdeki makineniz. En yüksek önceliğe sahiptir.
2. **Bulut Lideri (EC2):** Fiziksel makineler kapalıyken otomatik devreye giren yedek güç.

### 2. Felaket Kurtarma (DR)
```text
Evdeki Lider 💀 Kapanırsa -> [5 Dakika Bekle] -> AWS Lambda 🚀 EC2 Başlatır -> S3'ten Yedek Yüklenir -> Sistem Online ✅
```

---

## 📁 Dokümantasyon Rehberi

Sistemi daha derinlemesine tanımak için aşağıdaki belgeleri inceleyebilirsiniz:

| Doküman | İçerik |
| :--- | :--- |
| 🏗️ **[ARCHITECTURE.md](./ARCHITECTURE.md)** | Derin teknik mimari, failover senaryoları ve flow diyagramları. |
| 🗄️ **[DATABASE.md](./DATABASE.md)** | Veritabanı şeması, tablo yapıları ve ilişkiler. |
| 📦 **[SERVICE-DISTRIBUTION.md](./SERVICE-DISTRIBUTION.md)** | Hangi servis nerede çalışıyor? Kaynak yönetimi. |
| 🌐 **[NAMESPACE-ORGANIZATION.md](./NAMESPACE-ORGANIZATION.md)** | Kubernetes üzerindeki mantıksal ayrım ve izolasyon. |

---

## 🚀 Hızlı Başlatma

Sistemi yeni bir makinede ayağa kaldırmak için tek bir komut yeterli:

```powershell
# Windows için (Yönetici modunda)
./scripts/setup-windows-docker.ps1
```

```bash
# Linux/macOS için
./scripts/setup-linux-docker.sh
```

---

## 🔐 Güvenlik Politikası

- **Zero Trust:** Cloudflare üzerinden kimlik doğrulamalı erişim.
- **Secrets:** Şifreler asla kodda durmaz; AWS S3 ve GitHub Secrets üzerinden yönetilir.
- **Audit Logs:** Her finansal işlem Kafka üzerinden denetlenir ve kaydedilir.

---
**Versiyon:** 1.0.0 | **Durum:** 🚀 Üretim Hazır | **Erişim:** [finansasistan.com](https://www.finansasistan.com)
