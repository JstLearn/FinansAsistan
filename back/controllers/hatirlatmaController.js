// Migrated: MS SQL → PostgreSQL (2025-11-06)
const { pool, query, transaction } = require('../config/db');

// Hatırlatma ekleme
const addHatirlatma = async (req, res) => {
    try {
        const { hatirlatilacak_olay, olay_zamani } = req.body;
        const kullanici = req.user.username;
        const ekleyen_kullanici = req.user.username;

        const result = await transaction(async (client) => {
            const insertResult = await client.query(`
                INSERT INTO hatirlatmalar (kullanici, ekleyen_kullanici, hatirlatilacak_olay, olay_zamani)
                VALUES ($1, $2, $3, $4)
                RETURNING id, tarih
            `, [kullanici, ekleyen_kullanici, hatirlatilacak_olay, olay_zamani]);
            return insertResult.rows[0];
        });

        res.status(201).json({
            success: true,
            message: 'Hatırlatma başarıyla eklendi',
            data: { id: result.id, tarih: result.tarih, hatirlatilacak_olay, olay_zamani, kullanici, ekleyen_kullanici }
        });
    } catch (error) {
        console.error('SQL Hatası:', error);
        res.status(500).json({ success: false, error: error.message || 'Hatırlatma eklenirken bir hata oluştu' });
    }
};

// Tüm hatırlatmaları getirme
const getAllHatirlatma = async (req, res) => {
    try {
        const result = await query(`
            SELECT id, ekleyen_kullanici, hatirlatilacak_olay, olay_zamani
            FROM hatirlatmalar 
            WHERE kullanici = $1
        `, [req.user.username]);
        res.status(200).json({ success: true, data: result.rows });
    } catch (error) {
        console.error('SQL Hatası:', error);
        res.status(500).json({ success: false, error: error.message || 'Hatırlatma verileri alınırken bir hata oluştu' });
    }
};

// Hatırlatma Güncelleme
const updateHatirlatma = async (req, res) => {
    try {
        const { id } = req.params;
        const { hatirlatilacak_olay, olay_zamani } = req.body;
        const kullanici = req.user.username;

        const result = await transaction(async (client) => {
            const checkResult = await client.query('SELECT * FROM hatirlatmalar WHERE id = $1 AND kullanici = $2', [id, kullanici]);
            if (checkResult.rows.length === 0) throw new Error('Hatırlatma bulunamadı veya yetkiniz yok');
            const updateResult = await client.query(`
                UPDATE hatirlatmalar
                SET hatirlatilacak_olay = $1, olay_zamani = $2
                WHERE id = $3 AND kullanici = $4
                RETURNING id, tarih
            `, [hatirlatilacak_olay, olay_zamani, id, kullanici]);
            return updateResult.rows[0];
        });

        res.status(200).json({ success: true, message: 'Hatırlatma başarıyla güncellendi', data: { id: result.id, tarih: result.tarih, hatirlatilacak_olay, olay_zamani, kullanici } });
    } catch (error) {
        console.error('SQL Hatası:', error);
        if (error.message === 'Hatırlatma bulunamadı veya yetkiniz yok') {
            return res.status(404).json({ success: false, error: error.message });
        }
        res.status(500).json({ success: false, error: error.message || 'Hatırlatma güncellenirken bir hata oluştu' });
    }
};

// Hatırlatma Silme
const deleteHatirlatma = async (req, res) => {
    try {
        const { id } = req.params;
        const kullanici = req.user.username;

        await transaction(async (client) => {
            const checkResult = await client.query('SELECT * FROM hatirlatmalar WHERE id = $1 AND kullanici = $2', [id, kullanici]);
            if (checkResult.rows.length === 0) throw new Error('Hatırlatma bulunamadı veya yetkiniz yok');
            await client.query('DELETE FROM hatirlatmalar WHERE id = $1 AND kullanici = $2', [id, kullanici]);
        });

        res.status(200).json({ success: true, message: 'Hatırlatma başarıyla silindi' });
    } catch (error) {
        console.error('SQL Hatası:', error);
        if (error.message === 'Hatırlatma bulunamadı veya yetkiniz yok') {
            return res.status(404).json({ success: false, error: error.message });
        }
        res.status(500).json({ success: false, error: error.message || 'Hatırlatma silinirken bir hata oluştu' });
    }
};

module.exports = { addHatirlatma, getAllHatirlatma, updateHatirlatma, deleteHatirlatma };
