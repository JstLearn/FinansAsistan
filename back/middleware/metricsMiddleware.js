// ════════════════════════════════════════════════════════════
// FinansAsistan - Prometheus Metrics Middleware
// Application metrics collection
// ════════════════════════════════════════════════════════════

const promClient = require('prom-client');
const logger = require('../utils/logger');

// Prometheus registry
const register = new promClient.Registry();

// Default metrics (CPU, memory, etc.)
promClient.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.5, 1, 2, 5, 10]
});

const httpRequestTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const httpRequestErrors = new promClient.Counter({
  name: 'http_request_errors_total',
  help: 'Total number of HTTP request errors',
  labelNames: ['method', 'route', 'error_type']
});

const databaseQueryDuration = new promClient.Histogram({
  name: 'database_query_duration_seconds',
  help: 'Duration of database queries in seconds',
  labelNames: ['query_type', 'table'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5]
});

const databaseConnections = new promClient.Gauge({
  name: 'database_connections_active',
  help: 'Number of active database connections',
  labelNames: ['state']
});

const kafkaEventsPublished = new promClient.Counter({
  name: 'kafka_events_published_total',
  help: 'Total number of Kafka events published',
  labelNames: ['event_type', 'topic']
});

const kafkaEventsFailed = new promClient.Counter({
  name: 'kafka_events_failed_total',
  help: 'Total number of failed Kafka events',
  labelNames: ['event_type', 'topic', 'error_type']
});

const cacheHits = new promClient.Counter({
  name: 'cache_hits_total',
  help: 'Total number of cache hits',
  labelNames: ['cache_key']
});

const cacheMisses = new promClient.Counter({
  name: 'cache_misses_total',
  help: 'Total number of cache misses',
  labelNames: ['cache_key']
});

// Register all metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestTotal);
register.registerMetric(httpRequestErrors);
register.registerMetric(databaseQueryDuration);
register.registerMetric(databaseConnections);
register.registerMetric(kafkaEventsPublished);
register.registerMetric(kafkaEventsFailed);
register.registerMetric(cacheHits);
register.registerMetric(cacheMisses);

// Metrics middleware
const metricsMiddleware = (req, res, next) => {
  const startTime = Date.now();
  const route = req.route ? req.route.path : req.path;
  const method = req.method;

  // Response finish event
  res.on('finish', () => {
    const duration = (Date.now() - startTime) / 1000;
    const statusCode = res.statusCode;

    // Record metrics
    httpRequestDuration.observe({ method, route, status_code: statusCode }, duration);
    httpRequestTotal.inc({ method, route, status_code: statusCode });

    // Error tracking
    if (statusCode >= 400) {
      const errorType = statusCode >= 500 ? 'server_error' : 'client_error';
      httpRequestErrors.inc({ method, route, error_type: errorType });
    }
  });

  next();
};

// Metrics endpoint handler
const getMetrics = async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    const metrics = await register.metrics();
    res.send(metrics);
  } catch (error) {
    logger.error('❌ Metrics export failed', { error: error.message });
    res.status(500).send('Metrics export failed');
  }
};

module.exports = {
  register,
  metricsMiddleware,
  getMetrics,
  // Metric helpers
  recordDatabaseQuery: (queryType, table, duration) => {
    databaseQueryDuration.observe({ query_type: queryType, table }, duration);
  },
  recordDatabaseConnections: (active, idle) => {
    databaseConnections.set({ state: 'active' }, active);
    databaseConnections.set({ state: 'idle' }, idle);
  },
  recordKafkaEventPublished: (eventType, topic) => {
    kafkaEventsPublished.inc({ event_type: eventType, topic });
  },
  recordKafkaEventFailed: (eventType, topic, errorType) => {
    kafkaEventsFailed.inc({ event_type: eventType, topic, error_type: errorType });
  },
  recordCacheHit: (cacheKey) => {
    cacheHits.inc({ cache_key: cacheKey });
  },
  recordCacheMiss: (cacheKey) => {
    cacheMisses.inc({ cache_key: cacheKey });
  }
};

