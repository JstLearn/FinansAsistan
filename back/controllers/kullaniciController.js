// ════════════════════════════════════════════════════════════
// controllers/kullaniciController.js
// Migrated: MS SQL Server → PostgreSQL
// Date: 2025-11-06
// Event-Driven: Kafka integration added
// ════════════════════════════════════════════════════════════

const { pool, query, transaction } = require('../config/db');
const jwt = require('jsonwebtoken');
const nodemailer = require('nodemailer');
const bcrypt = require('bcrypt');
const { getVerificationEmail } = require('../utils/emailTemplates');
const { publishEventAsync } = require('../services/kafka/producer');
const { USER_TOPICS } = require('../services/kafka/topics');

const getJwtSecret = () => {
    const secret = process.env.JWT_SECRET;
    if (!secret) {
        console.error('❌ CRITICAL: JWT_SECRET environment variable is not set!');
        throw new Error('JWT_SECRET environment variable is required');
    }
    return secret;
};

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
    const emailPass = process.env.EMAIL_PASS;

    const config = {
        host: smtpHost,
        port: smtpPort,
        secure: smtpSecure,
        auth: { user: emailUser, pass: emailPass },
        tls: { rejectUnauthorized: process.env.NODE_ENV === 'production' }
    };

    if (!smtpSecure && smtpPort === 587) {
        config.requireTLS = true;
    }

    return nodemailer.createTransport(config);
}

function getTransporter() {
    return createTransporter();
}

function generateVerificationCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

const verificationAttempts = new Map();
const loginAttempts = new Map();

const checkRateLimit = (attemptMap, key, maxAttempts, windowMs) => {
    const now = Date.now();
    const attempts = attemptMap.get(key) || [];
    const recentAttempts = attempts.filter(timestamp => now - timestamp < windowMs);
    if (recentAttempts.length >= maxAttempts) return false;
    recentAttempts.push(now);
    attemptMap.set(key, recentAttempts);
    return true;
};

const checkVerificationAttempt = (email) => checkRateLimit(verificationAttempts, email, 5, 60000);
const checkLoginAttempt = (identifier) => checkRateLimit(loginAttempts, identifier, 5, 300000);
const resetLoginAttempts = (identifier) => { loginAttempts.delete(identifier); };

const addKullanici = async (req, res) => {
    try {
        const { kullanici, sifre } = req.body;
        const checkResult = await query('SELECT id, onaylandi FROM kullanicilar WHERE kullanici = $1', [kullanici]);
        const verificationCode = generateVerificationCode();

        if (checkResult.rows.length > 0) {
            const user = checkResult.rows[0];
            if (!user.onaylandi) {
                await query('UPDATE kullanicilar SET verification_token = $1 WHERE kullanici = $2', [verificationCode, kullanici]);
                try {
                    await getTransporter().sendMail({
                        from: `"FinansAsistan" <${process.env.EMAIL_USER}>`,
                        to: kullanici,
                        subject: 'FinansAsistan - Yeni Doğrulama Kodunuz',
                        html: getVerificationEmail(verificationCode)
                    });
                } catch (emailError) {
                    console.error('❌ Email gönderilemedi:', emailError.message);
                }
                return res.json({ success: true, message: 'Yeni doğrulama kodu e-posta adresinize gönderildi.' });
            } else {
                return res.status(400).json({ success: false, message: 'Bu e-posta adresi zaten kayıtlı ve doğrulanmış' });
            }
        }

        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(sifre, saltRounds);
        const isDevelopment = process.env.NODE_ENV === 'development';
        
        const insertResult = await query(`
            INSERT INTO kullanicilar (kullanici, sifre, verification_token, onaylandi)
            VALUES ($1, $2, $3, $4)
            RETURNING id, tarih
        `, [kullanici, hashedPassword, verificationCode, isDevelopment ? true : false]);

        const userId = insertResult.rows[0].id;

        publishEventAsync(USER_TOPICS.REGISTERED, {
            id: userId, kullanici, onaylandi: isDevelopment, tarih: insertResult.rows[0].tarih
        }, { correlationId: req.correlationId || req.id, ip: req.ip || req.connection.remoteAddress, userAgent: req.get('user-agent') || '' });

        try {
            await getTransporter().sendMail({
                from: `"FinansAsistan" <${process.env.EMAIL_USER}>`,
                to: kullanici,
                subject: 'FinansAsistan - Hesap Doğrulama Kodunuz',
                html: getVerificationEmail(verificationCode)
            });
        } catch (emailError) {
            console.error('❌ Email gönderilemedi:', emailError.message);
        }

        res.json({
            success: true,
            message: isDevelopment 
                ? `✅ Kullanıcı başarıyla oluşturuldu ve onayandı (Development Mode)`
                : 'Doğrulama kodu e-posta adresinize gönderildi.'
        });
    } catch (err) {
        console.error('❌ Kullanıcı ekleme hatası:', err);
        res.status(500).json({ success: false, message: 'Kullanıcı eklenirken bir hata oluştu' });
    }
};

const verifyEmail = async (req, res) => {
    try {
        const { email, code } = req.body;
        if (!checkVerificationAttempt(email)) {
            return res.status(429).json({ success: false, message: 'Çok fazla deneme yaptınız. Lütfen 1 dakika bekleyin.' });
        }

        const result = await query('SELECT id, kullanici FROM kullanicilar WHERE kullanici = $1 AND verification_token = $2', [email, code]);

        if (result.rows.length > 0) {
            const userId = result.rows[0].id;
            await query('UPDATE kullanicilar SET onaylandi = TRUE, verification_token = NULL WHERE kullanici = $1', [email]);

            publishEventAsync(USER_TOPICS.VERIFIED, { id: userId, kullanici: email }, {
                correlationId: req.correlationId || req.id, ip: req.ip || req.connection.remoteAddress, userAgent: req.get('user-agent') || ''
            });

            const token = jwt.sign({ username: email, id: result.rows[0].id }, getJwtSecret(), { expiresIn: '24h' });
            verificationAttempts.delete(email);
            res.json({ success: true, message: 'E-posta başarıyla doğrulandı', data: { token, username: email } });
        } else {
            res.status(400).json({ success: false, message: 'Geçersiz doğrulama kodu' });
        }
    } catch (error) {
        console.error('❌ E-posta doğrulama hatası:', error);
        res.status(500).json({ success: false, message: 'Doğrulama işlemi sırasında bir hata oluştu' });
    }
};

const validateKullanici = async (req, res) => {
    try {
        const { kullanici, sifre } = req.body;
        const rateLimitKey = `${req.ip || 'unknown'}_${kullanici}`;
        if (!checkLoginAttempt(rateLimitKey)) {
            return res.status(429).json({ success: false, message: 'Çok fazla başarısız giriş denemesi. Lütfen 5 dakika bekleyin.' });
        }

        const result = await query('SELECT id, kullanici, sifre, onaylandi FROM kullanicilar WHERE kullanici = $1', [kullanici]);
        if (result.rows.length === 0) {
            return res.status(401).json({ success: false, message: 'Geçersiz kullanıcı adı veya şifre' });
        }

        const user = result.rows[0];
        const isPasswordValid = await bcrypt.compare(sifre, user.sifre);
        if (!isPasswordValid) {
            return res.status(401).json({ success: false, message: 'Geçersiz kullanıcı adı veya şifre' });
        }

        if (!user.onaylandi) {
            return res.status(401).json({ success: false, message: 'Lütfen önce e-posta adresinizi doğrulayın' });
        }

        resetLoginAttempts(rateLimitKey);
        const token = jwt.sign({ username: kullanici, id: user.id }, getJwtSecret(), { expiresIn: '24h' });

        publishEventAsync(USER_TOPICS.LOGGED_IN, { id: user.id, kullanici, login_time: new Date().toISOString() }, {
            correlationId: req.correlationId || req.id, ip: req.ip || req.connection.remoteAddress, userAgent: req.get('user-agent') || '', userId: user.id
        });

        res.json({ success: true, data: { token, username: kullanici } });
    } catch (err) {
        console.error('❌ Kullanıcı doğrulama hatası:', err);
        res.status(500).json({ success: false, message: 'Giriş yapılırken bir hata oluştu' });
    }
};

const forgotPassword = async (req, res) => {
    try {
        const { kullanici } = req.body;
        const result = await query('SELECT id FROM kullanicilar WHERE kullanici = $1', [kullanici]);
        if (result.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı' });
        }

        const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
        await query('UPDATE kullanicilar SET verification_token = $1 WHERE kullanici = $2', [resetCode, kullanici]);

        await getTransporter().sendMail({
            from: process.env.EMAIL_USER,
            to: kullanici,
            subject: 'Parola Sıfırlama Kodunuz',
            html: `<h2>Parola Sıfırlama</h2><p>Parola sıfırlama kodunuz: <strong>${resetCode}</strong></p>`
        });

        res.json({ success: true, message: 'Parola sıfırlama kodu e-posta adresinize gönderildi' });
    } catch (error) {
        console.error('❌ Parola sıfırlama hatası:', error);
        res.status(500).json({ success: false, message: 'Parola sıfırlama işlemi sırasında bir hata oluştu' });
    }
};

const resetPassword = async (req, res) => {
    try {
        const { kullanici, code, yeniSifre } = req.body;
        const result = await query('SELECT id FROM kullanicilar WHERE kullanici = $1 AND verification_token = $2', [kullanici, code]);
        if (result.rows.length === 0) {
            return res.status(400).json({ success: false, message: 'Geçersiz sıfırlama kodu' });
        }

        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(yeniSifre, saltRounds);
        await query('UPDATE kullanicilar SET sifre = $1, verification_token = NULL WHERE kullanici = $2', [hashedPassword, kullanici]);

        publishEventAsync(USER_TOPICS.PASSWORD_CHANGED, { kullanici }, {
            correlationId: req.correlationId || req.id, ip: req.ip || req.connection.remoteAddress, userAgent: req.get('user-agent') || ''
        });

        res.json({ success: true, message: 'Parolanız başarıyla güncellendi' });
    } catch (error) {
        console.error('❌ Parola güncelleme hatası:', error);
        res.status(500).json({ success: false, message: 'Parola güncellenirken bir hata oluştu' });
    }
};

module.exports = { addKullanici, validateKullanici, verifyEmail, forgotPassword, resetPassword };
