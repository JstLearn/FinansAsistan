// ════════════════════════════════════════════════════════════
// FinansAsistan - Email Service
// SMTP integration ve email gönderimi
// ════════════════════════════════════════════════════════════

const nodemailer = require('nodemailer');
const logger = require('../../utils/logger');
const { getAuthorizationEmail, getVerificationEmail } = require('../../utils/emailTemplates');

// SMTP transporter oluştur (her çağrıda fresh env değerleri almak için fonksiyon)
function createTransporter() {
  const smtpHost = process.env.SMTP_HOST || process.env.EMAIL_HOST;
  const smtpPort = process.env.SMTP_PORT
    ? parseInt(process.env.SMTP_PORT, 10)
    : process.env.EMAIL_PORT
      ? parseInt(process.env.EMAIL_PORT, 10)
      : undefined;
  const smtpSecureEnv = process.env.SMTP_SSL;
  const smtpSecure = smtpSecureEnv
    ? ['true', '1', 'yes'].includes(String(smtpSecureEnv).toLowerCase())
    : false;
  const emailUser = process.env.EMAIL_USER || process.env.SMTP_USER;
  const emailPass = process.env.EMAIL_PASS || process.env.SMTP_PASS || process.env.SMTP_PASSWORD;

  // DEBUG: Kullanılan değerleri log'la
  logger.info('🔧 SMTP Config (emailService)', {
    host: smtpHost,
    port: smtpPort,
    secure: smtpSecure,
    user: emailUser ? emailUser.substring(0, 5) + '...' : 'MISSING'
  });

  if (!smtpHost) {
    logger.error('❌ SMTP_HOST veya EMAIL_HOST env değişkeni tanımlı değil!');
  }

  const config = {
    host: smtpHost,
    port: smtpPort,
    secure: smtpSecure,
    auth: {
      user: emailUser,
      pass: emailPass
    },
    tls: {
      // Production'da TLS sertifikası doğrulansın, development'ta gevşek ol
      rejectUnauthorized: process.env.NODE_ENV === 'production'
    }
  };

  // STARTTLS için (port 587, secure: false) - SSL portları (465, 993) için gerekli değil
  if (!smtpSecure && smtpPort === 587) {
    config.requireTLS = true;
  }

  return nodemailer.createTransport(config);
}

// Her mail gönderme işleminde fresh transporter oluştur
function getTransporter() {
  return createTransporter();
}

// Email gönderme fonksiyonu
const sendEmail = async (to, subject, html, text = null) => {
  try {
    const mailOptions = {
      from: `"FinansAsistan" <${process.env.EMAIL_USER || process.env.SMTP_USER}>`,
      to: to,
      subject: subject,
      html: html,
      text: text || html.replace(/<[^>]*>/g, '') // HTML'den text çıkar
    };

    const info = await getTransporter().sendMail(mailOptions);
    
    logger.info('✅ Email sent', {
      to: to,
      subject: subject,
      messageId: info.messageId
    });

    return {
      success: true,
      messageId: info.messageId
    };
  } catch (error) {
    logger.error('❌ Email send failed', {
      to: to,
      subject: subject,
      error: error.message
    });
    throw error;
  }
};

// Email service methods
const emailService = {
  // Verification email gönder
  sendVerificationEmail: async (to, verificationCode) => {
    const html = getVerificationEmail(verificationCode);
    return await sendEmail(to, 'FinansAsistan - Hesap Doğrulama', html);
  },

  // Authorization email gönder
  sendAuthorizationEmail: async (to, yetkiVerenEmail, yetkiler) => {
    const html = getAuthorizationEmail(yetkiVerenEmail, to, yetkiler);
    return await sendEmail(to, 'FinansAsistan - Yetkilendirme Bildirimi', html);
  },

  // Generic email gönder
  sendEmail: async (to, subject, html, text = null) => {
    return await sendEmail(to, subject, html, text);
  },

  // Email gönderimi test et
  verifyConnection: async () => {
    try {
      await getTransporter().verify();
      logger.info('✅ SMTP connection verified');
      return true;
    } catch (error) {
      logger.error('❌ SMTP connection verification failed', { error: error.message });
      return false;
    }
  }
};

module.exports = emailService;

