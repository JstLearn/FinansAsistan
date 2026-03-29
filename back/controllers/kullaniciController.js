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

// JWT Secret helper - fallback olmadan, güvenli
const getJwtSecret = () => {
    const secret = process.env.JWT_SECRET;
    if (!secret) {
        console.error('❌ CRITICAL: JWT_SECRET environment variable is not set!');
        throw new Error('JWT_SECRET environment variable is required');
    }
    return secret;
};

// E-posta gönderme için transporter oluştur (her çağrıda fresh env değerleri almak için fonksiyon)
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

    // DEBUG: Kullanılan değerleri log'la
    console.log('🔧 SMTP Config:', {
        host: smtpHost,
        port: smtpPort,
        secure: smtpSecure,
        user: emailUser ? emailUser.substring(0, 5) + '...' : 'MISSING'
    });

    if (!smtpHost) {
        console.error('❌ SMTP_HOST veya EMAIL_HOST env değişkeni tanımlı değil!');
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

    const transport = nodemailer.createTransport(config);

    // Test connection (sadece ilk oluşturulduğunda)
    transport.verify(function(error, success) {
    if (error) {
            console.log('❌ SMTP Bağlantı hatası:', error.message);
    } else {
            console.log('✅ SMTP Sunucusu hazır:', smtpHost);
    }
});

    return transport;
}

// Her mail gönderme işleminde fresh transporter oluştur (env değişikliklerini yakalamak için)
function getTransporter() {
    return createTransporter();
}

// 6 haneli doğrulama kodu oluştur
function generateVerificationCode() {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

// Rate limiting için generic Map'ler
const verificationAttempts = new Map();
const loginAttempts = new Map();

// Generic rate limiter
const checkRateLimit = (attemptMap, key, maxAttempts, windowMs) => {
    const now = Date.now();
    const attempts = attemptMap.get(key) || [];
    
    // Belirtilen zaman penceresi içindeki denemeleri filtrele
    const recentAttempts = attempts.filter(timestamp => now - timestamp < windowMs);
    
    // Maksimum deneme sayısını aştıysa false döndür
    if (recentAttempts.length >= maxAttempts) {
        return false;
    }
    
    // Yeni denemeyi ekle
    recentAttempts.push(now);
    attemptMap.set(key, recentAttempts);
    return true;
};

// Doğrulama denemelerini kontrol et (5 deneme / 1 dakika)
const checkVerificationAttempt = (email) => {
    return checkRateLimit(verificationAttempts, email, 5, 60000);
};

// Login denemelerini kontrol et (5 deneme / 5 dakika - brute force koruması)
const checkLoginAttempt = (identifier) => {
    return checkRateLimit(loginAttempts, identifier, 5, 300000);
};

// Başarılı login sonrası rate limit'i sıfırla
const resetLoginAttempts = (identifier) => {
    loginAttempts.delete(identifier);
};

const addKullanici = async (req, res) => {
    try {
        const { kullanici, sifre } = req.body;

        // E-posta kontrolü
        const checkResult = await query(
            'SELECT id, onaylandi FROM kullanicilar WHERE kullanici = $1',
            [kullanici]
        );

        // Doğrulama kodu oluştur
        const verificationCode = generateVerificationCode();

        if (checkResult.rows.length > 0) {
            const user = checkResult.rows[0];
            
            // Kullanıcı var ama onaylanmamış
            if (!user.onaylandi) {
                // Doğrulama kodunu güncelle
                await query(
                    'UPDATE kullanicilar SET verification_token = $1 WHERE kullanici = $2',
                    [verificationCode, kullanici]
                );

                // E-posta gönder (hata olsa bile devam et)
                try {
                    const mailOptions = {
                        from: `"FinansAsistan" <${process.env.EMAIL_USER}>`,
                        to: kullanici,
                        subject: 'FinansAsistan - Yeni Doğrulama Kodunuz',
                        html: getVerificationEmail(verificationCode, kullanici)
                    };

                    await getTransporter().sendMail(mailOptions);
                    console.log('✅ Doğrulama maili gönderildi:', kullanici);
                    if (process.env.NODE_ENV === 'development') {
                        console.log('📧 Development Mode - Yeni Doğrulama Kodu:', verificationCode);
                    }
                } catch (emailError) {
                    console.error('❌ Email gönderilemedi:', emailError.message);
                    console.error('Email Error Details:', emailError);
                    if (process.env.NODE_ENV === 'development') {
                        console.log('📧 Development Mode - Yeni Doğrulama Kodu (Email gönderilemedi):', verificationCode);
                    }
                }

                return res.json({
                    success: true,
                    message: 'Yeni doğrulama kodu e-posta adresinize gönderildi.'
                });
            } else {
                return res.status(400).json({
                    success: false,
                    message: 'Bu e-posta adresi zaten kayıtlı ve doğrulanmış'
                });
            }
        }

        // Şifreyi hashle
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(sifre, saltRounds);

        // Development modunda email doğrulaması olmadan direkt onaylanmış kullanıcı oluştur
        const isDevelopment = process.env.NODE_ENV === 'development';
        
        // Yeni kullanıcıyı kaydet
        const insertResult = await query(`
            INSERT INTO kullanicilar
            (kullanici, sifre, verification_token, onaylandi)
            VALUES ($1, $2, $3, $4)
            RETURNING id, tarih
        `, [kullanici, hashedPassword, verificationCode, isDevelopment ? true : false]);

        const userId = insertResult.rows[0].id;

        // ✅ Kafka event publish - User Registered
        // NOT: verification_token güvenlik nedeniyle event'e dahil edilmiyor
        publishEventAsync(USER_TOPICS.REGISTERED, {
            id: userId,
            kullanici,
            onaylandi: isDevelopment,
            tarih: insertResult.rows[0].tarih
        }, {
            correlationId: req.correlationId || req.id,
            ip: req.ip || req.connection.remoteAddress,
            userAgent: req.get('user-agent') || ''
        });

        // E-posta gönder (hem development hem production'da)
        try {
            const mailOptions = {
                from: `"FinansAsistan" <${process.env.EMAIL_USER}>`,
                to: kullanici,
                subject: 'FinansAsistan - Hesap Doğrulama Kodunuz',
                html: getVerificationEmail(verificationCode, kullanici)
            };

            await getTransporter().sendMail(mailOptions);
            console.log('✅ Doğrulama maili gönderildi:', kullanici);
            if (isDevelopment) {
                console.log('📧 Development Mode - Doğrulama Kodu:', verificationCode);
            }
        } catch (emailError) {
            console.error('❌ Email gönderilemedi:', emailError.message);
            console.error('Email Error Details:', emailError);
            // Development modunda email hatası olsa bile devam et
            if (isDevelopment) {
                console.log('📧 Development Mode - Doğrulama Kodu (Email gönderilemedi):', verificationCode);
            }
        }

        res.json({
            success: true,
            message: isDevelopment 
                ? `✅ Kullanıcı başarıyla oluşturuldu ve onaylandı (Development Mode)`
                : 'Doğrulama kodu e-posta adresinize gönderildi.'
        });
    } catch (err) {
        console.error('❌ Kullanıcı ekleme hatası:', err);
        res.status(500).json({
            success: false,
            message: 'Kullanıcı eklenirken bir hata oluştu'
        });
    }
};

const verifyEmail = async (req, res) => {
    try {
        const { email, code } = req.body;

        // Deneme hakkını kontrol et
        if (!checkVerificationAttempt(email)) {
            return res.status(429).json({
                success: false,
                message: 'Çok fazla deneme yaptınız. Lütfen 1 dakika bekleyin.'
            });
        }

        // Kullanıcıyı bul ve doğrulama kodunu kontrol et
        const result = await query(
            'SELECT id, kullanici FROM kullanicilar WHERE kullanici = $1 AND verification_token = $2',
            [email, code]
        );

        if (result.rows.length > 0) {
            const userId = result.rows[0].id;
            
            // Kullanıcıyı onayla
            await query(
                'UPDATE kullanicilar SET onaylandi = TRUE, verification_token = NULL WHERE kullanici = $1',
                [email]
            );

            // ✅ Kafka event publish - User Verified
            // NOT: verification_code güvenlik nedeniyle event'e dahil edilmiyor
            publishEventAsync(USER_TOPICS.VERIFIED, {
                id: userId,
                kullanici: email
            }, {
                correlationId: req.correlationId || req.id,
                ip: req.ip || req.connection.remoteAddress,
                userAgent: req.get('user-agent') || ''
            });

            const tokenData = { 
                username: email,
                id: result.rows[0].id
            };

            const token = jwt.sign(tokenData, getJwtSecret(), { expiresIn: '24h' });

            // Başarılı doğrulamadan sonra deneme sayısını sıfırla
            verificationAttempts.delete(email);

            res.json({
                success: true,
                message: 'E-posta başarıyla doğrulandı',
                data: {
                    token,
                    username: email
                }
            });
        } else {
            res.status(400).json({
                success: false,
                message: 'Geçersiz doğrulama kodu'
            });
        }
    } catch (error) {
        console.error('❌ E-posta doğrulama hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Doğrulama işlemi sırasında bir hata oluştu'
        });
    }
};

const validateKullanici = async (req, res) => {
    try {
        const { kullanici, sifre } = req.body;
        
        // Rate limiting: IP + kullanıcı adı kombinasyonu ile brute force koruması
        const rateLimitKey = `${req.ip || 'unknown'}_${kullanici}`;
        if (!checkLoginAttempt(rateLimitKey)) {
            return res.status(429).json({
                success: false,
                message: 'Çok fazla başarısız giriş denemesi. Lütfen 5 dakika bekleyin.'
            });
        }

        const result = await query(
            'SELECT id, kullanici, sifre, onaylandi FROM kullanicilar WHERE kullanici = $1',
            [kullanici]
        );

        if (result.rows.length === 0) {
            return res.status(401).json({
                success: false,
                message: 'Geçersiz kullanıcı adı veya şifre'
            });
        }

        const user = result.rows[0];

        // Şifre kontrolü
        const isPasswordValid = await bcrypt.compare(sifre, user.sifre);

        if (!isPasswordValid) {
            return res.status(401).json({
                success: false,
                message: 'Geçersiz kullanıcı adı veya şifre'
            });
        }

        // E-posta doğrulaması kontrolü
        if (!user.onaylandi) {
            return res.status(401).json({
                success: false,
                message: 'Lütfen önce e-posta adresinizi doğrulayın'
            });
        }

        // Başarılı giriş - rate limit'i sıfırla
        resetLoginAttempts(rateLimitKey);

        const tokenData = { 
            username: kullanici,
            id: user.id
        };

        const token = jwt.sign(tokenData, getJwtSecret(), { expiresIn: '24h' });

        // ✅ Kafka event publish - User Logged In
        publishEventAsync(USER_TOPICS.LOGGED_IN, {
            id: user.id,
            kullanici,
            login_time: new Date().toISOString()
        }, {
            correlationId: req.correlationId || req.id,
            ip: req.ip || req.connection.remoteAddress,
            userAgent: req.get('user-agent') || '',
            userId: user.id
        });

        res.json({
            success: true,
            data: {
                token,
                username: kullanici
            }
        });
    } catch (err) {
        console.error('❌ Kullanıcı doğrulama hatası:', err);
        res.status(500).json({
            success: false,
            message: 'Giriş yapılırken bir hata oluştu'
        });
    }
};

const forgotPassword = async (req, res) => {
    try {
        const { kullanici } = req.body;

        // Kullanıcıyı kontrol et
        const result = await query(
            'SELECT id FROM kullanicilar WHERE kullanici = $1',
            [kullanici]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı'
            });
        }

        // Sıfırlama kodu oluştur
        const resetCode = Math.floor(100000 + Math.random() * 900000).toString();

        // Sıfırlama kodunu kaydet
        await query(
            'UPDATE kullanicilar SET verification_token = $1 WHERE kullanici = $2',
            [resetCode, kullanici]
        );

        // E-posta gönder
        const mailOptions = {
            from: process.env.EMAIL_USER,
            to: kullanici,
            subject: 'Parola Sıfırlama Kodunuz',
            html: `
                <h2>Parola Sıfırlama</h2>
                <p>Parola sıfırlama kodunuz:</p>
                <h1 style="
                    color: #007bff;
                    font-size: 32px;
                    letter-spacing: 5px;
                    margin: 20px 0;
                ">${resetCode}</h1>
                <p>Bu kodu kullanarak yeni parolanızı belirleyebilirsiniz.</p>
            `
        };

        await getTransporter().sendMail(mailOptions);

        res.json({
            success: true,
            message: 'Parola sıfırlama kodu e-posta adresinize gönderildi'
        });
    } catch (error) {
        console.error('❌ Parola sıfırlama hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Parola sıfırlama işlemi sırasında bir hata oluştu'
        });
    }
};

const resetPassword = async (req, res) => {
    try {
        const { kullanici, code, yeniSifre } = req.body;

        // Kullanıcı ve kodu kontrol et
        const result = await query(
            'SELECT id FROM kullanicilar WHERE kullanici = $1 AND verification_token = $2',
            [kullanici, code]
        );

        if (result.rows.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Geçersiz sıfırlama kodu'
            });
        }

        // Yeni şifreyi hashle
        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(yeniSifre, saltRounds);

        // Şifreyi güncelle ve sıfırlama kodunu temizle
        await query(
            'UPDATE kullanicilar SET sifre = $1, verification_token = NULL WHERE kullanici = $2',
            [hashedPassword, kullanici]
        );

        // ✅ Kafka event publish - Password Changed
        publishEventAsync(USER_TOPICS.PASSWORD_CHANGED, {
            kullanici,
            reset_code: code
        }, {
            correlationId: req.correlationId || req.id,
            ip: req.ip || req.connection.remoteAddress,
            userAgent: req.get('user-agent') || ''
        });

        res.json({
            success: true,
            message: 'Parolanız başarıyla güncellendi'
        });
    } catch (error) {
        console.error('❌ Parola güncelleme hatası:', error);
        res.status(500).json({
            success: false,
            message: 'Parola güncellenirken bir hata oluştu'
        });
    }
};

module.exports = {
    addKullanici,
    validateKullanici,
    verifyEmail,
    forgotPassword,
    resetPassword
}; 