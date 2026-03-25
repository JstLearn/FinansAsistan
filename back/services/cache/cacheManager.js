// ════════════════════════════════════════════════════════════
// FinansAsistan - Redis Cache Manager
// Cache operations ve invalidation logic
// ════════════════════════════════════════════════════════════

const Redis = require('ioredis');
const logger = require('../../utils/logger');

// Redis configuration
const redisConfig = {
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT) || 6379,
  password: process.env.REDIS_PASSWORD || undefined,
  db: parseInt(process.env.REDIS_DB) || 0,
  retryStrategy: (times) => {
    const delay = Math.min(times * 50, 2000);
    return delay;
  },
  maxRetriesPerRequest: 3,
  enableReadyCheck: true,
  lazyConnect: true
};

// Redis client oluştur
const redis = new Redis(redisConfig);

// Connection event handlers
redis.on('connect', () => {
  logger.info('✅ Redis client connected');
});

redis.on('ready', () => {
  logger.info('✅ Redis client ready');
});

redis.on('error', (error) => {
  logger.error('❌ Redis client error', { error: error.message });
});

redis.on('close', () => {
  logger.warn('⚠️  Redis client connection closed');
});

// Cache key prefix
const CACHE_PREFIX = 'finans:';

// Cache key builder
const buildKey = (key) => {
  return `${CACHE_PREFIX}${key}`;
};

// Cache operations
const cacheManager = {
  // Get value from cache
  get: async (key) => {
    try {
      const value = await redis.get(buildKey(key));
      if (value) {
        return JSON.parse(value);
      }
      return null;
    } catch (error) {
      logger.error('❌ Cache get error', { key, error: error.message });
      return null;
    }
  },

  // Set value in cache
  set: async (key, value, ttlSeconds = 3600) => {
    try {
      const serialized = JSON.stringify(value);
      await redis.setex(buildKey(key), ttlSeconds, serialized);
      return true;
    } catch (error) {
      logger.error('❌ Cache set error', { key, error: error.message });
      return false;
    }
  },

  // Delete key from cache
  delete: async (key) => {
    try {
      await redis.del(buildKey(key));
      return true;
    } catch (error) {
      logger.error('❌ Cache delete error', { key, error: error.message });
      return false;
    }
  },

  // Delete multiple keys (pattern)
  deletePattern: async (pattern) => {
    try {
      const keys = await redis.keys(buildKey(pattern));
      if (keys.length > 0) {
        await redis.del(...keys);
      }
      return keys.length;
    } catch (error) {
      logger.error('❌ Cache delete pattern error', { pattern, error: error.message });
      return 0;
    }
  },

  // Check if key exists
  exists: async (key) => {
    try {
      const result = await redis.exists(buildKey(key));
      return result === 1;
    } catch (error) {
      logger.error('❌ Cache exists error', { key, error: error.message });
      return false;
    }
  },

  // Get TTL
  ttl: async (key) => {
    try {
      return await redis.ttl(buildKey(key));
    } catch (error) {
      logger.error('❌ Cache TTL error', { key, error: error.message });
      return -1;
    }
  },

  // Increment counter
  increment: async (key, by = 1) => {
    try {
      return await redis.incrby(buildKey(key), by);
    } catch (error) {
      logger.error('❌ Cache increment error', { key, error: error.message });
      return null;
    }
  },

  // Decrement counter
  decrement: async (key, by = 1) => {
    try {
      return await redis.decrby(buildKey(key), by);
    } catch (error) {
      logger.error('❌ Cache decrement error', { key, error: error.message });
      return null;
    }
  }
};

// Cache invalidation patterns
const invalidation = {
  // User cache invalidation
  invalidateUser: async (userId) => {
    await cacheManager.deletePattern(`user:${userId}:*`);
    await cacheManager.delete(`user:${userId}`);
  },

  // Asset cache invalidation
  invalidateAsset: async (userId, assetId) => {
    await cacheManager.delete(`asset:${assetId}`);
    await cacheManager.deletePattern(`user:${userId}:assets:*`);
  },

  // Income cache invalidation
  invalidateIncome: async (userId, incomeId) => {
    await cacheManager.delete(`income:${incomeId}`);
    await cacheManager.deletePattern(`user:${userId}:income:*`);
  },

  // Expense cache invalidation
  invalidateExpense: async (userId, expenseId) => {
    await cacheManager.delete(`expense:${expenseId}`);
    await cacheManager.deletePattern(`user:${userId}:expense:*`);
  },

  // Debt cache invalidation
  invalidateDebt: async (userId, debtId) => {
    await cacheManager.delete(`debt:${debtId}`);
    await cacheManager.deletePattern(`user:${userId}:debt:*`);
  },

  // Clear all user-related cache
  invalidateUserAll: async (userId) => {
    await cacheManager.deletePattern(`user:${userId}:*`);
    await cacheManager.deletePattern(`asset:*:user:${userId}*`);
    await cacheManager.deletePattern(`income:*:user:${userId}*`);
    await cacheManager.deletePattern(`expense:*:user:${userId}*`);
    await cacheManager.deletePattern(`debt:*:user:${userId}*`);
  }
};

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('⏹️  SIGTERM received, disconnecting Redis...');
  await redis.quit();
});

process.on('SIGINT', async () => {
  logger.info('⏹️  SIGINT received, disconnecting Redis...');
  await redis.quit();
});

module.exports = {
  redis,
  cacheManager,
  invalidation
};

