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
│   ├── models/              # Veri modelleri
│   ├── services/
│   │   ├── kafka/           # KafkaJS producer (opsiyonel, KAFKA_ENABLED=false ile devre dışı)
│   │   ├── email/           # Nodemailer e-posta servisi
│   │   ├── notification/    # Bildirim servisi
│   │   └── cache/           # Redis cache (ioredis)
│   └── utils/               # logger (Winston), emailTemplates
├── front/                   # React frontend (port 9999 dev, 80 prod)
│   ├── index.web.js         # Web entry point (AppRegistry)
│   ├── front.js             # Ana App bileşeni
│   ├── src/components/      # LoginModal, diğer bileşenler
│   ├── components/          # Buttons, Forms, Tables, Common
│   ├── context/             # UserContext (auth state)
│   ├── services/api.js      # Axios API çağrıları
│   └── webpack.config.js    # Webpack bundle yapılandırması
├── bootstrap/
│   ├── init.sql             # PostgreSQL schema başlangıç
│   └── 001_initial_schema.sql  # Migration script (prod'da da yüklenir)
├── docker-compose.dev.yml   # Geliştirme ortamı
├── docker-compose.prod.yml  # Production (+ cloudflared servis)
└── .env                     # Ortam değişkenleri
```

## Komutlar

### Geliştirme

```bash
# Tüm stack'i başlat (postgres + backend + frontend)
docker-compose -f docker-compose.dev.yml up -d

# Logları takip et
docker-compose -f docker-compose.dev.yml logs -f backend
docker-compose -f docker-compose.dev.yml logs -f frontend

# Backend'i yeniden başlat (kod değişikliği sonrası nodemon otomatik yapar)
docker-compose -f docker-compose.dev.yml restart backend
```

### Backend (back/)

```bash
cd back
npm install
npm run dev        # nodemon ile hot-reload
npm start          # production modu

# Testler
npm test                    # Jest + coverage
npm run test:unit           # tests/unit/
npm run test:integration    # tests/integration/
npm run test:e2e            # tests/e2e/
npm run test:watch          # watch modu
```

### Frontend (front/)

```bash
cd front
npm install
npm start          # webpack-dev-server (port 9999)
npm run build      # production bundle
```

### Production Deploy

```bash
# 1. .env dosyasını ayarla
# 2. Deploy:
docker-compose -f docker-compose.prod.yml up -d --build
```

## Mimari Notlar

### Auth Akışı
JWT tabanlı. Token `Authorization: Bearer <token>` header'ında taşınır. `authMiddleware.js` token'ı doğrular; süresi 1 saatten az kaldıysa `New-Token` response header'ı ile yeniler. Süresi dolmuş token'lar yenilenmez — yeni giriş gerekir.

### Veritabanı Erişimi
`back/config/db.js` bir pg Pool yönetir. Her yerde doğrudan `pool.query()` değil, `query()` ve `transaction()` helper'ları kullanılır; bu helper'lar otomatik Prometheus metriklerini kaydeder.

DB credentials öncelik sırası: `POSTGRES_*` env var → `DB_*` env var. Hiçbiri yoksa uygulama crash eder.

### Kafka (Opsiyonel)
`KAFKA_ENABLED=false` ile tamamen devre dışı bırakılır (dev compose'da varsayılan). Aktifken event'ler `domain.entity.action` formatında topic'lere publish edilir. Kafka bağlantısı başarısız olsa bile backend başlar.

### Frontend Stack
React Native Web üzerine kurulu — `react-native` bileşenleri web'de çalışır. Webpack ile bundle edilir. API URL'si `REACT_APP_API_URL` env var ile ayarlanır (dev: `http://localhost:5000`).

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
| `GET /health` | Sağlık kontrolü (DB durumu) |
| `GET /metrics` | Prometheus metrikleri |

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **FinansAsistan** (562 symbols, 1409 relationships, 44 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> If any GitNexus tool warns the index is stale, run `npx gitnexus analyze` in terminal first.

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `gitnexus_impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `gitnexus_detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `gitnexus_query({query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `gitnexus_context({name: "symbolName"})`.

## When Debugging

1. `gitnexus_query({query: "<error or symptom>"})` — find execution flows related to the issue
2. `gitnexus_context({name: "<suspect function>"})` — see all callers, callees, and process participation
3. `READ gitnexus://repo/FinansAsistan/process/{processName}` — trace the full execution flow step by step
4. For regressions: `gitnexus_detect_changes({scope: "compare", base_ref: "main"})` — see what your branch changed

## When Refactoring

- **Renaming**: MUST use `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` first. Review the preview — graph edits are safe, text_search edits need manual review. Then run with `dry_run: false`.
- **Extracting/Splitting**: MUST run `gitnexus_context({name: "target"})` to see all incoming/outgoing refs, then `gitnexus_impact({target: "target", direction: "upstream"})` to find all external callers before moving code.
- After any refactor: run `gitnexus_detect_changes({scope: "all"})` to verify only expected files changed.

## Never Do

- NEVER edit a function, class, or method without first running `gitnexus_impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `gitnexus_rename` which understands the call graph.
- NEVER commit changes without running `gitnexus_detect_changes()` to check affected scope.

## Tools Quick Reference

| Tool | When to use | Command |
|------|-------------|---------|
| `query` | Find code by concept | `gitnexus_query({query: "auth validation"})` |
| `context` | 360-degree view of one symbol | `gitnexus_context({name: "validateUser"})` |
| `impact` | Blast radius before editing | `gitnexus_impact({target: "X", direction: "upstream"})` |
| `detect_changes` | Pre-commit scope check | `gitnexus_detect_changes({scope: "staged"})` |
| `rename` | Safe multi-file rename | `gitnexus_rename({symbol_name: "old", new_name: "new", dry_run: true})` |
| `cypher` | Custom graph queries | `gitnexus_cypher({query: "MATCH ..."})` |

## Impact Risk Levels

| Depth | Meaning | Action |
|-------|---------|--------|
| d=1 | WILL BREAK — direct callers/importers | MUST update these |
| d=2 | LIKELY AFFECTED — indirect deps | Should test |
| d=3 | MAY NEED TESTING — transitive | Test if critical path |

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/FinansAsistan/context` | Codebase overview, check index freshness |
| `gitnexus://repo/FinansAsistan/clusters` | All functional areas |
| `gitnexus://repo/FinansAsistan/processes` | All execution flows |
| `gitnexus://repo/FinansAsistan/process/{name}` | Step-by-step execution trace |

## Self-Check Before Finishing

Before completing any code modification task, verify:
1. `gitnexus_impact` was run for all modified symbols
2. No HIGH/CRITICAL risk warnings were ignored
3. `gitnexus_detect_changes()` confirms changes match expected scope
4. All d=1 (WILL BREAK) dependents were updated

## Keeping the Index Fresh

After committing code changes, the GitNexus index becomes stale. Re-run analyze to update it:

```bash
npx gitnexus analyze
```

If the index previously included embeddings, preserve them by adding `--embeddings`:

```bash
npx gitnexus analyze --embeddings
```

To check whether embeddings exist, inspect `.gitnexus/meta.json` — the `stats.embeddings` field shows the count (0 means no embeddings). **Running analyze without `--embeddings` will delete any previously generated embeddings.**

> Claude Code users: A PostToolUse hook handles this automatically after `git commit` and `git merge`.

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
