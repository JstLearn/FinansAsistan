# Event Processor Service

FinansAsistan Event Processor Service - Kafka event consumer ve processor.

## Özellikler

- ✅ Kafka event consumer
- ✅ Notification handler (Email bildirimleri)
- ✅ Analytics handler (Kullanıcı davranış analizi)
- ✅ Audit handler (Compliance logging)
- ✅ Graceful shutdown
- ✅ Error handling ve retry logic

## Yapı

```
services/event-processor/
├── src/
│   ├── index.js              # Main entry point
│   ├── consumer.js           # Kafka consumer
│   └── handlers/
│       ├── notificationHandler.js  # Email/SMS bildirimleri
│       ├── analyticsHandler.js     # Metrik toplama
│       └── auditHandler.js          # Audit logging
├── package.json
├── Dockerfile
└── .env.example
```

## Kurulum

```bash
cd services/event-processor
npm install
```

## Çalıştırma

### Development
```bash
npm run dev
```

### Production
```bash
npm start
```

### Docker
```bash
docker build -t finans-asistan-event-processor:latest .
docker run -e KAFKA_BROKERS=localhost:9092 \
           -e EMAIL_USER=hello@finansasistan.com \
           -e EMAIL_PASS=your-password \
           finans-asistan-event-processor:latest
```

## Environment Variables

```bash
# Kafka
KAFKA_BROKERS=localhost:9092
KAFKA_CLIENT_ID=event-processor
KAFKA_CONSUMER_GROUP=event-processor-group

# Email (for notifications)
SMTP_HOST=mail.finansasistan.com
SMTP_PORT=465
SMTP_SSL=true
IMAP_HOST=mail.finansasistan.com
IMAP_PORT=993
IMAP_SSL=true
EMAIL_USER=hello@finansasistan.com
EMAIL_PASS=your-app-password

Note: SMTP_PORT is set to 465 (SSL) and IMAP_PORT is set to 993 (SSL) for Odeaweb/MXRouting. Use the ports provided by your mail provider if different. SMTP_SSL and IMAP_SSL should be 'true' for SSL ports (465, 993), or 'false' for STARTTLS ports (587, 143).
```

## Event Handlers

### Notification Handler
- `user.registered` → Verification email gönderir
- `user.verified` → Welcome email gönderir
- `user.password_changed` → Security notification gönderir
- `transaction.*.created` → Transaction bildirimleri (opsiyonel)

### Analytics Handler
- `user.registered` → Günlük kayıt sayısını takip eder
- `user.logged_in` → Aktif kullanıcı sayısını takip eder
- `transaction.*.created` → Transaction metriklerini toplar

### Audit Handler
- Tüm user event'leri → Audit log'a kaydeder
- Tüm transaction event'leri → Audit log'a kaydeder
- Security event'leri → Özel olarak loglar

## Test

```bash
# Kafka topic'ini dinle
docker-compose exec kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic user.registered \
  --from-beginning

# Backend'den event gönder (API çağrısı yap)
# Event processor otomatik olarak işleyecek
```

## Kubernetes Deployment

```bash
kubectl apply -f k8s/11-event-processor.yaml
```

## Notlar

- Event processor, Kafka'dan event'leri consume eder
- Her event için birden fazla handler çalışabilir (notification + analytics + audit)
- Handler'lar async çalışır, birinin başarısız olması diğerlerini etkilemez
- Production'da analytics ve audit için Redis/Database kullanılmalı (şu an in-memory)

