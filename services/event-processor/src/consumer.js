// ════════════════════════════════════════════════════════════
// FinansAsistan - Kafka Consumer Service
// Event-driven architecture için Kafka event consumer
// ════════════════════════════════════════════════════════════

const { Kafka } = require('kafkajs');

// Simple logger
const logger = {
  info: (...args) => console.log('[INFO]', ...args),
  warn: (...args) => console.warn('[WARN]', ...args),
  error: (...args) => console.error('[ERROR]', ...args),
  debug: (...args) => process.env.DEBUG && console.log('[DEBUG]', ...args)
};

// Kafka configuration
const kafkaConfig = {
  clientId: process.env.KAFKA_CLIENT_ID || 'event-processor',
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

// Consumer group
const CONSUMER_GROUP_ID = process.env.KAFKA_CONSUMER_GROUP || 'event-processor-group';

// Consumer instance
let consumer = null;
let isRunning = false;

// Event handlers
const handlers = new Map();

// Handler kaydet
const registerHandler = (eventType, handler) => {
  if (typeof handler !== 'function') {
    throw new Error(`Handler for ${eventType} must be a function`);
  }
  handlers.set(eventType, handler);
  logger.info(`📝 Handler registered for event: ${eventType}`);
};

// Consumer başlat
const startConsumer = async (topics) => {
  if (isRunning) {
    logger.warn('⚠️  Consumer already running');
    return;
  }

  try {
    consumer = kafka.consumer({
      groupId: CONSUMER_GROUP_ID,
      sessionTimeout: 30000,
      heartbeatInterval: 3000,
      maxBytesPerPartition: 1048576, // 1MB
      retry: {
        initialRetryTime: 100,
        retries: 8,
        multiplier: 2,
        maxRetryTime: 30000
      }
    });

    await consumer.connect();
    logger.info('✅ Kafka consumer connected', { 
      groupId: CONSUMER_GROUP_ID,
      brokers: kafkaConfig.brokers 
    });

    // Topic'lere subscribe ol
    await consumer.subscribe({ 
      topics: topics,
      fromBeginning: false // Sadece yeni mesajları al
    });

    // Consumer run
    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const event = JSON.parse(message.value.toString());
          
          logger.debug('📨 Event received', {
            topic,
            partition,
            eventType: event.eventType,
            eventId: event.eventId
          });

          // Event handler'ı bul
          const handler = handlers.get(event.eventType);
          
          if (handler) {
            // Handler'ı çalıştır
            await handler(event);
            
            logger.debug('✅ Event processed', {
              eventType: event.eventType,
              eventId: event.eventId
            });
          } else {
            logger.warn('⚠️  No handler found for event', {
              eventType: event.eventType,
              eventId: event.eventId
            });
          }
        } catch (error) {
          logger.error('❌ Event processing failed', {
            topic,
            partition,
            offset: message.offset,
            error: error.message,
            stack: error.stack
          });

          // Dead Letter Queue (DLQ) için burada retry logic veya DLQ'ya gönderme yapılabilir
          // Şimdilik sadece logluyoruz
        }
      },
      eachBatch: async ({ batch }) => {
        // Batch processing için (opsiyonel)
        // Şimdilik her mesajı tek tek işliyoruz
      }
    });

    isRunning = true;
    logger.info('✅ Consumer started', { topics });
  } catch (error) {
    logger.error('❌ Consumer start failed', { error: error.message });
    throw error;
  }
};

// Consumer durdur
const stopConsumer = async () => {
  if (!isRunning || !consumer) {
    return;
  }

  try {
    await consumer.disconnect();
    isRunning = false;
    logger.info('⏹️  Consumer stopped');
  } catch (error) {
    logger.error('❌ Consumer stop failed', { error: error.message });
    throw error;
  }
};

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('⏹️  SIGTERM received, stopping consumer...');
  await stopConsumer();
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('⏹️  SIGINT received, stopping consumer...');
  await stopConsumer();
  process.exit(0);
});

module.exports = {
  startConsumer,
  stopConsumer,
  registerHandler,
  isRunning: () => isRunning
};

