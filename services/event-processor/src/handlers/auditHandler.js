// ════════════════════════════════════════════════════════════
// FinansAsistan - Audit Handler
// Kafka event'lerini audit log olarak kaydeder
// ════════════════════════════════════════════════════════════

// Simple logger
const logger = {
  info: (...args) => console.log('[INFO]', ...args),
  warn: (...args) => console.warn('[WARN]', ...args),
  error: (...args) => console.error('[ERROR]', ...args),
  debug: (...args) => process.env.DEBUG && console.log('[DEBUG]', ...args)
};

// In-memory audit log (production'da database veya S3'e kaydedilmeli)
const auditLogs = [];

// Maximum log size (memory protection)
const MAX_LOG_SIZE = 10000;

// Audit log kaydet
const logAuditEvent = (event) => {
  try {
    const auditEntry = {
      eventId: event.eventId,
      eventType: event.eventType,
      timestamp: event.timestamp,
      correlationId: event.correlationId,
      userId: event.payload?.kullanici || event.payload?.userId || event.metadata?.userId,
      ip: event.metadata?.ip,
      userAgent: event.metadata?.userAgent,
      service: event.metadata?.service,
      payload: {
        // Hassas bilgileri filtrele
        id: event.payload?.id,
        kullanici: event.payload?.kullanici || event.payload?.userId,
        // Şifre, token gibi hassas bilgileri kaydetme
      }
    };

    auditLogs.push(auditEntry);

    // Memory protection - eski log'ları temizle
    if (auditLogs.length > MAX_LOG_SIZE) {
      auditLogs.shift(); // En eski log'u sil
    }

    logger.info('📋 Audit log recorded', {
      eventType: event.eventType,
      eventId: event.eventId,
      userId: auditEntry.userId
    });
  } catch (error) {
    logger.error('❌ Audit log failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// User action audit
const handleUserAction = async (event) => {
  try {
    const { eventType } = event;
    
    // User ile ilgili tüm event'leri audit log'a kaydet
    if (eventType.startsWith('user.')) {
      logAuditEvent(event);
    }

    logger.debug('📋 User action audited', {
      eventType,
      eventId: event.eventId
    });
  } catch (error) {
    logger.error('❌ User action audit failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// Transaction audit
const handleTransaction = async (event) => {
  try {
    const { eventType } = event;
    
    // Transaction ile ilgili tüm event'leri audit log'a kaydet
    if (eventType.startsWith('transaction.')) {
      logAuditEvent(event);
    }

    logger.debug('📋 Transaction audited', {
      eventType,
      eventId: event.eventId
    });
  } catch (error) {
    logger.error('❌ Transaction audit failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// Security event audit
const handleSecurityEvent = async (event) => {
  try {
    const { eventType } = event;
    
    // Security ile ilgili event'leri audit log'a kaydet
    const securityEvents = [
      'user.password_changed',
      'user.logged_in',
      'user.logged_out'
    ];

    if (securityEvents.includes(eventType)) {
      logAuditEvent(event);
      
      // Security event'leri özel olarak logla
      logger.warn('🔒 Security event audited', {
        eventType,
        eventId: event.eventId,
        userId: event.payload?.kullanici || event.payload?.userId,
        ip: event.metadata?.ip
      });
    }
  } catch (error) {
    logger.error('❌ Security event audit failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// Audit log'ları getir
const getAuditLogs = (limit = 100) => {
  return auditLogs.slice(-limit).reverse(); // En yeni log'lar önce
};

// Audit log'ları temizle (test için)
const clearAuditLogs = () => {
  auditLogs.length = 0;
};

module.exports = {
  handleUserAction,
  handleTransaction,
  handleSecurityEvent,
  getAuditLogs,
  clearAuditLogs
};

