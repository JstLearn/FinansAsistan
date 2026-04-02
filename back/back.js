// ════════════════════════════════════════════════════════════
// back/back.js - Main Entry Point
// Migrated: MS SQL Server → PostgreSQL
// Date: 2025-11-06
// Event-Driven: Kafka integration added
// ════════════════════════════════════════════════════════════

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, "../.env") });
const express = require('express');
const cors = require('cors');
const { pool, checkHealth } = require('./config/db');
const { connect: connectKafka } = require('./services/kafka/producer');
const varlikRoutes = require('./routes/varlikRoutes');
const gelirAlacakRoutes = require('./routes/gelirAlacakRoutes');
const harcamaBorcRoutes = require('./routes/harcamaBorcRoutes');
const giderRoutes = require('./routes/giderRoutes');
const istekRoutes = require('./routes/istekRoutes');
const hatirlatmaRoutes = require('./routes/hatirlatmaRoutes');
const kullaniciRoutes = require('./routes/kullaniciRoutes');
const yetkiRoutes = require('./routes/yetkiRoutes');
const adminRoutes = require('./routes/adminRoutes');
const { metricsMiddleware, getMetrics } = require('./middleware/metricsMiddleware');

const app = express();

// CORS ayarları
const allowedOrigins = (process.env.CORS_ORIGINS || process.env.CORS_ORIGIN || 'https://finansasistan.com,https://www.finansasistan.com')
  .split(',')
  .map(o => o.trim())
  .filter(Boolean);

app.use(cors({
  origin: (origin, callback) => {
    if (!origin) return callback(null, true); // mobile/cli gibi origin olmayan istekler
    if (allowedOrigins.includes(origin)) return callback(null, true);
    return callback(new Error('Not allowed by CORS'));
  },
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Active-Account'],
  credentials: true
}));

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(metricsMiddleware); // Prometheus metrics

// Request logging (simple)
app.use((req, res, next) => {
    console.log(`${req.method} ${req.path}`);
    next();
});

// Health check endpoint
app.get('/health', async (req, res) => {
    const dbHealth = await checkHealth();
    res.json({
        status: dbHealth.healthy ? 'healthy' : 'unhealthy',
        database: dbHealth.healthy ? 'connected' : 'disconnected',
        timestamp: new Date().toISOString()
    });
});

// Ready endpoint (Kubernetes readiness probe)
app.get('/ready', async (req, res) => {
    const dbHealth = await checkHealth();
    if (dbHealth.healthy) {
        res.json({ status: 'ready', database: 'connected' });
    } else {
        res.status(503).json({ status: 'not ready', error: dbHealth.error });
    }
});

// Metrics endpoint (Prometheus)
app.get('/metrics', getMetrics);

// Routes
app.use('/api/kullanicilar', kullaniciRoutes);
app.use('/api/varlik', varlikRoutes);
app.use('/api/gelir-alacak', gelirAlacakRoutes);
app.use('/api/harcama-borc', harcamaBorcRoutes);
app.use('/api/gider', giderRoutes);
app.use('/api/istek', istekRoutes);
app.use('/api/hatirlatma', hatirlatmaRoutes);
app.use('/api/yetki', yetkiRoutes);
app.use('/api/admin', adminRoutes);

// Root ve favicon
app.get('/', (req, res) => {
    res.status(200).json({ success: true, service: 'FinansAsistan API' });
});

app.get('/favicon.ico', (req, res) => {
    res.status(204).end();
});

// 404 handler
app.use((req, res) => {
    console.log('404 - Endpoint bulunamadı:', req.method, req.url);
    res.status(404).json({
        success: false,
        error: `Endpoint bulunamadı: ${req.method} ${req.url}`
    });
});

// Error handler
app.use((err, req, res, next) => {
    console.error('Hata:', err);
    res.status(500).json({
        success: false,
        error: 'Sunucu hatası'
    });
});

// Sunucuyu başlat
const PORT = process.env.PORT || 5000;
// Always listen on all interfaces (0.0.0.0)
const HOST = '0.0.0.0';

// Export app for testing
module.exports = app;

// Only start server if not in test environment
if (process.env.NODE_ENV !== 'test') {
  // Initialize Kafka producer connection (non-blocking)
  // Skip Kafka connection if KAFKA_ENABLED is explicitly set to 'false'
  if (process.env.KAFKA_ENABLED !== 'false') {
    (async () => {
      try {
        await connectKafka();
        console.log('✅ Kafka producer connected');
      } catch (error) {
        console.error('⚠️  Kafka connection failed (non-critical):', error.message);
        // Kafka bağlantısı başarısız olsa bile server başlasın
      }
    })();
  } else {
    console.log('ℹ️  Kafka disabled - skipping connection');
  }

  app.listen(PORT, HOST, () => {
    console.log(`\n✅ Sunucu başlatıldı!`);
    console.log(`   Local: http://localhost:${PORT}`);
    console.log(`   Network: http://0.0.0.0:${PORT}\n`);
    console.log('Kullanılabilir endpoint\'ler:');
    console.log('- POST   /api/kullanicilar');
    console.log('- POST   /api/kullanicilar/validate');
    console.log('- POST   /api/kullanicilar/verify');
    console.log('- POST   /api/kullanicilar/forgot-password');
    console.log('- POST   /api/kullanicilar/reset-password');
    console.log('- GET    /api/varlik');
    console.log('- POST   /api/varlik');
    console.log('- PUT    /api/varlik/:id');
    console.log('- DELETE /api/varlik/:id');
    console.log('- GET    /api/gelir');
    console.log('- POST   /api/gelir');
    console.log('- PUT    /api/gelir/:id');
    console.log('- DELETE /api/gelir/:id');
    console.log('- GET    /api/harcama-borc');
    console.log('- POST   /api/harcama-borc');
    console.log('- PUT    /api/harcama-borc/:id');
    console.log('- DELETE /api/harcama-borc/:id');
    console.log('- GET    /api/gider');
    console.log('- POST   /api/gider');
    console.log('- GET    /api/istek');
    console.log('- POST   /api/istek');
    console.log('- PUT    /api/istek/:id');
    console.log('- DELETE /api/istek/:id');
    console.log('- GET    /api/hatirlatma');
    console.log('- POST   /api/hatirlatma');
    console.log('- PUT    /api/hatirlatma/:id');
    console.log('- DELETE /api/hatirlatma/:id');
    console.log('- GET    /api/yetki');
    console.log('- POST   /api/yetki');
    console.log('- GET    /api/yetki/check');
    console.log('- PUT    /api/yetki/:id');
    console.log('- DELETE /api/yetki/:id');
  });
}
