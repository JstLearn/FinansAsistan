// ════════════════════════════════════════════════════════════
// FinansAsistan - Notification Handler
// Kafka event'lerini dinleyip bildirim gönderir
// ════════════════════════════════════════════════════════════

const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '../../../.env') });

const nodemailer = require('nodemailer');

// Simple logger
const logger = {
  info: (...args) => console.log('[INFO]', ...args),
  warn: (...args) => console.warn('[WARN]', ...args),
  error: (...args) => console.error('[ERROR]', ...args),
  debug: (...args) => process.env.DEBUG && console.log('[DEBUG]', ...args)
};

// Simple email template (can be replaced with proper template)
const getVerificationEmail = (code) => {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h1 style="color: #007bff;">Hesap Doğrulama</h1>
      <p>Doğrulama kodunuz:</p>
      <h1 style="color: #007bff; font-size: 32px; letter-spacing: 5px; margin: 20px 0;">${code}</h1>
      <p>Bu kodu kullanarak hesabınızı doğrulayabilirsiniz.</p>
    </div>
  `;
};

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
  const emailUser = process.env.EMAIL_USER;
  const emailPass = process.env.EMAIL_PASS || process.env.EMAIL_PASSWORD;

  // DEBUG: Kullanılan değerleri log'la
  logger.info('🔧 SMTP Config (notificationHandler)', {
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

// Email gönderme helper
const sendEmail = async (to, subject, html) => {
  try {
    const mailOptions = {
      from: `"FinansAsistan" <${process.env.EMAIL_USER}>`,
      to: to,
      subject: subject,
      html: html
    };

    const info = await getTransporter().sendMail(mailOptions);
    
    logger.info('✅ Notification email sent', {
      to: to,
      subject: subject,
      messageId: info.messageId
    });

    return { success: true, messageId: info.messageId };
  } catch (error) {
    logger.error('❌ Notification email failed', {
      to: to,
      subject: subject,
      error: error.message
    });
    throw error;
  }
};

// User Registered handler
const handleUserRegistered = async (event) => {
  try {
    const { payload } = event;
    const email = payload.kullanici || payload.userId;
    const verificationCode = payload.verification_token || payload.verificationToken;

    if (!email || !verificationCode) {
      logger.warn('⚠️  Missing email or verification code', { payload });
      return;
    }

    // Verification email gönder (eğer backend'de gönderilmediyse)
    // Backend'de zaten gönderiliyor ama burada da gönderebiliriz
    const html = getVerificationEmail(verificationCode);
    await sendEmail(email, 'FinansAsistan - Hesap Doğrulama', html);

    logger.info('✅ User registration notification sent', {
      email,
      eventId: event.eventId
    });
  } catch (error) {
    logger.error('❌ User registered handler failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// User Verified handler
const handleUserVerified = async (event) => {
  try {
    const { payload } = event;
    const email = payload.kullanici || payload.userId;

    if (!email) {
      logger.warn('⚠️  Missing email in user verified event', { payload });
      return;
    }

    // Welcome email gönder
    const welcomeHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #007bff;">Hoş Geldiniz!</h1>
        <p>Hesabınız başarıyla doğrulandı. FinansAsistan'a hoş geldiniz!</p>
        <p>Artık tüm özelliklerimizi kullanabilirsiniz:</p>
        <ul>
          <li>Varlıklarınızı takip edin</li>
          <li>Gelir ve giderlerinizi yönetin</li>
          <li>Borçlarınızı takip edin</li>
          <li>Finansal raporlarınızı görüntüleyin</li>
        </ul>
        <p>İyi kullanımlar!</p>
        <p><strong>FinansAsistan Ekibi</strong></p>
      </div>
    `;

    await sendEmail(email, 'FinansAsistan - Hoş Geldiniz!', welcomeHtml);

    logger.info('✅ User verification welcome email sent', {
      email,
      eventId: event.eventId
    });
  } catch (error) {
    logger.error('❌ User verified handler failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// Transaction Created handler (Asset, Income, Expense, Debt)
const handleTransactionCreated = async (event) => {
  try {
    const { payload, eventType } = event;
    const email = payload.kullanici || payload.userId;

    if (!email) {
      logger.warn('⚠️  Missing email in transaction event', { payload });
      return;
    }

    // Transaction tipine göre bildirim mesajı
    let transactionType = '';
    if (eventType.includes('asset')) transactionType = 'Varlık';
    else if (eventType.includes('income')) transactionType = 'Gelir';
    else if (eventType.includes('expense')) transactionType = 'Gider';
    else if (eventType.includes('debt')) transactionType = 'Borç';

    // Kullanıcıya bildirim email'i gönder (opsiyonel - çok fazla email göndermemek için)
    // Şimdilik sadece logluyoruz
    logger.info('✅ Transaction created notification', {
      email,
      transactionType,
      eventId: event.eventId
    });
  } catch (error) {
    logger.error('❌ Transaction created handler failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

// Password Changed handler
const handlePasswordChanged = async (event) => {
  try {
    const { payload } = event;
    const email = payload.kullanici || payload.userId;

    if (!email) {
      logger.warn('⚠️  Missing email in password changed event', { payload });
      return;
    }

    // Security notification email gönder
    const securityHtml = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #dc3545;">Güvenlik Bildirimi</h1>
        <p>Hesabınızın şifresi başarıyla değiştirildi.</p>
        <p><strong>Değişiklik Zamanı:</strong> ${new Date().toLocaleString('tr-TR')}</p>
        <p>Eğer bu işlemi siz yapmadıysanız, lütfen derhal bizimle iletişime geçin.</p>
        <p><strong>FinansAsistan Güvenlik Ekibi</strong></p>
      </div>
    `;

    await sendEmail(email, 'FinansAsistan - Şifre Değişikliği Bildirimi', securityHtml);

    logger.info('✅ Password changed notification sent', {
      email,
      eventId: event.eventId
    });
  } catch (error) {
    logger.error('❌ Password changed handler failed', {
      eventId: event.eventId,
      error: error.message
    });
  }
};

module.exports = {
  handleUserRegistered,
  handleUserVerified,
  handleTransactionCreated,
  handlePasswordChanged
};

