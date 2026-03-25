// ════════════════════════════════════════════════════════════
// FinansAsistan - Event Processor Service
// Main entry point for Kafka event processing
// ════════════════════════════════════════════════════════════

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../../.env') });

const { startConsumer, stopConsumer, registerHandler } = require('./consumer');
const { 
  handleUserRegistered: handleNotificationUserRegistered,
  handleUserVerified: handleNotificationUserVerified,
  handleTransactionCreated: handleNotificationTransactionCreated,
  handlePasswordChanged: handleNotificationPasswordChanged
} = require('./handlers/notificationHandler');

const {
  handleUserRegistered: handleAnalyticsUserRegistered,
  handleUserLoggedIn: handleAnalyticsUserLoggedIn,
  handleTransactionCreated: handleAnalyticsTransactionCreated
} = require('./handlers/analyticsHandler');

const {
  handleUserAction: handleAuditUserAction,
  handleTransaction: handleAuditTransaction,
  handleSecurityEvent: handleAuditSecurityEvent
} = require('./handlers/auditHandler');

// Simple logger
const logger = {
  info: (...args) => console.log('[INFO]', ...args),
  warn: (...args) => console.warn('[WARN]', ...args),
  error: (...args) => console.error('[ERROR]', ...args),
  debug: (...args) => process.env.DEBUG && console.log('[DEBUG]', ...args)
};

// Topic definitions (can be moved to shared package)
const USER_TOPICS = {
  REGISTERED: 'user.registered',
  VERIFIED: 'user.verified',
  LOGGED_IN: 'user.logged_in',
  LOGGED_OUT: 'user.logged_out',
  PASSWORD_CHANGED: 'user.password_changed',
  PROFILE_UPDATED: 'user.profile_updated'
};

const TRANSACTION_TOPICS = {
  ASSET_CREATED: 'transaction.asset.created',
  ASSET_UPDATED: 'transaction.asset.updated',
  ASSET_DELETED: 'transaction.asset.deleted',
  INCOME_CREATED: 'transaction.income.created',
  INCOME_UPDATED: 'transaction.income.updated',
  INCOME_DELETED: 'transaction.income.deleted',
  EXPENSE_CREATED: 'transaction.expense.created',
  EXPENSE_UPDATED: 'transaction.expense.updated',
  EXPENSE_DELETED: 'transaction.expense.deleted',
  DEBT_CREATED: 'transaction.debt.created',
  DEBT_UPDATED: 'transaction.debt.updated',
  DEBT_DELETED: 'transaction.debt.deleted'
};

// Tüm topic'leri topla
const topics = [
  // User topics
  USER_TOPICS.REGISTERED,
  USER_TOPICS.VERIFIED,
  USER_TOPICS.LOGGED_IN,
  USER_TOPICS.LOGGED_OUT,
  USER_TOPICS.PASSWORD_CHANGED,
  USER_TOPICS.PROFILE_UPDATED,
  
  // Transaction topics
  TRANSACTION_TOPICS.ASSET_CREATED,
  TRANSACTION_TOPICS.ASSET_UPDATED,
  TRANSACTION_TOPICS.ASSET_DELETED,
  TRANSACTION_TOPICS.INCOME_CREATED,
  TRANSACTION_TOPICS.INCOME_UPDATED,
  TRANSACTION_TOPICS.INCOME_DELETED,
  TRANSACTION_TOPICS.EXPENSE_CREATED,
  TRANSACTION_TOPICS.EXPENSE_UPDATED,
  TRANSACTION_TOPICS.EXPENSE_DELETED,
  TRANSACTION_TOPICS.DEBT_CREATED,
  TRANSACTION_TOPICS.DEBT_UPDATED,
  TRANSACTION_TOPICS.DEBT_DELETED
];

// Event handler'ları kaydet
const registerHandlers = () => {
  // Notification handlers
  registerHandler(USER_TOPICS.REGISTERED, handleNotificationUserRegistered);
  registerHandler(USER_TOPICS.VERIFIED, handleNotificationUserVerified);
  registerHandler(USER_TOPICS.PASSWORD_CHANGED, handleNotificationPasswordChanged);
  
  // Transaction notification handlers
  registerHandler(TRANSACTION_TOPICS.ASSET_CREATED, handleNotificationTransactionCreated);
  registerHandler(TRANSACTION_TOPICS.INCOME_CREATED, handleNotificationTransactionCreated);
  registerHandler(TRANSACTION_TOPICS.EXPENSE_CREATED, handleNotificationTransactionCreated);
  registerHandler(TRANSACTION_TOPICS.DEBT_CREATED, handleNotificationTransactionCreated);

  // Analytics handlers
  registerHandler(USER_TOPICS.REGISTERED, handleAnalyticsUserRegistered);
  registerHandler(USER_TOPICS.LOGGED_IN, handleAnalyticsUserLoggedIn);
  registerHandler(TRANSACTION_TOPICS.ASSET_CREATED, handleAnalyticsTransactionCreated);
  registerHandler(TRANSACTION_TOPICS.INCOME_CREATED, handleAnalyticsTransactionCreated);
  registerHandler(TRANSACTION_TOPICS.EXPENSE_CREATED, handleAnalyticsTransactionCreated);
  registerHandler(TRANSACTION_TOPICS.DEBT_CREATED, handleAnalyticsTransactionCreated);

  // Audit handlers
  registerHandler(USER_TOPICS.REGISTERED, handleAuditUserAction);
  registerHandler(USER_TOPICS.VERIFIED, handleAuditUserAction);
  registerHandler(USER_TOPICS.LOGGED_IN, handleAuditSecurityEvent);
  registerHandler(USER_TOPICS.LOGGED_OUT, handleAuditSecurityEvent);
  registerHandler(USER_TOPICS.PASSWORD_CHANGED, handleAuditSecurityEvent);
  
  registerHandler(TRANSACTION_TOPICS.ASSET_CREATED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.ASSET_UPDATED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.ASSET_DELETED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.INCOME_CREATED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.INCOME_UPDATED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.INCOME_DELETED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.EXPENSE_CREATED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.EXPENSE_UPDATED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.EXPENSE_DELETED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.DEBT_CREATED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.DEBT_UPDATED, handleAuditTransaction);
  registerHandler(TRANSACTION_TOPICS.DEBT_DELETED, handleAuditTransaction);

  logger.info('✅ All event handlers registered');
};

// Service başlat
const start = async () => {
  try {
    logger.info('🚀 Starting Event Processor Service...');
    
    // Handler'ları kaydet
    registerHandlers();
    
    // Consumer'ı başlat
    await startConsumer(topics);
    
    logger.info('✅ Event Processor Service started successfully');
  } catch (error) {
    logger.error('❌ Event Processor Service start failed', {
      error: error.message,
      stack: error.stack
    });
    process.exit(1);
  }
};

// Service durdur
const stop = async () => {
  try {
    logger.info('⏹️  Stopping Event Processor Service...');
    await stopConsumer();
    logger.info('✅ Event Processor Service stopped');
  } catch (error) {
    logger.error('❌ Event Processor Service stop failed', {
      error: error.message
    });
  }
};

// Graceful shutdown
process.on('SIGTERM', async () => {
  logger.info('⏹️  SIGTERM received');
  await stop();
  process.exit(0);
});

process.on('SIGINT', async () => {
  logger.info('⏹️  SIGINT received');
  await stop();
  process.exit(0);
});

// Unhandled errors
process.on('unhandledRejection', (reason, promise) => {
  logger.error('❌ Unhandled Rejection', { reason, promise });
});

process.on('uncaughtException', (error) => {
  logger.error('❌ Uncaught Exception', { error: error.message, stack: error.stack });
  process.exit(1);
});

// Service'i başlat
if (require.main === module) {
  start();
}

module.exports = {
  start,
  stop
};

