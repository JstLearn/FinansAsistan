// ════════════════════════════════════════════════════════════
// FinansAsistan - Kafka Topics Definitions
// Tüm Kafka topic isimleri ve konfigürasyonları
// ════════════════════════════════════════════════════════════

// Topic naming convention: <domain>.<entity>.<action>

// User Domain Topics
const USER_TOPICS = {
  REGISTERED: 'user.registered',
  VERIFIED: 'user.verified',
  LOGGED_IN: 'user.logged_in',
  LOGGED_OUT: 'user.logged_out',
  PASSWORD_CHANGED: 'user.password_changed',
  PROFILE_UPDATED: 'user.profile_updated'
};

// Transaction Domain Topics
const TRANSACTION_TOPICS = {
  // Asset events
  ASSET_CREATED: 'transaction.asset.created',
  ASSET_UPDATED: 'transaction.asset.updated',
  ASSET_DELETED: 'transaction.asset.deleted',
  
  // Income events
  INCOME_CREATED: 'transaction.income.created',
  INCOME_UPDATED: 'transaction.income.updated',
  INCOME_DELETED: 'transaction.income.deleted',
  
  // Expense events
  EXPENSE_CREATED: 'transaction.expense.created',
  EXPENSE_UPDATED: 'transaction.expense.updated',
  EXPENSE_DELETED: 'transaction.expense.deleted',
  
  // Debt events
  DEBT_CREATED: 'transaction.debt.created',
  DEBT_UPDATED: 'transaction.debt.updated',
  DEBT_DELETED: 'transaction.debt.deleted'
};

// Notification Domain Topics
const NOTIFICATION_TOPICS = {
  EMAIL_REQUEST: 'notification.email.request',
  EMAIL_SENT: 'notification.email.sent',
  EMAIL_FAILED: 'notification.email.failed',
  SMS_REQUEST: 'notification.sms.request',
  PUSH_REQUEST: 'notification.push.request'
};

// Analytics Domain Topics
const ANALYTICS_TOPICS = {
  USER_ACTION: 'analytics.user.action',
  PAGE_VIEW: 'analytics.page.view',
  PERFORMANCE_METRIC: 'analytics.performance.metric'
};

// Audit Domain Topics
const AUDIT_TOPICS = {
  USER_ACTION: 'audit.user.action',
  SYSTEM_EVENT: 'audit.system.event',
  SECURITY_EVENT: 'audit.security.event'
};

// Tüm topic'leri birleştir
const TOPICS = {
  ...USER_TOPICS,
  ...TRANSACTION_TOPICS,
  ...NOTIFICATION_TOPICS,
  ...ANALYTICS_TOPICS,
  ...AUDIT_TOPICS
};

// Topic konfigürasyonları (Kafka cluster'da oluşturulacak)
const TOPIC_CONFIGS = {
  // User topics - 6 partitions, 3 replication
  [USER_TOPICS.REGISTERED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [USER_TOPICS.VERIFIED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [USER_TOPICS.LOGGED_IN]: { partitions: 12, replicationFactor: 3, retentionDays: 7 },
  [USER_TOPICS.LOGGED_OUT]: { partitions: 6, replicationFactor: 3, retentionDays: 7 },
  [USER_TOPICS.PASSWORD_CHANGED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [USER_TOPICS.PROFILE_UPDATED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  
  // Transaction topics - 6 partitions, 3 replication
  [TRANSACTION_TOPICS.ASSET_CREATED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.ASSET_UPDATED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.ASSET_DELETED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.INCOME_CREATED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.INCOME_UPDATED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.INCOME_DELETED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.EXPENSE_CREATED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.EXPENSE_UPDATED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.EXPENSE_DELETED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.DEBT_CREATED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.DEBT_UPDATED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  [TRANSACTION_TOPICS.DEBT_DELETED]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  
  // Notification topics - 6 partitions, 3 replication
  [NOTIFICATION_TOPICS.EMAIL_REQUEST]: { partitions: 6, replicationFactor: 3, retentionDays: 7 },
  [NOTIFICATION_TOPICS.EMAIL_SENT]: { partitions: 6, replicationFactor: 3, retentionDays: 7 },
  [NOTIFICATION_TOPICS.EMAIL_FAILED]: { partitions: 6, replicationFactor: 3, retentionDays: 7 },
  [NOTIFICATION_TOPICS.SMS_REQUEST]: { partitions: 6, replicationFactor: 3, retentionDays: 7 },
  [NOTIFICATION_TOPICS.PUSH_REQUEST]: { partitions: 6, replicationFactor: 3, retentionDays: 7 },
  
  // Analytics topics - 12 partitions, 3 replication (high volume)
  [ANALYTICS_TOPICS.USER_ACTION]: { partitions: 12, replicationFactor: 3, retentionDays: 30 },
  [ANALYTICS_TOPICS.PAGE_VIEW]: { partitions: 12, replicationFactor: 3, retentionDays: 30 },
  [ANALYTICS_TOPICS.PERFORMANCE_METRIC]: { partitions: 6, replicationFactor: 3, retentionDays: 90 },
  
  // Audit topics - 6 partitions, 3 replication
  [AUDIT_TOPICS.USER_ACTION]: { partitions: 6, replicationFactor: 3, retentionDays: 365 },
  [AUDIT_TOPICS.SYSTEM_EVENT]: { partitions: 6, replicationFactor: 3, retentionDays: 365 },
  [AUDIT_TOPICS.SECURITY_EVENT]: { partitions: 6, replicationFactor: 3, retentionDays: 365 }
};

module.exports = {
  TOPICS,
  USER_TOPICS,
  TRANSACTION_TOPICS,
  NOTIFICATION_TOPICS,
  ANALYTICS_TOPICS,
  AUDIT_TOPICS,
  TOPIC_CONFIGS
};

