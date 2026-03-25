# FinansAsistan - Servis Dağılımı ve Yerleşim Stratejisi

Bu dokümantasyon, FinansAsistan Kubernetes cluster'ındaki servislerin nasıl dağıtıldığını ve hangi servislerin sadece lider makinede, hangilerinin distributed (tüm node'larda) çalıştığını açıklar.

## Genel Bakış

FinansAsistan cluster'ı **lider makine** ve **worker node'lar** üzerinde çalışır. Servisler iki kategoriye ayrılır:

1. **Lider-Only Servisler**: Sadece lider makinede çalışan servisler (stateful, singleton)
2. **Distributed Servisler**: Tüm node'larda çalışabilen servisler (stateless, scalable)

---

## 🔴 Lider-Only Servisler

### PostgreSQL
- **Kubernetes Tipi**: StatefulSet
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: Persistent storage gerektirir, veri tutarlılığı kritik
- **Storage**: 50Gi PVC (hostpath)
- **Container'lar**: 
  - `postgres` (PostgreSQL 16)
  - `wal-g-backup` (S3 backup sidecar)
- **HPA**: ❌ Yok
- **Kaynaklar**: Memory 128Mi-4Gi, CPU 100m-1000m

### Redis
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: Persistent storage gerektirir, cache tutarlılığı önemli
- **Storage**: 5Gi PVC (hostpath)
- **Container'lar**: `redis` (Redis 7)
- **HPA**: ❌ Yok
- **Kaynaklar**: Memory 64Mi-2Gi, CPU 50m-500m

### Kafka Controller
- **Kubernetes Tipi**: KafkaNodePool
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: Kafka cluster yönetimi
- **Storage**: 20Gi PVC
- **HPA**: ❌ Yok
- **Kaynaklar**: Memory 256Mi-2560Mi, CPU 200m-2000m

### Kafka Broker
- **Kubernetes Tipi**: KafkaNodePool
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: Persistent storage, message queue tutarlılığı kritik
- **Storage**: 100Gi PVC
- **HPA**: ❌ Yok
- **Kaynaklar**: Memory 512Mi-5120Mi, CPU 300m-3000m

### Prometheus
- **Kubernetes Tipi**: StatefulSet
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: Metrics storage, veri tutarlılığı kritik
- **Storage**: 50Gi PVC (hostpath)
- **Container'lar**: `prometheus` (Prometheus v2.48.0)
- **HPA**: ❌ Yok
- **Kaynaklar**: Memory 512Mi-2Gi, CPU 500m-2000m

### ArgoCD Application Controller
- **Kubernetes Tipi**: StatefulSet
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: Singleton servis, GitOps yönetimi için tek instance gerekli
- **Container'lar**: `argocd-application-controller` (ArgoCD v3.2.0)
- **HPA**: ❌ Yok

### Traefik Ingress Controller
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: Ingress controller, tek instance yeterli
- **Storage**: ClusterIP sabit (10.96.72.134)
- **Container'lar**: `traefik` (Traefik v3.0)
- **HPA**: ❌ Yok
- **Kaynaklar**: Memory 128Mi-512Mi, CPU 100m-500m

### Cloudflare Tunnel
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: Tunnel bağlantısı, tek instance yeterli
- **Container'lar**: `cloudflared` (Cloudflare Tunnel)
- **HPA**: ❌ Yok
- **Kaynaklar**: Memory 64Mi-256Mi, CPU 50m-200m
- **Not**: Port yönlendirme gerektirmez, Cloudflare üzerinden erişim

### External-DNS
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: DNS yönetimi, tek instance yeterli
- **Container'lar**: `external-dns` (External-DNS v0.14.0)
- **HPA**: ❌ Yok
- **Kaynaklar**: Memory 64Mi-128Mi, CPU 50m-100m
- **Not**: Route53 DNS kayıtlarını otomatik yönetir

### GitHub Actions Self-Hosted Runner
- **Kubernetes Tipi**: RunnerDeployment (actions-runner-controller)
- **Dağılım**: Sadece lider makinede (zorunlu)
- **Affinity**: `requiredDuringSchedulingIgnoredDuringExecution`
- **Neden**: CI/CD işlemleri, küme içinde çalışmalı
- **Container'lar**: `runner` (GitHub Actions runner)
- **HPA**: ❌ Yok
- **Kaynaklar**: Memory 512Mi-2Gi, CPU 500m-2000m
- **Not**: Kubernetes API'ye erişim için in-cluster kubeconfig kullanır

---

## 🟢 Distributed Servisler

### Backend
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless API, yüksek trafik için distributed
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### Frontend
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless UI, yüksek trafik için distributed
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### Event Processor
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless event processing, yüksek throughput için distributed
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### Grafana
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Read-only UI, HA için distributed
- **Storage**: PVC (dashboard ve config için)
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### AlertManager
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Alert routing, HA için distributed
- **Storage**: 5Gi PVC (alert state için)
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### Postgres Exporter
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless metrics exporter
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### Redis Exporter
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless metrics exporter
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### Kafka Exporter
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless metrics exporter
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### ArgoCD Server
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless API server
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### ArgoCD Repo Server
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless repo server
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### ArgoCD Dex Server
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless auth server
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

### ArgoCD Notifications Controller
- **Kubernetes Tipi**: Deployment
- **Dağılım**: Tüm node'larda (distributed)
- **Affinity**: Yok (her node'da en az 1 pod, yüke göre daha fazla pod olabilir)
- **Neden**: Stateless notifications
- **HPA**: ✅ Var (max 100 replicas)
- **Ölçekleme**: CPU/Memory bazlı otomatik ölçekleme, minReplicas = node sayısı

---

## Affinity Stratejileri Açıklaması

### `required` (Zorunlu)
**Tam adı**: `requiredDuringSchedulingIgnoredDuringExecution`

- **Anlam**: Pod **mutlaka** belirtilen koşulu sağlamalı, aksi halde çalışmaz
- **Kullanım**: Lider-Only servisler
- **Davranış**: Lider node yoksa pod başlatılamaz
- **Örnek**: PostgreSQL, Redis, Kafka, Prometheus


### Affinity Yok (Serbest Yerleşim)
- **Anlam**: Pod'lar herhangi bir node'a yerleşebilir, hiçbir kısıtlama yok
- **Kullanım**: Tüm distributed servisler
- **Davranış**: 
  - Pod'lar kaynaklara göre en uygun node'a yerleşir
  - Her node'da en az 1 pod olması HPA minReplicas ile sağlanır (minReplicas = node sayısı)
  - Yük arttığında aynı node'da birden fazla pod olabilir
  - HPA ile ölçeklendiğinde → Pod'lar kaynak durumuna göre herhangi bir node'a yerleşir
- **Örnek**: Backend, Frontend, Event Processor, Grafana, AlertManager, Exporters, ArgoCD Server

---

## Lider Makine Toplam Kaynak Kullanımı

Lider makinede çalışan servislerin toplam kaynak kullanımı:

- **Memory Request**: ~2.5Gi
- **Memory Limit**: ~18Gi
- **CPU Request**: ~2.0 cores
- **CPU Limit**: ~10 cores

**Not**: Distributed servisler HPA ile ölçeklenir ve kaynak kullanımı dinamik olarak değişir.

**Yeni Eklenen Servisler:**
- Traefik Ingress Controller
- Cloudflare Tunnel
- External-DNS
- GitHub Actions Self-Hosted Runner

---

## Best Practices

### Lider-Only Servisler İçin
1. ✅ Persistent storage kullan (PVC)
2. ✅ `requiredDuringSchedulingIgnoredDuringExecution` kullan
3. ✅ HPA kullanma (tek instance)
4. ✅ Backup stratejisi uygula (wal-g, Redis backup)

### Distributed Servisler İçin
1. ✅ Stateless tasarım
2. ✅ `podAntiAffinity` veya `preferredDuringSchedulingIgnoredDuringExecution` kullan
3. ✅ HPA ile ölçekle
4. ✅ Her node'da en az bir pod olmasını sağla (minReplicas)

---

## Güncelleme Notları

### 2024-11-19
- Grafana, AlertManager ve Exporters'lar distributed yapıldı
- `nodeAffinity` kaldırıldı, sadece `podAntiAffinity` kullanılıyor
- HA ve performans iyileştirmeleri yapıldı

### 2025-01-27
- Cloudflare Tunnel eklendi (lider-only)
- Traefik Ingress Controller eklendi (lider-only)
- External-DNS eklendi (lider-only)
- GitHub Actions Self-Hosted Runner eklendi (lider-only)
- Cluster Autoscaler kaldırıldı (Docker Desktop uyumluluğu için)

---

## İlgili Dokümantasyon

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Genel mimari
- [DATABASE.md](./DATABASE.md) - Veritabanı yapılandırması
