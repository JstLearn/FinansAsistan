// ════════════════════════════════════════════════════════════
// FinansAsistan - PostgreSQL Database Configuration
// Migrated from: MS SQL Server (mssql) → PostgreSQL (pg)
// Date: 2025-11-06
// ════════════════════════════════════════════════════════════

const { Pool } = require('pg');
const path = require("path");
// Try to load .env from ../bootstrap/.env first, then fallback to root .env
// Note: In Docker, environment variables are already set by Docker Compose, so dotenv is optional
try {
  require("dotenv").config({ path: path.join(__dirname, "../bootstrap/.env") });
} catch (e) {
  // If bootstrap/.env doesn't exist, try root .env
  try {
    require("dotenv").config({ path: path.join(__dirname, "../../.env") });
  } catch (e2) {
    // If neither exists, rely on environment variables set by Docker Compose
    console.log("ℹ️  No .env file found, using environment variables from Docker Compose");
  }
}
const { recordDatabaseQuery, recordDatabaseConnections } = require('../middleware/metricsMiddleware');

// Resolve credentials strictly from POSTGRES_* first, then DB_* (no hardcoded fallbacks)
const resolvedDbName = process.env.POSTGRES_DB || process.env.DB_NAME || process.env.DB_DATABASE;
const resolvedDbUser = process.env.POSTGRES_USER || process.env.DB_USER;
const resolvedDbPassword = process.env.POSTGRES_PASSWORD || process.env.DB_PASSWORD;

// Validate required database configuration
if (!resolvedDbName) {
  console.error('❌ Database name is not set!');
  console.error('   Please set POSTGRES_DB or DB_NAME environment variable');
  console.error('   Current env vars:', {
    POSTGRES_DB: process.env.POSTGRES_DB,
    DB_NAME: process.env.DB_NAME,
    DB_DATABASE: process.env.DB_DATABASE
  });
  throw new Error('Database name (POSTGRES_DB or DB_NAME) is required');
}

if (!resolvedDbUser) {
  console.error('❌ Database user is not set!');
  console.error('   Please set POSTGRES_USER or DB_USER environment variable');
  throw new Error('Database user (POSTGRES_USER or DB_USER) is required');
}

if (!resolvedDbPassword) {
  console.error('❌ Database password is not set!');
  console.error('   Please set POSTGRES_PASSWORD or DB_PASSWORD environment variable');
  throw new Error('Database password (POSTGRES_PASSWORD or DB_PASSWORD) is required');
}

// Database configuration
// Ensure database name is explicitly set (never use default/username)
if (!resolvedDbName || resolvedDbName.trim() === '') {
  console.error('❌ CRITICAL: Database name is empty or undefined!');
  console.error('   This will cause PostgreSQL to use username as database name');
  console.error('   Current resolvedDbName:', resolvedDbName);
  throw new Error('Database name cannot be empty - this prevents using username as database');
}

const dbConfig = {
  host: process.env.DB_HOST || 'postgres',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: resolvedDbName, // Explicitly set - never undefined
  user: resolvedDbUser,
  password: resolvedDbPassword,
  
  // Connection pool settings
  max: parseInt(process.env.DB_POOL_SIZE) || 20,
  min: 2,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
  
  // SSL configuration
  // Development'ta SSL kapalı, production'da açık (veya DB_SSL env var ile kontrol)
  ssl: process.env.DB_SSL === 'true' || (process.env.NODE_ENV === 'production' && process.env.DB_SSL !== 'false') ? {
    rejectUnauthorized: false
  } : false
};

// Final validation before creating pool
if (!dbConfig.database || dbConfig.database.trim() === '') {
  console.error('❌ CRITICAL ERROR: Database name is empty in dbConfig!');
  console.error('   dbConfig:', JSON.stringify(dbConfig, null, 2));
  console.error('   This would cause PostgreSQL to use username as database name');
  throw new Error('Database name cannot be empty in dbConfig');
}

// Config değerlerini kontrol et
console.log("✅ PostgreSQL Config:", {
  host: dbConfig.host,
  port: dbConfig.port,
  database: dbConfig.database,
  user: dbConfig.user,
  pool_size: dbConfig.max,
  ssl: dbConfig.ssl ? 'enabled' : 'disabled'
});

// Connection pool oluştur
const pool = new Pool(dbConfig);

// Event handlers
pool.on('connect', (client) => {
  console.log('✅ New PostgreSQL client connected');
  // ✅ Metrics kaydı - connection pool durumu
  updateConnectionMetrics();
});

pool.on('acquire', (client) => {
  // Client pool'dan alındı
  updateConnectionMetrics();
});

pool.on('error', (err, client) => {
  console.error('❌ Unexpected PostgreSQL error:', err);
  // Pool error'ları critical, process exit gerekebilir
  if (err.code === 'ECONNREFUSED') {
    console.error('❌ Database connection refused. Exiting...');
    process.exit(-1);
  }
});

pool.on('remove', (client) => {
  // Client pool'dan çıkarıldı
  updateConnectionMetrics();
});

// Connection metrics update function
const updateConnectionMetrics = async () => {
  try {
    // pg Pool'da connection stats için pool._totalCount ve pool._idleCount kullanılır
    // Ancak bu private property'ler, bu yüzden güvenli bir şekilde kontrol edelim
    const active = pool.totalCount !== undefined ? pool.totalCount - (pool.idleCount || 0) : 0;
    const idle = pool.idleCount !== undefined ? pool.idleCount : 0;
    recordDatabaseConnections(active, idle);
  } catch (error) {
    // Metrics kaydı başarısız olsa bile devam et
  }
};

// Health check function
const checkHealth = async () => {
  try {
    const result = await pool.query('SELECT NOW(), current_database(), current_user');
    return {
      healthy: true,
      timestamp: result.rows[0].now,
      database: result.rows[0].current_database,
      user: result.rows[0].current_user
    };
  } catch (error) {
    console.error('❌ Health check failed:', error);
    return {
      healthy: false,
      error: error.message
    };
  }
};

// Helper function: Simple query
const query = (text, params) => {
  const start = Date.now();
  const queryType = text.trim().substring(0, 6).toUpperCase(); // SELECT, INSERT, UPDATE, DELETE
  const tableMatch = text.match(/FROM\s+(\w+)|INTO\s+(\w+)|UPDATE\s+(\w+)/i);
  const table = tableMatch ? (tableMatch[1] || tableMatch[2] || tableMatch[3]) : 'unknown';
  
  return pool.query(text, params)
    .then(res => {
      const duration = (Date.now() - start) / 1000; // seconds
      if (duration > 1) {
        console.warn(`⚠️  Slow query (${duration}s):`, text.substring(0, 100));
      }
      
      // ✅ Metrics kaydı
      recordDatabaseQuery(queryType, table, duration);
      
      return res;
    })
    .catch(err => {
      console.error('❌ Query error:', err);
      console.error('Query:', text);
      console.error('Params:', params);
      throw err;
    });
};

// Helper function: Transaction
const transaction = async (callback) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const result = await callback(client);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK');
    console.error('❌ Transaction rolled back:', error);
    throw error;
  } finally {
    client.release();
  }
};

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('⏹️  SIGTERM received, closing database connections...');
  await pool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('⏹️  SIGINT received, closing database connections...');
  await pool.end();
  process.exit(0);
});

// Export
module.exports = {
  pool,
  query,
  transaction,
  checkHealth
};

// Initial connection test
(async () => {
  try {
    const health = await checkHealth();
    if (health.healthy) {
      console.log('✅ PostgreSQL connected successfully!');
      console.log(`   Database: ${health.database}`);
      console.log(`   User: ${health.user}`);
      console.log(`   Timestamp: ${health.timestamp}`);
    } else {
      console.error('❌ PostgreSQL health check failed!');
    }
  } catch (error) {
    console.error('❌ Initial connection test failed:', error.message);
    console.error('   Check your .env configuration');
  }
})();
