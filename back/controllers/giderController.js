// Migrated: MS SQL → PostgreSQL (2025-11-06)
// Event-Driven: Kafka integration added
const { pool, query, transaction } = require('../config/db');
const { publishEventAsync } = require('../services/kafka/producer');
const { TRANSACTION_TOPICS } = require('../services/kafka/topics');

// Gider ekleme
const addGider = async (req, res) => {
    try {
        const { 
            gider, duzenlimi, tutar, para_birimi, kalan_taksit,
            odeme_tarihi, faiz_binecekmi, odendi_mi, talimat_varmi, bagimli_oldugu_gelir 
        } = req.body;
        
        const kullanici = req.user.username;

        const result = await transaction(async (client) => {
            const insertResult = await client.query(`
                INSERT INTO harcama_borc (
                    kullanici, ekleyen_kullanici, miktar, para_birimi,
                    odeme_tarihi, taksit, odendi_mi, talimat_varmi, faiz_uygulaniyormu,
                    bagimli_oldugu_gelir, aciklama
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
                RETURNING id, tarih
            `, [kullanici, kullanici, tutar, para_birimi,
                odeme_tarihi, kalan_taksit, odendi_mi, talimat_varmi, faiz_binecekmi,
                bagimli_oldugu_gelir, gider]);
            return insertResult.rows[0];
        });

        publishEventAsync(TRANSACTION_TOPICS.EXPENSE_CREATED, {
            id: result.id, kullanici, gider, duzenlimi, tutar, para_birimi,
            kalan_taksit, odeme_tarihi, faiz_binecekmi, odendi_mi, talimat_varmi,
            bagimli_oldugu_gelir, tarih: result.tarih
        }, { correlationId: req.correlationId || req.id, ip: req.ip || req.connection.remoteAddress, userAgent: req.get('user-agent') || '', userId: req.user?.id || req.user?.username });

        res.status(201).json({
            success: true,
            message: 'Gider başarıyla eklendi',
            data: { id: result.id, tarih: result.tarih, gider, tutar, odeme_tarihi, kullanici }
        });
    } catch (error) {
        console.error('SQL Hatası:', error);
        res.status(500).json({ success: false, error: error.message || 'Gider eklenirken bir hata oluştu' });
    }
};

// Tüm giderleri getirme
const getAllGider = async (req, res) => {
    try {
        const result = await query('SELECT * FROM harcama_borc WHERE kullanici = $1', [req.user.username]);
        res.status(200).json({ success: true, data: result.rows });
    } catch (error) {
        console.error('SQL Hatası:', error);
        res.status(500).json({ success: false, error: error.message || 'Gider verileri alınırken bir hata oluştu' });
    }
};

module.exports = { addGider, getAllGider };
