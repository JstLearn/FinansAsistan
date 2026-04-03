// controllers/gelirAlacakController.js
// Migrated: MS SQL → PostgreSQL (2025-11-06)
// Event-Driven: Kafka integration added
const { pool, query, transaction } = require("../config/db");
const { publishEventAsync } = require('../services/kafka/producer');
const { TRANSACTION_TOPICS } = require('../services/kafka/topics');

// Gelir-Alacak Ekleme
const addGelirAlacak = async (req, res) => {
  try {
    let {
      miktar,
      para_birimi = "TRY",
      tahsilat_tarihi,
      taksit = 1,
      faiz_uygulaniyormu = false,
      alindi_mi = false,
      talimat_varmi = false,
      bagimli_oldugu_gider = null,
      aciklama = null,
      miktar_belirsiz = false
    } = req.body;
    
    // Boolean değerleri düzgün parse et (string '0' ve '1' için)
    faiz_uygulaniyormu = faiz_uygulaniyormu === '1' || faiz_uygulaniyormu === 1 || faiz_uygulaniyormu === true;
    alindi_mi = alindi_mi === '1' || alindi_mi === 1 || alindi_mi === true;
    talimat_varmi = talimat_varmi === '1' || talimat_varmi === 1 || talimat_varmi === true;
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
    if (miktar < 0) {
      return res.status(400).json({
        success: false,
        error: 'Miktar negatif olamaz.'
      });
    }

    const kullanici = req.activeAccount.username;
    const ekleyen_kullanici = req.user.username;

    const result = await transaction(async (client) => {
      const insertResult = await client.query(`
        INSERT INTO gelir_alacak
          (kullanici, ekleyen_kullanici, miktar, para_birimi, tahsilat_tarihi, 
           taksit, faiz_uygulaniyormu, alindi_mi, talimat_varmi, bagimli_oldugu_gider, aciklama, miktar_belirsiz)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
        RETURNING id, tarih
      `, [kullanici, ekleyen_kullanici, miktar, para_birimi, tahsilat_tarihi, 
          taksit, faiz_uygulaniyormu, alindi_mi, talimat_varmi, bagimli_oldugu_gider, aciklama, miktar_belirsiz]);
      return insertResult.rows[0];
    });

    // ✅ Kafka event publish
    publishEventAsync(TRANSACTION_TOPICS.INCOME_CREATED, {
      id: result.id,
      kullanici,
      ekleyen_kullanici,
      miktar,
      para_birimi,
      tahsilat_tarihi,
      taksit,
      faiz_uygulaniyormu,
      alindi_mi,
      talimat_varmi,
      bagimli_oldugu_gider,
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
      message: "Gelir-Alacak başarıyla eklendi!",
      data: {
        id: result.id,
        tarih: result.tarih,
        miktar,
        para_birimi,
        tahsilat_tarihi,
        kullanici,
        ekleyen_kullanici
      }
    });
  } catch (err) {
    console.error("SQL Hatası (gelir-alacak):", err);
    res.status(500).json({
      success: false,
      error: err.message || "Gelir-Alacak eklenirken bir hata oluştu"
    });
  }
};

// Gelir-Alacakları Getirme
const getAllGelirAlacak = async (req, res) => {
  try {
    const result = await query(`
      SELECT 
        id, ekleyen_kullanici, miktar, miktar_belirsiz, para_birimi, tahsilat_tarihi,
        taksit, faiz_uygulaniyormu, alindi_mi, talimat_varmi, bagimli_oldugu_gider, aciklama
      FROM gelir_alacak 
      WHERE kullanici = $1
    `, [req.activeAccount.username]);

    res.status(200).json({
      success: true,
      data: result.rows
    });
  } catch (err) {
    console.error("SQL Hatası (get-all-gelir-alacak):", err);
    res.status(500).json({
      success: false,
      error: err.message || "Gelir-Alacak verileri alınırken bir hata oluştu"
    });
  }
};

// Gelir-Alacak Güncelleme
const updateGelirAlacak = async (req, res) => {
  try {
    const { id } = req.params;
    let {
      miktar,
      para_birimi = "TRY",
      tahsilat_tarihi,
      taksit = 1,
      faiz_uygulaniyormu = false,
      alindi_mi = false,
      talimat_varmi = false,
      bagimli_oldugu_gider = null,
      aciklama = null,
      miktar_belirsiz = false
    } = req.body;
    
    // Boolean değerleri düzgün parse et (string '0' ve '1' için)
    faiz_uygulaniyormu = faiz_uygulaniyormu === '1' || faiz_uygulaniyormu === 1 || faiz_uygulaniyormu === true;
    alindi_mi = alindi_mi === '1' || alindi_mi === 1 || alindi_mi === true;
    talimat_varmi = talimat_varmi === '1' || talimat_varmi === 1 || talimat_varmi === true;
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
    if (miktar < 0) {
      return res.status(400).json({
        success: false,
        error: 'Miktar negatif olamaz.'
      });
    }

    const kullanici = req.activeAccount.username;

    const result = await transaction(async (client) => {
      // Önce varlığı kontrol et
      const checkResult = await client.query(
        'SELECT * FROM gelir_alacak WHERE id = $1 AND kullanici = $2',
        [id, kullanici]
      );

      if (checkResult.rows.length === 0) {
        throw new Error('Gelir-Alacak bulunamadı veya yetkiniz yok');
      }

      // Güncelle
      const updateResult = await client.query(`
        UPDATE gelir_alacak
        SET miktar = $1,
            para_birimi = $2,
            tahsilat_tarihi = $3,
            taksit = $4,
            faiz_uygulaniyormu = $5,
            alindi_mi = $6,
            talimat_varmi = $7,
            bagimli_oldugu_gider = $8,
            aciklama = $9,
            miktar_belirsiz = $10
        WHERE id = $11 AND kullanici = $12
        RETURNING id, tarih
      `, [miktar, para_birimi, tahsilat_tarihi, taksit, faiz_uygulaniyormu, alindi_mi, talimat_varmi, 
          bagimli_oldugu_gider, aciklama, miktar_belirsiz, id, kullanici]);

      return updateResult.rows[0];
    });

    // ✅ Kafka event publish
    publishEventAsync(TRANSACTION_TOPICS.INCOME_UPDATED, {
      id: result.id,
      kullanici,
      miktar,
      para_birimi,
      tahsilat_tarihi,
      taksit,
      faiz_uygulaniyormu,
      alindi_mi,
      talimat_varmi,
      bagimli_oldugu_gider,
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
      message: "Gelir-Alacak başarıyla güncellendi!",
      data: { id: result.id, tarih: result.tarih, miktar, para_birimi, tahsilat_tarihi, kullanici }
    });
  } catch (err) {
    console.error("Hata oluştu (update-gelir-alacak):", err);
    res.status(500).json({
      success: false,
      error: err.message || "Gelir-Alacak güncellenirken bir hata oluştu"
    });
  }
};

// Gelir-Alacak Silme
const deleteGelirAlacak = async (req, res) => {
  try {
    const { id } = req.params;
    const kullanici = req.activeAccount.username;

    const deletedRecord = await transaction(async (client) => {
      // Önce varlığı kontrol et
      const checkResult = await client.query(
        'SELECT * FROM gelir_alacak WHERE id = $1 AND kullanici = $2',
        [id, kullanici]
      );

      if (checkResult.rows.length === 0) {
        throw new Error('Gelir-Alacak bulunamadı veya yetkiniz yok');
      }

      // Sil
      await client.query(
        'DELETE FROM gelir_alacak WHERE id = $1 AND kullanici = $2',
        [id, kullanici]
      );

      return checkResult.rows[0];
    });

    // ✅ Kafka event publish
    publishEventAsync(TRANSACTION_TOPICS.INCOME_DELETED, {
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
      message: "Gelir-Alacak başarıyla silindi!"
    });
  } catch (err) {
    console.error("Hata oluştu (delete-gelir-alacak):", err);
    
    if (err.message === 'Gelir-Alacak bulunamadı veya yetkiniz yok') {
      return res.status(404).json({
        success: false,
        error: err.message
      });
    }
    
    res.status(500).json({
      success: false,
      error: err.message || "Gelir-Alacak silinirken bir hata oluştu"
    });
  }
};

module.exports = {
  addGelirAlacak,
  getAllGelirAlacak,
  updateGelirAlacak,
  deleteGelirAlacak
};

