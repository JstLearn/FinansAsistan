// Migrated: MS SQL → PostgreSQL (2025-11-06)
const { pool, query, transaction } = require('../config/db');
const nodemailer = require('nodemailer');
const { getAuthorizationEmail } = require('../utils/emailTemplates');

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
    console.log('🔧 SMTP Config (yetkiController):', {
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

    return nodemailer.createTransport(config);
}

// Her mail gönderme işleminde fresh transporter oluştur
function getTransporter() {
    return createTransporter();
}

// Email gönderme fonksiyonu
const sendAuthorizationEmail = async (yetkiVerenEmail, yetkiliEmail, yetkiler) => {
    try {
        const mailOptions = {
            from: process.env.EMAIL_USER,
            to: yetkiliEmail,
            subject: 'FinansAsistan - Yetkilendirme Bildirimi',
            html: getAuthorizationEmail(yetkiVerenEmail, yetkiliEmail, yetkiler)
        };

        await getTransporter().sendMail(mailOptions);
        console.log('Yetkilendirme maili gönderildi:', yetkiliEmail);
    } catch (error) {
        console.error('Mail gönderme hatası:', error);
        // Mail hatası uygulamayı durdurmasın, sadece log'la
    }
};

// Yetki ekleme
const addYetki = async (req, res) => {
    try {
        const {
            yetkili_kullanici,
            varlik_ekleme = false,
            gelir_ekleme = false,
            harcama_borc_ekleme = false,
            istek_ekleme = false,
            hatirlatma_ekleme = false
        } = req.body;

        const yetki_veren_kullanici = req.user.username;

        // En az bir yetki seçilmeli
        if (!varlik_ekleme && !gelir_ekleme && !harcama_borc_ekleme && !istek_ekleme && !hatirlatma_ekleme) {
            return res.status(400).json({
                success: false,
                error: 'En az bir yetki türü seçmelisiniz'
            });
        }

        // Kendine yetki veremez
        if (yetki_veren_kullanici === yetkili_kullanici) {
            return res.status(400).json({
                success: false,
                error: 'Kendinize yetki veremezsiniz'
            });
        }

        // Aynı kullanıcı için yetki var mı kontrol et
        const existingCheck = await query(
            'SELECT * FROM yetkiler WHERE yetki_veren_kullanici = $1 AND yetkili_kullanici = $2',
            [yetki_veren_kullanici, yetkili_kullanici]
        );

        if (existingCheck.rows.length > 0) {
            // Varsa güncelle
            await query(`
                UPDATE yetkiler
                SET varlik_ekleme = $1,
                    gelir_ekleme = $2,
                    harcama_borc_ekleme = $3,
                    istek_ekleme = $4,
                    hatirlatma_ekleme = $5,
                    aktif = TRUE
                WHERE yetki_veren_kullanici = $6 AND yetkili_kullanici = $7
            `, [varlik_ekleme, gelir_ekleme, harcama_borc_ekleme, istek_ekleme, hatirlatma_ekleme,
                yetki_veren_kullanici, yetkili_kullanici]);

            res.status(200).json({
                success: true,
                message: 'Yetki başarıyla güncellendi'
            });
        } else {
            // Yoksa yeni ekle
            await query(`
                INSERT INTO yetkiler (
                    yetki_veren_kullanici, yetkili_kullanici, 
                    varlik_ekleme, gelir_ekleme, harcama_borc_ekleme, istek_ekleme, hatirlatma_ekleme
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7)
            `, [yetki_veren_kullanici, yetkili_kullanici,
                varlik_ekleme, gelir_ekleme, harcama_borc_ekleme, istek_ekleme, hatirlatma_ekleme]);

            // Bilgilendirme maili gönder
            await sendAuthorizationEmail(yetki_veren_kullanici, yetkili_kullanici, {
                varlik_ekleme,
                gelir_ekleme,
                harcama_borc_ekleme,
                istek_ekleme,
                hatirlatma_ekleme
            });

            res.status(201).json({
                success: true,
                message: 'Yetki başarıyla eklendi ve bilgilendirme maili gönderildi'
            });
        }
    } catch (error) {
        console.error('Yetki ekleme hatası:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Yetki eklenirken bir hata oluştu'
        });
    }
};

// Kullanıcının verdiği yetkileri listele
const getMyAuthorizations = async (req, res) => {
    try {
        const result = await query(
            'SELECT * FROM yetkiler WHERE yetki_veren_kullanici = $1 ORDER BY tarih DESC',
            [req.user.username]
        );

        res.status(200).json({
            success: true,
            data: result.rows
        });
    } catch (error) {
        console.error('Yetki listeleme hatası:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Yetki listesi alınırken bir hata oluştu'
        });
    }
};

// Kullanıcıya verilen yetkileri listele
const getGrantedToMeAuthorizations = async (req, res) => {
    try {
        const result = await query(
            'SELECT * FROM yetkiler WHERE yetkili_kullanici = $1 AND aktif = TRUE ORDER BY tarih DESC',
            [req.user.username]
        );

        res.status(200).json({
            success: true,
            data: result.rows
        });
    } catch (error) {
        console.error('Verilen yetki listeleme hatası:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Verilen yetki listesi alınırken bir hata oluştu'
        });
    }
};

// Kullanıcının sahip olduğu yetkileri kontrol et
const checkAuthorization = async (req, res) => {
    try {
        const { yetki_veren_kullanici, yetki_turu } = req.query;
        
        const result = await query(
            'SELECT * FROM yetkiler WHERE yetki_veren_kullanici = $1 AND yetkili_kullanici = $2 AND aktif = TRUE',
            [yetki_veren_kullanici, req.user.username]
        );

        if (result.rows.length === 0) {
            return res.status(200).json({
                success: true,
                authorized: false
            });
        }

        const yetki = result.rows[0];
        let authorized = false;

        switch (yetki_turu) {
            case 'varlik':
                authorized = yetki.varlik_ekleme === true;
                break;
            case 'gelir':
                authorized = yetki.gelir_ekleme === true;
                break;
            case 'harcama-borc':
                authorized = yetki.harcama_borc_ekleme === true;
                break;
            case 'istek':
                authorized = yetki.istek_ekleme === true;
                break;
            case 'hatirlatma':
                authorized = yetki.hatirlatma_ekleme === true;
                break;
            default:
                authorized = false;
        }

        res.status(200).json({
            success: true,
            authorized
        });
    } catch (error) {
        console.error('Yetki kontrol hatası:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Yetki kontrolü yapılırken bir hata oluştu'
        });
    }
};

// Yetki güncelleme
const updateYetki = async (req, res) => {
    try {
        const { id } = req.params;
        const {
            varlik_ekleme = false,
            gelir_ekleme = false,
            harcama_borc_ekleme = false,
            istek_ekleme = false,
            hatirlatma_ekleme = false,
            aktif = true
        } = req.body;

        const yetki_veren_kullanici = req.user.username;

        // Yetki kaydının yetki veren kullanıcıya ait olduğunu kontrol et
        const checkResult = await query(
            'SELECT * FROM yetkiler WHERE id = $1 AND yetki_veren_kullanici = $2',
            [id, yetki_veren_kullanici]
        );

        if (checkResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                error: 'Yetki kaydı bulunamadı veya yetkiniz yok'
            });
        }

        const yetkiliEmail = checkResult.rows[0].yetkili_kullanici;

        await query(`
            UPDATE yetkiler
            SET varlik_ekleme = $1,
                gelir_ekleme = $2,
                harcama_borc_ekleme = $3,
                istek_ekleme = $4,
                hatirlatma_ekleme = $5,
                aktif = $6
            WHERE id = $7
        `, [varlik_ekleme, gelir_ekleme, harcama_borc_ekleme, istek_ekleme, hatirlatma_ekleme, aktif, id]);

        // Güncelleme için de bilgilendirme maili gönder
        await sendAuthorizationEmail(yetki_veren_kullanici, yetkiliEmail, {
            varlik_ekleme,
            gelir_ekleme,
            harcama_borc_ekleme,
            istek_ekleme,
            hatirlatma_ekleme
        });

        res.status(200).json({
            success: true,
            message: 'Yetki başarıyla güncellendi ve bilgilendirme maili gönderildi'
        });
    } catch (error) {
        console.error('Yetki güncelleme hatası:', error);
        res.status(500).json({
            success: false,
            error: error.message || 'Yetki güncellenirken bir hata oluştu'
        });
    }
};

// Yetki silme
const deleteYetki = async (req, res) => {
    try {
        const { id } = req.params;
        const yetki_veren_kullanici = req.user.username;

        await transaction(async (client) => {
            // Yetki kaydının yetki veren kullanıcıya ait olduğunu kontrol et
            const checkResult = await client.query(
                'SELECT * FROM yetkiler WHERE id = $1 AND yetki_veren_kullanici = $2',
                [id, yetki_veren_kullanici]
            );

            if (checkResult.rows.length === 0) {
                throw new Error('Yetki kaydı bulunamadı veya yetkiniz yok');
            }

            await client.query('DELETE FROM yetkiler WHERE id = $1', [id]);
        });

        res.status(200).json({
            success: true,
            message: 'Yetki başarıyla silindi'
        });
    } catch (error) {
        console.error('Yetki silme hatası:', error);
        
        if (error.message === 'Yetki kaydı bulunamadı veya yetkiniz yok') {
            return res.status(404).json({
                success: false,
                error: error.message
            });
        }
        
        res.status(500).json({
            success: false,
            error: error.message || 'Yetki silinirken bir hata oluştu'
        });
    }
};

module.exports = {
    addYetki,
    getMyAuthorizations,
    getGrantedToMeAuthorizations,
    checkAuthorization,
    updateYetki,
    deleteYetki
};

