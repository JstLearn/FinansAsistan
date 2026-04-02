const jwt = require('jsonwebtoken');
const { query } = require('../config/db');

// JWT Secret'ı başlangıçta kontrol et
const getJwtSecret = () => {
    const secret = process.env.JWT_SECRET;
    if (!secret) {
        console.error('❌ CRITICAL: JWT_SECRET environment variable is not set!');
        console.error('   This is a security vulnerability. Please set JWT_SECRET.');
        // Production'da crash et, development'ta uyarı ver
        if (process.env.NODE_ENV === 'production') {
            throw new Error('JWT_SECRET must be set in production environment');
        }
        // Development'ta bile güvenli bir fallback kullanma - hata vermeli
        throw new Error('JWT_SECRET environment variable is required');
    }
    return secret;
};

const createNewToken = (user) => {
    return jwt.sign(
        { username: user.username, id: user.id },
        getJwtSecret(),
        { expiresIn: '7d' }
    );
};

const authMiddleware = async (req, res, next) => {
    try {
        // Token'ı header'dan al
        const token = req.headers.authorization?.split(' ')[1];
        
        if (!token) {
            return res.status(401).json({
                success: false,
                message: 'Token bulunamadı'
            });
        }

        try {
            // Token'ı doğrula
            const decoded = jwt.verify(token, getJwtSecret());
            
            // Kullanıcı bilgilerini request'e ekle
            req.user = {
                username: decoded.username,
                id: decoded.id
            };

            // Kullanıcının hala DB'de olup olmadığını kontrol et (silinmişse logout ettir)
            const userCheck = await query(
                'SELECT id FROM kullanicilar WHERE id = $1 AND onaylandi = TRUE',
                [decoded.id]
            );
            if (userCheck.rows.length === 0) {
                return res.status(401).json({
                    success: false,
                    message: 'Hesap bulunamadı veya silinmiş. Lütfen tekrar giriş yapın.',
                    code: 'USER_DELETED'
                });
            }

            // Token'ın süresi dolmak üzereyse yenile (1 saatten az kaldıysa)
            const tokenExp = decoded.exp * 1000;
            const now = Date.now();
            const timeUntilExp = tokenExp - now;
            
            if (timeUntilExp < 3600000 && timeUntilExp > 0) {
                const newToken = createNewToken(req.user);
                res.setHeader('New-Token', newToken);
                res.setHeader('Access-Control-Expose-Headers', 'New-Token');
            }
            
            next();
        } catch (verifyError) {
            // Token expired veya geçersiz - YENİ TOKEN OLUŞTURMA, sadece hata döndür
            // Bug J Fix: Expired token'ları yenilemek güvenlik açığıdır
            if (verifyError.name === 'TokenExpiredError') {
                    return res.status(401).json({
                        success: false,
                    message: 'Oturum süresi doldu. Lütfen tekrar giriş yapın.',
                    code: 'TOKEN_EXPIRED'
                    });
            }
            throw verifyError;
        }
    } catch (error) {
        console.error('Auth middleware hatası:', error.message);
        return res.status(401).json({
            success: false,
            message: 'Geçersiz token'
        });
    }
};

module.exports = authMiddleware; 
