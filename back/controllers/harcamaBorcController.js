// ════════════════════════════════════════════════════════════
// back/controllers/harcamaBorcController.js
// Migrated: MS SQL Server → PostgreSQL
// Date: 2025-11-06
// Event-Driven: Kafka integration added
// ════════════════════════════════════════════════════════════

const { pool, query, transaction } = require("../config/db");
const { publishEventAsync } = require('../services/kafka/producer');
const { TRANSACTION_TOPICS } = require('../services/kafka/topics');

// Harcama/Borç Ekleme
const addHarcamaBorc = async (req, res) => {
  try {
    let {
      miktar,
      para_birimi = "TRY",
      odeme_tarihi,
      taksit = 1,
      odendi_mi = false,
      talimat_varmi = false,
      faiz_uygulaniyormu = false,
      bagimli_oldugu_gelir = null,
      aciklama = null,
      miktar_belirsiz = false
    } = req.body;
    
    // Boolean değerleri düzgün parse et (string '0' ve '1' için)
    odendi_mi = odendi_mi === '1' || odendi_mi === 1 || odendi_mi === true;
    talimat_varmi = talimat_varmi === '1' || talimat_varmi === 1 || talimat_varmi === true;
    faiz_uygulaniyormu = faiz_uygulaniyormu === '1' || faiz_uygulaniyormu === 1 || faiz_uygulaniyormu === true;
    miktar_belirsiz = miktar_belirsiz === '1' || miktar_belirsiz === 1 || miktar_belirsiz === true;

    // Taksit değerini kontrol et ve düzelt
    if (typeof taksit === 'string') {
      taksit = parseInt(taksit, 10);
    }
    if (isNaN(taksit) || taksit === null || taksit === undefined) {
      taksit = 1; // Default değer
    }

    // Miktar değerini kontrol et ve düzelt
    if (typeof miktar === 'string') {
      miktar = parseFloat(miktar);
    }
    if (isNaN(miktar) || miktar === null || miktar === undefined) {
      return res.status(400).json({
        success: false,
        error: 'Geçersiz miktar değeri. Lütfen sayısal bir değer girin.'
      });
    }

    const kullanici = req.user.username;
    const ekleyen_kullanici = req.user.username;

    // PostgreSQL ile veriyi ekle
    const insertResult = await query(`
      INSERT INTO harcama_borc
        (kullanici, ekleyen_kullanici, miktar, para_birimi, odeme_tarihi, 
         taksit, odendi_mi, talimat_varmi, faiz_uygulaniyormu, bagimli_oldugu_gelir, aciklama, miktar_belirsiz)
      VALUES
        ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
      RETURNING id, tarih
    `, [
      kullanici,
      ekleyen_kullanici,
      miktar,
      para_birimi,
      odeme_tarihi,
      taksit,
      odendi_mi,
      talimat_varmi,
      faiz_uygulaniyormu,
      bagimli_oldugu_gelir,
      aciklama,
      miktar_belirsiz
    ]);

    const result = insertResult.rows[0];

    // ✅ Kafka event publish
    publishEventAsync(TRANSACTION_TOPICS.DEBT_CREATED, {
      id: result.id,
      kullanici,
      ekleyen_kullanici,
      miktar,
      para_birimi,
      odeme_tarihi,
      taksit,
      odendi_mi,
      talimat_varmi,
      faiz_uygulaniyormu,
      bagimli_oldugu_gelir,
      aciklama,
      miktar_belirsiz,
      tarih: result.tarih
    }, {
      correlationId: req.correlationId || req.id,
      ip: req.ip || req.connection.remoteAddress,
      userAgent: req.get('user-agent') || '',
      userId: req.user?.id || req.user?.username
    });

    res.status(201).json({ 
      success: true,
      message: "Harcama/Borç başarıyla eklendi!",
      data: {
        miktar,
        para_birimi,
        odeme_tarihi,
        kullanici,
        ekleyen_kullanici
      }
    });
  } catch (err) {
    console.error("SQL Hatası (harcama/borc):", err);
    res.status(500).json({
      success: false,
      error: err.message || "Harcama/Borç eklenirken bir hata oluştu"
    });
  }
};

// Harcama/Borçları Getirme
const getAllHarcamaBorc = async (req, res) => {
  try {
    const result = await query(`
      SELECT 
        id, ekleyen_kullanici, miktar, miktar_belirsiz, para_birimi, odeme_tarihi,
        taksit, odendi_mi, talimat_varmi, faiz_uygulaniyormu, bagimli_oldugu_gelir, aciklama
      FROM harcama_borc 
      WHERE kullanici = $1
      ORDER BY odeme_tarihi DESC
    `, [req.user.username]);

    res.status(200).json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error("SQL Hatası (get-all-harcama-borc):", err);
    res.status(500).json({
      success: false,
      error: err.message || "Harcama/Borç verileri alınırken bir hata oluştu"
    });
  }
};

// Harcama/Borç Güncelleme
const updateHarcamaBorc = async (req, res) => {
  try {
    const { id } = req.params;
    let {
      miktar,
      para_birimi = "TRY",
      odeme_tarihi,
      taksit = 1,
      odendi_mi = false,
      talimat_varmi = false,
      faiz_uygulaniyormu = false,
      bagimli_oldugu_gelir = null,
      aciklama = null,
      miktar_belirsiz = false
    } = req.body;
    
    // Boolean değerleri düzgün parse et (string '0' ve '1' için)
    odendi_mi = odendi_mi === '1' || odendi_mi === 1 || odendi_mi === true;
    talimat_varmi = talimat_varmi === '1' || talimat_varmi === 1 || talimat_varmi === true;
    faiz_uygulaniyormu = faiz_uygulaniyormu === '1' || faiz_uygulaniyormu === 1 || faiz_uygulaniyormu === true;
    miktar_belirsiz = miktar_belirsiz === '1' || miktar_belirsiz === 1 || miktar_belirsiz === true;

    // Taksit değerini kontrol et ve düzelt
    if (typeof taksit === 'string') {
      taksit = parseInt(taksit, 10);
    }
    if (isNaN(taksit) || taksit === null || taksit === undefined) {
      taksit = 1; // Default değer
    }

    if (typeof miktar === 'string') {
      miktar = parseFloat(miktar);
    }
    if (isNaN(miktar) || miktar === null || miktar === undefined) {
      return res.status(400).json({
        success: false,
        error: 'Geçersiz miktar değeri. Lütfen sayısal bir değer girin.'
      });
    }

    const kullanici = req.user.username;

    // Check if record exists and belongs to user
    const checkResult = await query(
      'SELECT id FROM harcama_borc WHERE id = $1 AND kullanici = $2',
      [id, kullanici]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Harcama/Borç bulunamadı veya yetkiniz yok'
      });
    }

    // Update the record
    const updateResult = await query(`
      UPDATE harcama_borc
      SET miktar = $1,
          para_birimi = $2,
          odeme_tarihi = $3,
          taksit = $4,
          odendi_mi = $5,
          talimat_varmi = $6,
          faiz_uygulaniyormu = $7,
          bagimli_oldugu_gelir = $8,
          aciklama = $9,
          miktar_belirsiz = $10
      WHERE id = $11 AND kullanici = $12
      RETURNING id, tarih
    `, [
      miktar,
      para_birimi,
      odeme_tarihi,
      taksit,
      odendi_mi,
      talimat_varmi,
      faiz_uygulaniyormu,
      bagimli_oldugu_gelir,
      aciklama,
      miktar_belirsiz,
      id,
      kullanici
    ]);

    const result = updateResult.rows[0];

    // ✅ Kafka event publish
    publishEventAsync(TRANSACTION_TOPICS.DEBT_UPDATED, {
      id: result.id,
      kullanici,
      miktar,
      para_birimi,
      odeme_tarihi,
      taksit,
      odendi_mi,
      talimat_varmi,
      faiz_uygulaniyormu,
      bagimli_oldugu_gelir,
      aciklama,
      miktar_belirsiz,
      tarih: result.tarih
    }, {
      correlationId: req.correlationId || req.id,
      ip: req.ip || req.connection.remoteAddress,
      userAgent: req.get('user-agent') || '',
      userId: req.user?.id || req.user?.username
    });

    res.status(200).json({ 
      success: true,
      message: "Harcama/Borç başarıyla güncellendi!",
      data: { id, miktar, para_birimi, odeme_tarihi, kullanici }
    });
  } catch (err) {
    console.error("Hata oluştu (update-harcama-borc):", err);
    res.status(500).json({
      success: false,
      error: err.message || "Harcama/Borç güncellenirken bir hata oluştu"
    });
  }
};

// Harcama/Borç Silme
const deleteHarcamaBorc = async (req, res) => {
  try {
    const { id } = req.params;
    const kullanici = req.user.username;

    // Check if record exists and belongs to user
    const checkResult = await query(
      'SELECT id, miktar, para_birimi FROM harcama_borc WHERE id = $1 AND kullanici = $2',
      [id, kullanici]
    );

    if (checkResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Harcama/Borç bulunamadı veya yetkiniz yok'
      });
    }

    const deletedRecord = checkResult.rows[0];

    // Delete the record
    await query(
      'DELETE FROM harcama_borc WHERE id = $1 AND kullanici = $2',
      [id, kullanici]
    );

    // ✅ Kafka event publish
    publishEventAsync(TRANSACTION_TOPICS.DEBT_DELETED, {
      id: parseInt(id),
      kullanici,
      miktar: deletedRecord.miktar,
      para_birimi: deletedRecord.para_birimi
    }, {
      correlationId: req.correlationId || req.id,
      ip: req.ip || req.connection.remoteAddress,
      userAgent: req.get('user-agent') || '',
      userId: req.user?.id || req.user?.username
    });

    res.status(200).json({ 
      success: true,
      message: "Harcama/Borç başarıyla silindi!"
    });
  } catch (err) {
    console.error("Hata oluştu (delete-harcama-borc):", err);
    res.status(500).json({
      success: false,
      error: err.message || "Harcama/Borç silinirken bir hata oluştu"
    });
  }
};

module.exports = {
  addHarcamaBorc,
  getAllHarcamaBorc,
  updateHarcamaBorc,
  deleteHarcamaBorc,
};

