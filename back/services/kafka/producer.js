// ════════════════════════════════════════════════════════════
// FinansAsistan - Kafka Producer Service
// Event-driven architecture için Kafka event publisher
// ════════════════════════════════════════════════════════════

const { Kafka } = require('kafkajs');
const { v4: uuidv4 } = require('uuid');
const { logger } = require('../../utils/logger');
const { recordKafkaEventPublished, recordKafkaEventFailed } = require('../../middleware/metricsMiddleware');

// Kafka configuration
const kafkaConfig = {
  clientId: process.env.KAFKA_CLIENT_ID || 'finans-backend',
  brokers: (process.env.KAFKA_BROKERS || 'localhost:9092').split(','),
  retry: {
    initialRetryTime: 100,
    retries: 8,
    multiplier: 2,
    maxRetryTime: 30000
  },
  requestTimeout: 30000,
  connectionTimeout: 3000
};

// Kafka client oluştur
const kafka = new Kafka(kafkaConfig);
const producer = kafka.producer();

// Producer connection state
let isConnected = false;

// Producer bağlantısını başlat
const connect = async () => {
  if (isConnected) {
    return;
  }

  try {
    await producer.connect();
    isConnected = true;
    logger.info('✅ Kafka producer connected', { brokers: kafkaConfig.brokers });
  } catch (error) {
    logger.error('❌ Kafka producer connection failed', { error: error.message });
    throw error;
  }
};

// Producer bağlantısını kapat
const disconnect = async () => {
  if (!isConnected) {
    return;
  }

  try {
    await producer.disconnect();
    isConnected = false;
    logger.info('⏹️  Kafka producer disconnected');
  } catch (error) {
    logger.error('❌ Kafka producer disconnect failed', { error: error.message });
  }
};

// Event schema validation
const validateEvent = (eventType, payload) => {
  if (!eventType || typeof eventType !== 'string') {
    throw new Error('Event type is required and must be a string');
  }
  if (!payload || typeof payload !== 'object') {
    throw new Error('Payload is required and must be an object');
  }
};

// Event publish fonksiyonu
const publishEvent = async (eventType, payload, metadata = {}) => {
  // Producer bağlı değilse bağlan
  if (!isConnected) {
    await connect();
  }

  // Event validation
  validateEvent(eventType, payload);

  // Event object oluştur
  const event = {
    eventId: uuidv4(),
    eventType: eventType,
    timestamp: new Date().toISOString(),
    version: '1.0',
    correlationId: metadata.correlationId || uuidv4(),
    payload: payload,
    metadata: {
      ip: metadata.ip || '',
      userAgent: metadata.userAgent || '',
      service: 'backend-api',
      hostname: process.env.HOSTNAME || 'localhost',
      ...metadata
    }
  };

  try {
    // Topic adını event type'tan çıkar (domain.entity.action formatı)
    const topic = eventType.split('.')[0] + '.' + eventType.split('.')[1] || eventType;

    // Kafka'ya event gönder
    await producer.send({
      topic: topic,
      messages: [{
        key: payload.userId || payload.id || event.eventId,
        value: JSON.stringify(event),
        timestamp: Date.now().toString()
      }]
    });

    logger.info('📤 Event published', {
      eventType: eventType,
      topic: topic,
      eventId: event.eventId
    });

    // ✅ Metrics kaydı
    recordKafkaEventPublished(eventType, topic);

    return event;
  } catch (error) {
    logger.error('❌ Event publish failed', {
      eventType: eventType,
      error: error.message,
      stack: error.stack
    });
    
    // ✅ Metrics kaydı (hata)
    const topic = eventType.split('.')[0] + '.' + eventType.split('.')[1] || eventType;
    recordKafkaEventFailed(eventType, topic, error.name || 'unknown');
    
    throw error;
  }
};

// Fire-and-forget pattern (async, hata olsa da devam et)
const publishEventAsync = (eventType, payload, metadata = {}) => {
  setImmediate(async () => {
    try {
      await publishEvent(eventType, payload, metadata);
    } catch (error) {
      // Hata logla ama API response'u etkileme
      logger.error('❌ Async event publish failed (non-blocking)', {
        eventType: eventType,
        error: error.message
      });
    }
  });
};

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('⏹️  SIGTERM received, disconnecting Kafka producer...');
  await disconnect();
});

process.on('SIGINT', async () => {
  logger.info('⏹️  SIGINT received, disconnecting Kafka producer...');
  await disconnect();
});

module.exports = {
  connect,
  disconnect,
  publishEvent,
  publishEventAsync,
  isConnected: () => isConnected
};

