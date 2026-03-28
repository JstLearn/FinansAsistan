# FinansAsistan

Kişisel finans yönetim uygulaması. Basit stack: Node.js backend + React frontend + PostgreSQL + Cloudflare Tunnel.

## Yapı

```
FinansAsistan/
├── back/           # Node.js/Express API
├── front/          # React frontend (nginx)
├── bootstrap/      # PostgreSQL schema (init.sql)
├── docker-compose.prod.yml
└── .env
```

## Deploy

```bash
# 1. .env dosyasını ayarla (örnek için .env.example'a bak)
# 2. Tek komutla deploy:
docker-compose -f docker-compose.prod.yml up -d --build
```

Hangi makinede çalışırsa çalışsın, `www.finansasistan.com` Cloudflare Tunnel üzerinden o makineye yönlenir.

## Cloudflare Tunnel

Dinamik deploy için Cloudflare Tunnel kullanılır. Her makineye:
1. `CLOUDFLARE_TUNNEL_TOKEN` .env'e eklenmeli
2. Cloudflare Dashboard'da `www.finansasistan.com` CNAME record tunnel'a yönlendirilmeli

## Dev

```bash
docker-compose -f docker-compose.dev.yml up -d
```
