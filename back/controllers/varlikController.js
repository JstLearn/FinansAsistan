// ════════════════════════════════════════════════════════════
// controllers/varlikController.js
// Migrated: MS SQL Server → PostgreSQL
// Date: 2025-11-06
// Event-Driven: Kafka integration added
// ════════════════════════════════════════════════════════════

const { pool, query, transaction } = require("../config/db");
const { publishEventAsync } = require('../services/kafka/producer');
const { TRANSACTION_TOPICS } = require('../services/kafka/topics');

// Varlık Ekleme
const addVarlik = async (req, res) => {
  try {
    const {
      kategori, varlik = null, alis_tarihi, alis_fiyati, alis_para_birimi = null,
      alis_adedi = null, saklanildigi_yer = null, link = null, metrekare = null, aciklama = null
    } = req.body;

    const kullanici = req.user.username;
    const ekleyen_kullanici = req.user.username;
    
    const result = await transaction(async (client) => {
      const insertResult = await client.query(`
        INSERT INTO varliklar
          (kullanici, ekleyen_kullanici, kategori, varlik, aciklama, saklanildigi_yer, 
           alis_tarihi, alis_para_birimi, alis_fiyati, alis_adedi, link, metrekare)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING id, tarih
      `, [kullanici, ekleyen_kullanici, kategori, varlik, aciklama, saklanildigi_yer,
          alis_tarihi, alis_para_birimi, alis_fiyati, alis_adedi, link, metrekare]);
      return insertResult.rows[0];
    });

    publishEventAsync(TRANSACTION_TOPICS.ASSET_CREATED, {
      id: result.id, kullanici, ekleyen_kullanici, kategori, varlik, alis_tarihi, alis_fiyati,
      alis_para_birimi, alis_adedi, saklanildigi_yer, link, metrekare, aciklama, tarih: result.tarih
    }, { correlationId: req.correlationId || req.id, ip: req.ip || req.connection.remoteAddress, userAgent: req.get('user-agent') || '', userId: req.user?.id || req.user?.username });

    res.status(201).json({ 
      success: true,
      message: "Varlık başarıyla eklendi!",
      data: { id: result.id, tarih: result.tarih, kategori, alis_fiyati, alis_tarihi, kullanici, ekleyen_kullanici }
    });
  } catch (err) {
    console.error("❌ Hata oluştu (varlık):", err);
    res.status(500).json({ success: false, error: err.message || "Varlık eklenirken bir hata oluştu" });
  }
};

// Varlıkları Getirme
const getAllVarlik = async (req, res) => {
  try {
    const result = await query(`
      SELECT 
        id, ekleyen_kullanici, kategori, varlik, aciklama, saklanildigi_yer,
        alis_tarihi, alis_para_birimi, alis_fiyati, alis_adedi,
        simdi_fiyati_USD, kar_zarar, kar_zarar_yuzde, min_satis_fiyati_USD,
        link, metrekare, tarih
      FROM varliklar 
      WHERE kullanici = $1
      ORDER BY tarih DESC
    `, [req.user.username]);
    res.status(200).json({ success: true, data: result.rows });
  } catch (err) {
    console.error("❌ Hata oluştu (get-all-varlik):", err);
    res.status(500).json({ success: false, error: err.message || "Varlık verileri alınırken bir hata oluştu" });
  }
};

// Varlık Güncelleme
const updateVarlik = async (req, res) => {
  try {
    const { id } = req.params;
    const {
      kategori, varlik = null, alis_tarihi, alis_fiyati, alis_para_birimi = null,
      alis_adedi = null, saklanildigi_yer = null, link = null, metrekare = null, aciklama = null
    } = req.body;

    const kullanici = req.user.username;
    
    const result = await transaction(async (client) => {
      const checkResult = await client.query('SELECT id FROM varliklar WHERE id = $1 AND kullanici = $2', [id, kullanici]);
      if (checkResult.rows.length === 0) throw new Error('Varlık bulunamadı veya yetkiniz yok');
      const updateResult = await client.query(`
        UPDATE varliklar
        SET kategori = $1, varlik = $2, aciklama = $3, saklanildigi_yer = $4,
            alis_tarihi = $5, alis_para_birimi = $6, alis_fiyati = $7, alis_adedi = $8,
            link = $9, metrekare = $10
        WHERE id = $11 AND kullanici = $12
        RETURNING id, tarih
      `, [kategori, varlik, aciklama, saklanildigi_yer, alis_tarihi, alis_para_birimi,
          alis_fiyati, alis_adedi, link, metrekare, id, kullanici]);
      return updateResult.rows[0];
    });

    publishEventAsync(TRANSACTION_TOPICS.ASSET_UPDATED, {
      id: result.id, kullanici, kategori, varlik, alis_tarihi, alis_fiyati, alis_para_birimi,
      alis_adedi, saklanildigi_yer, link, metrekare, aciklama, tarih: result.tarih
    }, { correlationId: req.correlationId || req.id, ip: req.ip || req.connection.remoteAddress, userAgent: req.get('user-agent') || '', userId: req.user?.id || req.user?.username });

    res.status(200).json({ success: true, message: "Varlık başarıyla güncellendi!", data: { id: result.id, kategori, alis_fiyati, alis_tarihi, kullanici } });
  } catch (err) {
    console.error("❌ Hata oluştu (update-varlik):", err);
    if (err.message === 'Varlık bulunamadı veya yetkiniz yok') {
      return res.status(404).json({ success: false, error: err.message });
    }
    res.status(500).json({ success: false, error: err.message || "Varlık güncellenirken bir hata oluştu" });
  }
};

// Varlık Silme
const deleteVarlik = async (req, res) => {
  try {
    const { id } = req.params;
    const kullanici = req.user.username;
    
    const deletedRecord = await transaction(async (client) => {
      const checkResult = await client.query('SELECT id, kategori, varlik FROM varliklar WHERE id = $1 AND kullanici = $2', [id, kullanici]);
      if (checkResult.rows.length === 0) throw new Error('Varlık bulunamadı veya yetkiniz yok');
      await client.query('DELETE FROM varliklar WHERE id = $1 AND kullanici = $2', [id, kullanici]);
      return checkResult.rows[0];
    });

    publishEventAsync(TRANSACTION_TOPICS.ASSET_DELETED, {
      id: parseInt(id), kullanici, kategori: deletedRecord.kategori, varlik: deletedRecord.varlik
    }, { correlationId: req.correlationId || req.id, ip: req.ip || req.connection.remoteAddress, userAgent: req.get('user-agent') || '', userId: req.user?.id || req.user?.username });

    res.status(200).json({ success: true, message: "Varlık başarıyla silindi!" });
  } catch (err) {
    console.error("❌ Hata oluştu (delete-varlik):", err);
    if (err.message === 'Varlık bulunamadı veya yetkiniz yok') {
      return res.status(404).json({ success: false, error: err.message });
    }
    res.status(500).json({ success: false, error: err.message || "Varlık silinirken bir hata oluştu" });
  }
};

module.exports = { addVarlik, getAllVarlik, updateVarlik, deleteVarlik };
