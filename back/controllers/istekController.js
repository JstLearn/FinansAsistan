// Migrated: MS SQL → PostgreSQL (2025-11-06)
const { pool, query, transaction } = require('../config/db');

// İstek ekleme
const addIstek = async (req, res) => {
    try {
        const { kategori, link, aciklama, oncelik, miktar, para_birimi } = req.body;
        const kullanici = req.user.username;
        const ekleyen_kullanici = req.user.username;

        const result = await transaction(async (client) => {
            const insertResult = await client.query(`
                INSERT INTO istekler (kullanici, ekleyen_kullanici, kategori, link, aciklama, oncelik, miktar, para_birimi)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
                RETURNING id, tarih
            `, [kullanici, ekleyen_kullanici, kategori, link || null, aciklama || null, oncelik || null, miktar || null, para_birimi || null]);
            return insertResult.rows[0];
        });

        res.status(201).json({
            success: true,
            message: 'İstek başarıyla eklendi',
            data: { id: result.id, tarih: result.tarih, kategori, link, aciklama, oncelik, miktar, para_birimi, kullanici, ekleyen_kullanici }
        });
    } catch (error) {
        console.error('SQL Hatası:', error);
        res.status(500).json({ success: false, error: error.message || 'İstek eklenirken bir hata oluştu' });
    }
};

// Tüm istekleri getirme
const getAllIstek = async (req, res) => {
    try {
        const result = await query(`
            SELECT id, ekleyen_kullanici, kategori, link, miktar, para_birimi, aciklama, oncelik
            FROM istekler 
            WHERE kullanici = $1
        `, [req.user.username]);
        res.status(200).json({ success: true, data: result.rows });
    } catch (error) {
        console.error('SQL Hatası:', error);
        res.status(500).json({ success: false, error: error.message || 'İstek verileri alınırken bir hata oluştu' });
    }
};

// İstek Güncelleme
const updateIstek = async (req, res) => {
    try {
        const { id } = req.params;
        const { kategori, link, aciklama, oncelik, miktar, para_birimi } = req.body;
        const kullanici = req.user.username;

        const result = await transaction(async (client) => {
            const checkResult = await client.query('SELECT * FROM istekler WHERE id = $1 AND kullanici = $2', [id, kullanici]);
            if (checkResult.rows.length === 0) throw new Error('İstek bulunamadı veya yetkiniz yok');
            const updateResult = await client.query(`
                UPDATE istekler
                SET kategori = $1, link = $2, aciklama = $3, oncelik = $4, miktar = $5, para_birimi = $6
                WHERE id = $7 AND kullanici = $8
                RETURNING id, tarih
            `, [kategori, link || null, aciklama || null, oncelik || null, miktar || null, para_birimi || null, id, kullanici]);
            return updateResult.rows[0];
        });

        res.status(200).json({ success: true, message: 'İstek başarıyla güncellendi', data: { id: result.id, tarih: result.tarih, kategori, link, aciklama, oncelik, miktar, para_birimi, kullanici } });
    } catch (error) {
        console.error('SQL Hatası:', error);
        if (error.message === 'İstek bulunamadı veya yetkiniz yok') {
            return res.status(404).json({ success: false, error: error.message });
        }
        res.status(500).json({ success: false, error: error.message || 'İstek güncellenirken bir hata oluştu' });
    }
};

// İstek Silme
const deleteIstek = async (req, res) => {
    try {
        const { id } = req.params;
        const kullanici = req.user.username;

        await transaction(async (client) => {
            const checkResult = await client.query('SELECT * FROM istekler WHERE id = $1 AND kullanici = $2', [id, kullanici]);
            if (checkResult.rows.length === 0) throw new Error('İstek bulunamadı veya yetkiniz yok');
            await client.query('DELETE FROM istekler WHERE id = $1 AND kullanici = $2', [id, kullanici]);
        });

        res.status(200).json({ success: true, message: 'İstek başarıyla silindi' });
    } catch (error) {
        console.error('SQL Hatası:', error);
        if (error.message === 'İstek bulunamadı veya yetkiniz yok') {
            return res.status(404).json({ success: false, error: error.message });
        }
        res.status(500).json({ success: false, error: error.message || 'İstek silinirken bir hata oluştu' });
    }
};

module.exports = { addIstek, getAllIstek, updateIstek, deleteIstek };
