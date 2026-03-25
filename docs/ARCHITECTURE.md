# 🏗️ FinansAsistan Mimarisi
> **Hibrit, Otonom ve Ölçeklenebilir Sistem Tasarımı**

FinansAsistan, yüksek erişilebilirlik (High Availability) ve maliyet optimizasyonunu bir araya getiren modern bir bulut mimarisine sahiptir.

---

## 🗺️ Genel Bakış

Sistem, fiziksel makinelerin (on-premise) sabit maliyet avantajı ile bulutun (AWS) dinamik ölçeklenme ve felaket kurtarma yeteneklerini birleştirir.

```text
[ İnternet ] 
     |
[ Cloudflare Zero Trust ] -> (Güvenli Tünel)
     |
[ Lider Node (Physical/EC2) ] <--- [ Worker Node 1 ]
     |                        <--- [ Worker Node 2 ]
     +---> [ AWS S3 (Veri Merkezi) ]
```

---

## 🤖 Otonom Liderlik ve Failover

Sistemin kalbi, S3 üzerinde tutulan `current-leader.json` dosyasıdır. Tüm makineler bu dosyayı izler ve kendi rollerine karar verir.

### 1. Liderlik Seçimi (Priority Logic)
- **Fiziksel Makine:** Her zaman en yüksek önceliğe sahiptir. Eğer bir fiziksel makine ayağa kalkarsa, mevcut lider EC2 olsa bile liderliği devralır (**Eve Dönüş özelliği**).
- **EC2 Instance:** Sadece fiziksel makine bulunmadığında lider olur.

### 2. Felaket Kurtarma (Disaster Recovery) Akışı
1. **Heartbeat:** Lider her 15 saniyede bir S3'teki kalp atışını günceller.
2. **Monitoring:** AWS Lambda fonksiyonu kalp atışını izler.
3. **Trigger:** Kalp atışı **5 dakika** gecikirse (Fiziksel lider çökmüşse), Lambda bir EC2 başlatır.
4. **Recovery:** Yeni EC2, S3'teki en son veritabanı yedeğini ve k3s snapshot'ını kullanarak sistemi ayağa kaldırır.

---

## 📦 Bileşen Yapısı

### 🚀 Kontrol Düzlemi (Control-Plane)
Lider makine üzerinde çalışan kritik servisler:
- **k3s Server:** Kubernetes yönetim merkezi.
- **PostgreSQL 16:** Ana veri deposu.
- **Apache Kafka:** Event broker.
- **Redis:** Cache ve Session yönetimi.

### 👷 Veri Düzlemi (Worker-Plane)
Yük arttığında otomatik açılan EC2 makineleri üzerinde:
- **API Gateway:** Gelen istekleri karşılar.
- **Event Processor:** Kafka event'lerini işler.
- **Frontend:** Kullanıcı arayüzünü sunar.

---

## 🔄 Veri Akışları

### Event-Driven Mimari
Her işlem (gelir ekleme, varlık güncelleme vb.) bir **Kafka Event**'idir.
```text
Kullanıcı -> API -> DB (Write) -> Kafka (Event) -> Processor -> Redis (Cache Update)
```

### S3-Centric Backup
- **Veritabanı:** Her 5 dakikada bir S3'e yedeklenir.
- **Kubernetes State:** Günlük etcd snapshot'ları S3'e yüklenir.
- **Secrets:** `.env` dosyası S3'te şifreli tutulur.

---

## 🛠️ Ölçekleme Stratejisi

1. **HPA (Horizontal Pod Autoscaler):** Pod'lar CPU/RAM kullanımına göre çoğalır.
2. **Cluster Autoscaler:** Mevcut makineler yetmezse AWS'den yeni EC2 makineleri istenir.
3. **Scale-Down:** Gece veya düşük yükte EC2 makineleri otomatik kapanır, sistem sadece fiziksel makine üzerinde (sıfır ek maliyet) çalışmaya devam eder.

---
**Doküman Güncelleme:** 2025-12-25  
**Mimar:** FinansAsistan AI Team
