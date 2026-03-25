// ════════════════════════════════════════════════════════════
// FinansAsistan - Notification Service
// Notification dispatch ve management
// ════════════════════════════════════════════════════════════

const logger = require('../../utils/logger');
const emailService = require('../email/emailService');
const { publishEventAsync } = require('../kafka/producer');
const { NOTIFICATION_TOPICS } = require('../kafka/topics');

// Notification service
const notificationService = {
  // Email notification gönder
  sendEmail: async (to, subject, html, metadata = {}) => {
    try {
      // Email gönder
      const result = await emailService.sendEmail(to, subject, html);
      
      // Event publish (async, non-blocking)
      publishEventAsync(NOTIFICATION_TOPICS.EMAIL_SENT, {
        to: to,
        subject: subject,
        messageId: result.messageId,
        sentAt: new Date().toISOString()
      }, metadata);

      return result;
    } catch (error) {
      // Failed event publish
      publishEventAsync(NOTIFICATION_TOPICS.EMAIL_FAILED, {
        to: to,
        subject: subject,
        error: error.message,
        failedAt: new Date().toISOString()
      }, metadata);

      throw error;
    }
  },

  // Verification email gönder
  sendVerificationEmail: async (to, verificationCode, metadata = {}) => {
    try {
      const result = await emailService.sendVerificationEmail(to, verificationCode);
      
      publishEventAsync(NOTIFICATION_TOPICS.EMAIL_SENT, {
        type: 'verification',
        to: to,
        messageId: result.messageId
      }, metadata);

      return result;
    } catch (error) {
      logger.error('❌ Verification email failed', { to, error: error.message });
      throw error;
    }
  },

  // Authorization email gönder
  sendAuthorizationEmail: async (to, yetkiVerenEmail, yetkiler, metadata = {}) => {
    try {
      const result = await emailService.sendAuthorizationEmail(to, yetkiVerenEmail, yetkiler);
      
      publishEventAsync(NOTIFICATION_TOPICS.EMAIL_SENT, {
        type: 'authorization',
        to: to,
        from: yetkiVerenEmail,
        messageId: result.messageId
      }, metadata);

      return result;
    } catch (error) {
      logger.error('❌ Authorization email failed', { to, error: error.message });
      throw error;
    }
  },

  // SMS notification (placeholder - future implementation)
  sendSMS: async (to, message, metadata = {}) => {
    logger.warn('⚠️  SMS notification not implemented yet', { to, message });
    
    // Event publish for future SMS service
    publishEventAsync(NOTIFICATION_TOPICS.SMS_REQUEST, {
      to: to,
      message: message,
      requestedAt: new Date().toISOString()
    }, metadata);

    return { success: false, message: 'SMS service not implemented' };
  },

  // Push notification (placeholder - future implementation)
  sendPush: async (userId, title, body, metadata = {}) => {
    logger.warn('⚠️  Push notification not implemented yet', { userId, title });
    
    // Event publish for future push service
    publishEventAsync(NOTIFICATION_TOPICS.PUSH_REQUEST, {
      userId: userId,
      title: title,
      body: body,
      requestedAt: new Date().toISOString()
    }, metadata);

    return { success: false, message: 'Push service not implemented' };
  }
};

module.exports = notificationService;

