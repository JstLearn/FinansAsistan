// ════════════════════════════════════════════════════════════
// FinansAsistan - Kafka Producer Service
// Event-driven architecture için Kafka event publisher
// ════════════════════════════════════════════════════════════

const { Kafka } = require('kafkajs');
const { v4: uuidv4 } = require('uuid');
const { logger } = require('../../utils/logger');
const { recordKafkaEventPublished, recordKafkaEventFailed } = require('../../middleware/metricsMiddleware');

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

const kafka = new Kafka(kafkaConfig);
const producer = kafka.producer();
let isConnected = false;

const connect = async () => {
  if (isConnected) return;
  try {
    await producer.connect();
    isConnected = true;
    logger.info('✅ Kafka producer connected', { brokers: kafkaConfig.brokers });
  } catch (error) {
    logger.error('❌ Kafka producer connection failed', { error: error.message });
    throw error;
  }
};

const disconnect = async () => {
  if (!isConnected) return;
  try {
    await producer.disconnect();
    isConnected = false;
    logger.info('⏹️  Kafka producer disconnected');
  } catch (error) {
    logger.error('❌ Kafka producer disconnect failed', { error: error.message });
  }
};

const validateEvent = (eventType, payload) => {
  if (!eventType || typeof eventType !== 'string') throw new Error('Event type is required and must be a string');
  if (!payload || typeof payload !== 'object') throw new Error('Payload is required and must be an object');
};

const publishEvent = async (eventType, payload, metadata = {}) => {
  if (!isConnected) await connect();
  validateEvent(eventType, payload);

  const event = {
    eventId: uuidv4(),
    eventType,
    timestamp: new Date().toISOString(),
    version: '1.0',
    correlationId: metadata.correlationId || uuidv4(),
    payload,
    metadata: {
      ip: metadata.ip || '',
      userAgent: metadata.userAgent || '',
      service: 'backend-api',
      hostname: process.env.HOSTNAME || 'localhost',
      ...metadata
    }
  };

  try {
    const topic = eventType.split('.')[0] + '.' + eventType.split('.')[1] || eventType;
    await producer.send({
      topic,
      messages: [{
        key: String(payload.userId || payload.id || event.eventId),
        value: JSON.stringify(event),
        timestamp: Date.now().toString()
      }]
    });

    logger.info('📤 Event published', { eventType, topic, eventId: event.eventId });
    recordKafkaEventPublished(eventType, topic);
    return event;
  } catch (error) {
    logger.error('❌ Event publish failed', { eventType, error: error.message });
    const topic = eventType.split('.')[0] + '.' + eventType.split('.')[1] || eventType;
    recordKafkaEventFailed(eventType, topic, error.name || 'unknown');
    throw error;
  }
};

const publishEventAsync = (eventType, payload, metadata = {}) => {
  setImmediate(async () => {
    try {
      await publishEvent(eventType, payload, metadata);
    } catch (error) {
      logger.error('❌ Async event publish failed (non-blocking)', { eventType, error: error.message });
    }
  });
};

process.on('SIGTERM', async () => { await disconnect(); });
process.on('SIGINT', async () => { await disconnect(); });

module.exports = { connect, disconnect, publishEvent, publishEventAsync, isConnected: () => isConnected };
