# 🗄️ Namespace Organizasyonu

FinansAsistan, kaynaklarını düzenli tutmak ve güvenlik izolasyonu sağlamak için mantıksal bölümler (Namespaces) kullanır. Bu doküman, tüm kaynakların detaylı dökümünü içerir.

---

## 🗺️ Namespace Haritası

| Namespace | Rolü | Kaynak Sayısı | Kritiklik |
| :--- | :--- | :--- | :--- |
| **`finans-asistan`** | 🏠 Ana Uygulama & Veri | ~70+ | 🔴 Kritik |
| **`argocd`** | 🤖 GitOps & Otomasyon | ~30+ | 🟡 Yüksek |
| **`traefik-system`** | 🚪 Giriş Kapısı (Ingress) | ~5 | 🟡 Yüksek |
| **`cloudflare-tunnel`**| 🛡️ Güvenli Erişim | ~3 | 🟢 Orta |
| **`kube-system`** | ⚙️ Cluster Servisleri | ~10+ | 🔴 Kritik |

---

## 🎯 Detaylı Kaynak Listesi

### 1. `finans-asistan` (Core)
Sistemin kalbi. Tüm iş mantığı ve veritabanları buradadır.
- **Uygulama:** `backend`, `frontend`, `event-processor` (Deployments & HPAs).
- **Veritabanı:** `postgres` (StatefulSet), `redis` (Deployment).
- **Kafka:** `kafka-cluster` (Kafka CR), Brokers & Controllers (NodePools), Entity Operator.
- **Monitoring:** `prometheus` (StatefulSet), `grafana`, `alertmanager`, `node-exporter` (DaemonSet).
- **Exporters:** `postgres-exporter`, `redis-exporter`, `kafka-exporter`.
- **Görevler:** `kafka-autoscaler`, `redis-backup` (CronJobs).
- **Ağ:** `finans-asistan-ingress` (Ingress), Secrets (certs, ecr), ConfigMaps.

### 2. `argocd` (Yönetim)
Sürekli dağıtım (CD) ve GitOps süreçleri.
- **Bileşenler:** `argocd-server`, `argocd-repo-server`, `argocd-application-controller`, `argocd-dex-server`, `argocd-notifications-controller`, `argocd-redis`.
- **Konfigürasyon:** `argocd-cm`, `argocd-rbac-cm`, `argocd-secret`, `argocd-repo-github` (SSH).

### 3. `traefik-system` (Ağ)
Dış dünyadan gelen trafiğin yönetimi.
- **Traefik:** `traefik` (Deployment & LoadBalancer Service).
- **Depolama:** `traefik-acme-pvc` (SSL sertifikaları için).

### 4. `cloudflare-tunnel` (Güvenlik)
Zero Trust erişim tüneli.
- **Tünel:** `cloudflared` (Deployment), `cloudflare-tunnel-token` (Secret).

### 5. `kube-system` (Cluster)
Altyapı servisleri.
- **DNS:** `external-dns` (Route53 entegrasyonu).
- **Otomasyon:** `cluster-autoscaler` (EKS/Cloud için).

---

## 🔍 Cluster-Scoped (Global) Kaynaklar
Bazı kaynaklar namespace bağımsızdır:
- **RBAC:** `traefik` (ClusterRole), `external-dns` (ClusterRole), `prometheus` (ClusterRole).
- **CRDs:** Kafka (Strimzi), ArgoCD Applications.
- **Ingress:** `traefik` (IngressClass).

---

## ⚠️ Önemli Kurallar
1. **ArgoCD App:** `argocd` namespace'inde durur ama `finans-asistan` namespace'ini yönetir.
2. **Secrets:** Şifreler ve sertifikalar her zaman ilgili namespace'deki `Secret` objelerinde saklanır.
3. **Storage:** Stateful servisler (Postgres, Kafka, Prometheus) mutlaka `PVC` kullanmalıdır.

---
[🏠 README'ye Dön](./README.md) | [🏗️ Mimari Detaylar](./ARCHITECTURE.md)

