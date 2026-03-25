// ════════════════════════════════════════════════════════════
// FinansAsistan - Analytics Handler
// Kafka event'lerini analiz edip metrikleri toplar
// ════════════════════════════════════════════════════════════

// Simple logger
const logger = {
  info: (...args) => console.log('[INFO]', ...args),
  warn: (...args) => console.warn('[WARN]', ...args),
  error: (...args) => console.error('[ERROR]', ...args),
  debug: (...args) => process.env.DEBUG && console.log('[DEBUG]', ...args)
};

// In-memory analytics store (production'da Redis veya database kullanılmalı)
const analyticsStore = {
  userRegistrations: new Map(),
  userLogins: new Map(),
  transactions: {
    assets: 0,
    income: 0,
    expenses: 0,
    debts: 0
  },
  dailyActivity: new Map()
};

// User Registered analytics
const handleUserRegistered = async (event) => {
  try {
    const { payload, timestamp } = event;
    const date = new Date(timestamp).toISOString().split('T')[0];
    
    // Günlük kayıt sayısını artır
    const count = analyticsStore.userRegistrations.get(date) || 0;
    analyticsStore.userRegistrations.set(date, count + 1);

    logger.debug('📊 User registration analytics', {
      date,
      totalToday: count + 1,
      eventId: event.eventId
    });
  } catch (error) {
    logger.error('❌ User registered analytics failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// User Logged In analytics
const handleUserLoggedIn = async (event) => {
  try {
    const { payload, timestamp } = event;
    const userId = payload.id || payload.userId;
    const date = new Date(timestamp).toISOString().split('T')[0];
    
    // Kullanıcı login sayısını artır
    const userLogins = analyticsStore.userLogins.get(userId) || 0;
    analyticsStore.userLogins.set(userId, userLogins + 1);

    // Günlük aktif kullanıcı sayısını artır
    const dailyActive = analyticsStore.dailyActivity.get(date) || new Set();
    dailyActive.add(userId);
    analyticsStore.dailyActivity.set(date, dailyActive);

    logger.debug('📊 User login analytics', {
      userId,
      loginCount: userLogins + 1,
      date,
      eventId: event.eventId
    });
  } catch (error) {
    logger.error('❌ User logged in analytics failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// Transaction Created analytics
const handleTransactionCreated = async (event) => {
  try {
    const { eventType, payload, timestamp } = event;
    const date = new Date(timestamp).toISOString().split('T')[0];
    
    // Transaction tipine göre sayacı artır
    if (eventType.includes('asset')) {
      analyticsStore.transactions.assets++;
    } else if (eventType.includes('income')) {
      analyticsStore.transactions.income++;
    } else if (eventType.includes('expense')) {
      analyticsStore.transactions.expenses++;
    } else if (eventType.includes('debt')) {
      analyticsStore.transactions.debts++;
    }

    logger.debug('📊 Transaction analytics', {
      eventType,
      totalAssets: analyticsStore.transactions.assets,
      totalIncome: analyticsStore.transactions.income,
      totalExpenses: analyticsStore.transactions.expenses,
      totalDebts: analyticsStore.transactions.debts,
      eventId: event.eventId
    });
  } catch (error) {
    logger.error('❌ Transaction analytics failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// Analytics metriklerini getir
const getAnalytics = () => {
  return {
    userRegistrations: Object.fromEntries(analyticsStore.userRegistrations),
    userLogins: Object.fromEntries(analyticsStore.userLogins),
    transactions: analyticsStore.transactions,
    dailyActiveUsers: Object.fromEntries(
      Array.from(analyticsStore.dailyActivity.entries()).map(([date, users]) => [
        date,
        users.size
      ])
    )
  };
};

// Analytics'i sıfırla (test için)
const resetAnalytics = () => {
  analyticsStore.userRegistrations.clear();
  analyticsStore.userLogins.clear();
  analyticsStore.transactions = {
    assets: 0,
    income: 0,
    expenses: 0,
    debts: 0
  };
  analyticsStore.dailyActivity.clear();
};

module.exports = {
  handleUserRegistered,
  handleUserLoggedIn,
  handleTransactionCreated,
  getAnalytics,
  resetAnalytics
};

