// ════════════════════════════════════════════════════════════
// FinansAsistan - Email Service
// SMTP integration ve email gönderimi
// ════════════════════════════════════════════════════════════

const nodemailer = require('nodemailer');
const logger = require('../../utils/logger');
const { getAuthorizationEmail, getVerificationEmail } = require('../../utils/emailTemplates');

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

  const config = {
    host: smtpHost,
    port: smtpPort,
    secure: smtpSecure,
    auth: { user: emailUser, pass: emailPass },
    tls: { rejectUnauthorized: process.env.NODE_ENV === 'production' }
  };

  if (!smtpSecure && smtpPort === 587) config.requireTLS = true;
  return nodemailer.createTransport(config);
}

function getTransporter() { return createTransporter(); }

const sendEmail = async (to, subject, html, text = null) => {
  try {
    const mailOptions = {
      from: `"FinansAsistan" <${process.env.EMAIL_USER || process.env.SMTP_USER}>`,
      to,
      subject,
      html,
      text: text || html.replace(/<[^>]*>/g, '')
    };

    const info = await getTransporter().sendMail(mailOptions);
    logger.info('✅ Email sent', { to, subject, messageId: info.messageId });
    return { success: true, messageId: info.messageId };
  } catch (error) {
    logger.error('❌ Email send failed', { to, subject, error: error.message });
    throw error;
  }
};

const emailService = {
  sendVerificationEmail: async (to, verificationCode) => {
    const html = getVerificationEmail(verificationCode);
    return await sendEmail(to, 'FinansAsistan - Hesap Doğrulama', html);
  },

  sendAuthorizationEmail: async (to, yetkiVerenEmail, yetkiler) => {
    const html = getAuthorizationEmail(yetkiVerenEmail, to, yetkiler);
    return await sendEmail(to, 'FinansAsistan - Yetkilendirme Bildirimi', html);
  },

  sendEmail: async (to, subject, html, text = null) => {
    return await sendEmail(to, subject, html, text);
  },

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
