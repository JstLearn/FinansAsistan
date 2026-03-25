// ════════════════════════════════════════════════════════════
// FinansAsistan - PostgreSQL Database Configuration
// Migrated from: MS SQL Server (mssql) → PostgreSQL (pg)
// Date: 2025-11-06
// ════════════════════════════════════════════════════════════

const { Pool } = require('pg');
const path = require("path");
try {
  require("dotenv").config({ path: path.join(__dirname, "../../QUICK_START/.env") });
} catch (e) {
  try {
    require("dotenv").config({ path: path.join(__dirname, "../../.env") });
  } catch (e2) {
    console.log("ℹ️  No .env file found, using environment variables from Docker Compose");
  }
}
const { recordDatabaseQuery, recordDatabaseConnections } = require('../middleware/metricsMiddleware');

const resolvedDbName = process.env.POSTGRES_DB || process.env.DB_NAME || process.env.DB_DATABASE;
const resolvedDbUser = process.env.POSTGRES_USER || process.env.DB_USER;
const resolvedDbPassword = process.env.POSTGRES_PASSWORD || process.env.DB_PASSWORD;

if (!resolvedDbName) {
  console.error('❌ Database name is not set!');
  throw new Error('Database name (POSTGRES_DB or DB_NAME) is required');
}

if (!resolvedDbUser) {
  console.error('❌ Database user is not set!');
  throw new Error('Database user (POSTGRES_USER or DB_USER) is required');
}

if (!resolvedDbPassword) {
  console.error('❌ Database password is not set!');
  throw new Error('Database password (POSTGRES_PASSWORD or DB_PASSWORD) is required');
}

const dbConfig = {
  host: process.env.DB_HOST || 'postgres',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: resolvedDbName,
  user: resolvedDbUser,
  password: resolvedDbPassword,
  max: parseInt(process.env.DB_POOL_SIZE) || 20,
  min: 2,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 10000,
  ssl: process.env.DB_SSL === 'true' || (process.env.NODE_ENV === 'production' && process.env.DB_SSL !== 'false') ? {
    rejectUnauthorized: false
  } : false
};

console.log("✅ PostgreSQL Config:", {
  host: dbConfig.host,
  port: dbConfig.port,
  database: dbConfig.database,
  user: dbConfig.user,
  pool_size: dbConfig.max,
  ssl: dbConfig.ssl ? 'enabled' : 'disabled'
});

const pool = new Pool(dbConfig);

pool.on('connect', (client) => {
  console.log('✅ New PostgreSQL client connected');
  updateConnectionMetrics();
});

pool.on('acquire', (client) => {
  updateConnectionMetrics();
});

pool.on('error', (err, client) => {
  console.error('❌ Unexpected PostgreSQL error:', err);
  if (err.code === 'ECONNREFUSED') {
    console.error('❌ Database connection refused. Exiting...');
    process.exit(-1);
  }
});

pool.on('remove', (client) => {
  updateConnectionMetrics();
});

const updateConnectionMetrics = async () => {
  try {
    const active = pool.totalCount !== undefined ? pool.totalCount - (pool.idleCount || 0) : 0;
    const idle = pool.idleCount !== undefined ? pool.idleCount : 0;
    recordDatabaseConnections(active, idle);
  } catch (error) {
    // Metrics kaydı başarısız olsa bile devam et
  }
};

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

const query = (text, params) => {
  const start = Date.now();
  const queryType = text.trim().substring(0, 6).toUpperCase();
  const tableMatch = text.match(/FROM\s+(\w+)|INTO\s+(\w+)|UPDATE\s+(\w+)/i);
  const table = tableMatch ? (tableMatch[1] || tableMatch[2] || tableMatch[3]) : 'unknown';
  
  return pool.query(text, params)
    .then(res => {
      const duration = (Date.now() - start) / 1000;
      if (duration > 1) {
        console.warn(`⚠️  Slow query (${duration}s):`, text.substring(0, 100));
      }
      recordDatabaseQuery(queryType, table, duration);
      return res;
    })
    .catch(err => {
      console.error('❌ Query error:', err);
      throw err;
    });
};

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

module.exports = {
  pool,
  query,
  transaction,
  checkHealth
};

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
  }
})();
