# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Proje Özeti

Kişisel finans yönetim uygulaması. Stack: Node.js/Express backend + React (react-native-web) frontend + PostgreSQL + Cloudflare Tunnel.

## Yapı

```
FinansAsistan/
├── back/                    # Node.js/Express API (port 5000)
│   ├── back.js              # Ana entry point
│   ├── config/db.js         # PostgreSQL connection pool
│   ├── controllers/         # İş mantığı (gelirAlacak, gider, harcamaBorc, varlik, istek, hatirlatma, kullanici, yetki)
│   ├── routes/              # Express router tanımları
│   ├── middleware/          # auth (JWT), errorHandler, metricsMiddleware (Prometheus)
│   ├── models/              # DB sorgu wrapper'ları (her tablo için ince JS sınıfı)
│   ├── services/
│   │   ├── kafka/           # KafkaJS producer (opsiyonel, KAFKA_ENABLED=false ile devre dışı)
│   │   ├── email/           # Nodemailer e-posta servisi
│   │   ├── notification/    # Bildirim servisi
│   │   └── cache/           # Redis cache (ioredis)
│   └── utils/               # logger (Winston), emailTemplates
├── front/                   # React frontend (port 9999 dev, 80 prod)
│   ├── index.web.js         # Web entry point (AppRegistry)
│   ├── front.js             # Ana App bileşeni (tek büyük stateful bileşen)
│   ├── components/          # Ana UI bileşenleri (Buttons, Forms, Tables, Modal, Header, LoginModal, AdminDashboard, FluidSimulation)
│   ├── src/components/      # Yalnızca LoginModal — bu dizin artık kullanılmıyor, components/ kullan
│   ├── fluid-sim.js         # WebGL parçacık arka plan animasyonu (ayrı bundle olarak derlenir)
│   ├── styles/styles.js     # Global stil tanımları (React Native StyleSheet)
│   ├── context/             # UserContext (auth state)
│   ├── services/api.js      # Fetch API çağrıları (Axios değil)
│   └── webpack.config.js    # Webpack bundle yapılandırması
├── bootstrap/
│   ├── init.sql             # PostgreSQL schema başlangıç
│   └── 001_initial_schema.sql  # Migration script (prod'da da yüklenir)
├── data/                    # Docker postgres volume (read-only, git'e dahil değil)
├── plans/                   # Uygulama planları (implementation plans)
├── docker-compose.yml       # Production deploy (postgres + backend + frontend + cloudflared)
└── .env                     # Ortam değişkenleri
```

## Komutlar

### Geliştirme

Docker Compose 4 servis çalıştırır:

| Servis | Port | Açıklama |
|--------|------|----------|
| `postgres` | 5432 | PostgreSQL 16 — veri deposu |
| `backend` | 5000 | Node.js/Express API |
| `frontend` | 80 | React web uygulaması |
| `cloudflared` | — | Cloudflare Tunnel (production domain) |

```bash
# Tüm stack'i başlat
docker-compose up -d

# Logları takip et
docker-compose logs -f backend
docker-compose logs -f frontend

# Backend'i yeniden başlat (kod değişikliği sonrası nodemon otomatik yapar)
docker-compose restart backend
```

### Backend (back/)

```bash
cd back
npm install
npm run dev        # nodemon ile hot-reload
npm start          # production modu

# Testler (back/tests/ dizini henüz mevcut değil — oluşturulduğunda aktif olur)
npm test                    # Jest + coverage (min %70 threshold)
npm run test:unit           # tests/unit/
npm run test:integration    # tests/integration/
npm run test:e2e            # tests/e2e/
npm run test:watch          # watch modu
```

### Frontend (front/)

```bash
cd front
npm install
npm start          # webpack-dev-server (port 9999) — npm run web ile aynı
npm run build      # production bundle (fluid-sim.js de dist/'e kopyalanır)

# fluid-sim debug testi (port 8000'de çalışan bir sunucu gerekir)
npx playwright test --config playwright-debug.config.js
```

### Production Deploy

```bash
# 1. .env dosyasını ayarla
# 2. Deploy:
docker-compose up -d --build
```

## Git Workflow

Branch yapısı: `main ← dev ← feat/* | fix/*`

**Kurallar:**
- `main` ve `dev` branch'lerine direkt commit YASAK
- Conventional commit: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Breaking change: `feat!:`, `fix!:`

```bash
# Yeni feature branch
git checkout -b feat/ozellik-adi

# Commit (conventional commit format)
git commit -m "feat: yeni ozellik eklendi"

# Merge (dev branch'ine)
git checkout dev
git merge feat/ozellik-adi
```

## Mimari Notlar

### Auth Akışı
JWT tabanlı. Token `Authorization: Bearer <token>` header'ında taşınır. Token ömrü **7 gün**. `authMiddleware.js` token'ı doğrular; süresi 1 saatten az kaldıysa `New-Token` response header'ı ile yeniler (`Access-Control-Expose-Headers: New-Token` de eklenir). Süresi dolmuş token'lar yenilenmez — `TOKEN_EXPIRED` kodu ile 401 döner, yeni giriş gerekir. Her istekte kullanıcının DB'de hala var olup olmadığı da kontrol edilir (`USER_DELETED`).

### Veritabanı Erişimi
`back/config/db.js` bir pg Pool yönetir. Her yerde doğrudan `pool.query()` değil, `query()` ve `transaction()` helper'ları kullanılır; bu helper'lar otomatik Prometheus metriklerini kaydeder.

DB credentials öncelik sırası: `POSTGRES_*` env var → `DB_*` env var. Hiçbiri yoksa uygulama crash eder.

### Kafka (Opsiyonel)
`KAFKA_ENABLED=false` ile tamamen devre dışı bırakılır (dev compose'da varsayılan). Aktifken event'ler `domain.entity.action` formatında topic'lere publish edilir. Kafka bağlantısı başarısız olsa bile backend başlar.

### Frontend Stack
React Native Web üzerine kurulu — `react-native` bileşenleri web'de çalışır. Webpack ile bundle edilir. API URL'si `REACT_APP_API_URL` env var ile ayarlanır (dev: `http://localhost:5000`). Production build'de console log'ları Babel plugin ile otomatik kaldırılır (`babel-plugin-transform-remove-console`).

### Rate Limiting
`express-rate-limit` + `rate-limit-redis` ile Redis destekli rate limiting var. Kritik endpoint'lerde (login, kayıt) uygulanır.

Login ve e-posta doğrulama için ek olarak `kullaniciController.js` içinde **in-memory Map tabanlı** rate limiting vardır (5 deneme / 5 dakika login, 5 deneme / 1 dakika verification). Bu limiter process restart'ta sıfırlanır — multi-instance deploy durumunda dikkat.

### Development Modu
`NODE_ENV=development` olduğunda yeni kayıt olan kullanıcılar e-posta doğrulaması olmadan otomatik olarak `onaylandi = true` şeklinde oluşturulur. Doğrulama kodu console'a da basılır.

### Yetki (Paylaşım) Sistemi
Kullanıcılar varlık/gelir/gider verilerini başka kullanıcılarla paylaşabilir. `yetkiController.js` bir kullanıcı yetki talep ettiğinde hedef kullanıcıya e-posta gönderir; onay/red e-posta linki üzerinden yapılır. `yetki` tablosu izin verilen kullanıcı çiftlerini tutar. `authMiddleware` her istekte yetkili kullanıcı listesini de req'e ekler.

### Admin Paneli
`?admin=1` URL parametresiyle gizli admin dashboard'u açılır. Production'da bu route ayrıca güvenlik kontrolüne tabi tutulmalıdır. `AdminDashboard.js` bileşeni tüm kullanıcıları/işlemleri yönetir.

### Cloudflare Tunnel (Production)
`cloudflared` container'ı `CLOUDFLARE_TUNNEL_TOKEN` ile Cloudflare'e tünel açar; `www.finansasistan.com` bu tünel üzerinden yönlendirilir. Makine değişse bile domain aynı kalır.

## Ortam Değişkenleri (.env)

```
POSTGRES_DB=
POSTGRES_USER=
POSTGRES_PASSWORD=
JWT_SECRET=
EMAIL_USER=
EMAIL_PASS=
SMTP_HOST=
SMTP_PORT=
SMTP_SSL=
APP_URL=
CLOUDFLARE_TUNNEL_TOKEN=   # Sadece production
KAFKA_ENABLED=false        # Kafka'yı devre dışı bırakmak için
CORS_ORIGINS=              # Virgülle ayrılmış izinli origin'ler (varsayılan: finansasistan.com, www.finansasistan.com)
```

## API Endpoint'leri

| Route | Açıklama |
|-------|----------|
| `POST /api/kullanicilar` | Kayıt |
| `POST /api/kullanicilar/validate` | Login (JWT döner) |
| `POST /api/kullanicilar/verify` | E-posta doğrulama |
| `POST /api/kullanicilar/forgot-password` | Parola sıfırlama isteği |
| `POST /api/kullanicilar/reset-password` | Parola sıfırlama |
| `GET/POST/PUT/DELETE /api/varlik` | Varlıklar |
| `GET/POST/PUT/DELETE /api/gelir-alacak` | Gelir/Alacak |
| `GET/POST/PUT/DELETE /api/harcama-borc` | Harcama/Borç |
| `GET/POST /api/gider` | Giderler |
| `GET/POST/PUT/DELETE /api/istek` | İstekler |
| `GET/POST/PUT/DELETE /api/hatirlatma` | Hatırlatmalar |
| `GET/POST/PUT/DELETE /api/yetki` | Yetkiler |
| `GET/POST/PUT/DELETE /api/admin` | Admin paneli |
| `GET /health` | Sağlık kontrolü (DB durumu) |
| `GET /ready` | Kubernetes readiness probe |
| `GET /metrics` | Prometheus metrikleri |

