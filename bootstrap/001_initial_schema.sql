-- ════════════════════════════════════════════════════════════
-- FinansAsistan - Initial Schema
-- ════════════════════════════════════════════════════════════

-- Kullanıcılar tablosu
CREATE TABLE IF NOT EXISTS kullanicilar (
    id SERIAL PRIMARY KEY,
    kullanici VARCHAR(150) UNIQUE NOT NULL,
    sifre VARCHAR(255) NOT NULL,
    verification_token VARCHAR(100),
    onaylandi BOOLEAN DEFAULT FALSE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Hatırlatmalar tablosu
CREATE TABLE IF NOT EXISTS hatirlatmalar (
    id SERIAL PRIMARY KEY,
    kullanici VARCHAR(150) NOT NULL,
    ekleyen_kullanici VARCHAR(150),
    hatirlatilacak_olay VARCHAR(500),
    olay_zamani TIMESTAMP,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    aktif BOOLEAN DEFAULT TRUE
);

-- Harcama/Borc tablosu
CREATE TABLE IF NOT EXISTS harcama_borc (
    id SERIAL PRIMARY KEY,
    kullanici VARCHAR(150) NOT NULL,
    ekleyen_kullanici VARCHAR(150),
    miktar DECIMAL(15,2),
    miktar_belirsiz BOOLEAN DEFAULT FALSE,
    para_birimi VARCHAR(10) DEFAULT 'TRY',
    odeme_tarihi DATE,
    aciklama TEXT,
    kategori VARCHAR(100),
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Gelir/Alacak tablosu
CREATE TABLE IF NOT EXISTS gelir_alacak (
    id SERIAL PRIMARY KEY,
    kullanici VARCHAR(150) NOT NULL,
    ekleyen_kullanici VARCHAR(150),
    miktar DECIMAL(15,2),
    miktar_belirsiz BOOLEAN DEFAULT FALSE,
    para_birimi VARCHAR(10) DEFAULT 'TRY',
    tahsilat_tarihi DATE,
    aciklama TEXT,
    kategori VARCHAR(100),
    bagimli_oldugu_gider INTEGER,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Varlıklar tablosu
CREATE TABLE IF NOT EXISTS varliklar (
    id SERIAL PRIMARY KEY,
    kullanici VARCHAR(150) NOT NULL,
    ekleyen_kullanici VARCHAR(150),
    kategori VARCHAR(100),
    varlik VARCHAR(200),
    aciklama TEXT,
    saklanildigi_yer VARCHAR(200),
    deger DECIMAL(15,2),
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- İstekler tablosu
CREATE TABLE IF NOT EXISTS istekler (
    id SERIAL PRIMARY KEY,
    kullanici VARCHAR(150) NOT NULL,
    ekleyen_kullanici VARCHAR(150),
    kategori VARCHAR(100),
    link TEXT,
    aciklama TEXT,
    miktar DECIMAL(15,2),
    para_birimi VARCHAR(10) DEFAULT 'TRY',
    oncelik INTEGER DEFAULT 0,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Yetkiler tablosu
CREATE TABLE IF NOT EXISTS yetkiler (
    id SERIAL PRIMARY KEY,
    yetki_veren_kullanici VARCHAR(150) NOT NULL,
    yetkili_kullanici VARCHAR(150) NOT NULL,
    yetki_turu VARCHAR(50),
    aktif BOOLEAN DEFAULT TRUE,
    tarih TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    varlik_ekleme BOOLEAN DEFAULT FALSE,
    varlik_silme BOOLEAN DEFAULT FALSE,
    varlik_duzenleme BOOLEAN DEFAULT FALSE,
    gelir_ekleme BOOLEAN DEFAULT FALSE,
    gelir_silme BOOLEAN DEFAULT FALSE,
    gelir_duzenleme BOOLEAN DEFAULT FALSE,
    harcama_borc_ekleme BOOLEAN DEFAULT FALSE,
    harcama_borc_silme BOOLEAN DEFAULT FALSE,
    harcama_borc_duzenleme BOOLEAN DEFAULT FALSE,
    istek_ekleme BOOLEAN DEFAULT FALSE,
    istek_silme BOOLEAN DEFAULT FALSE,
    istek_duzenleme BOOLEAN DEFAULT FALSE,
    hatirlatma_ekleme BOOLEAN DEFAULT FALSE,
    hatirlatma_silme BOOLEAN DEFAULT FALSE,
    hatirlatma_duzenleme BOOLEAN DEFAULT FALSE
);
-- Migration: boolean yetki kolonları (mevcut tablolara ekle)
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS varlik_ekleme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS varlik_silme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS varlik_duzenleme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS gelir_ekleme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS gelir_silme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS gelir_duzenleme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS harcama_borc_ekleme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS harcama_borc_silme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS harcama_borc_duzenleme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS istek_ekleme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS istek_silme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS istek_duzenleme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS hatirlatma_ekleme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS hatirlatma_silme BOOLEAN DEFAULT FALSE;
ALTER TABLE yetkiler ADD COLUMN IF NOT EXISTS hatirlatma_duzenleme BOOLEAN DEFAULT FALSE;

-- Indexes
CREATE INDEX IF NOT EXISTS idx_kullanicilar_kullanici ON kullanicilar(kullanici);
CREATE INDEX IF NOT EXISTS idx_hatirlatmalar_kullanici ON hatirlatmalar(kullanici);
CREATE INDEX IF NOT EXISTS idx_harcama_borc_kullanici ON harcama_borc(kullanici);
CREATE INDEX IF NOT EXISTS idx_gelir_alacak_kullanici ON gelir_alacak(kullanici);
CREATE INDEX IF NOT EXISTS idx_varliklar_kullanici ON varliklar(kullanici);
CREATE INDEX IF NOT EXISTS idx_istekler_kullanici ON istekler(kullanici);
CREATE INDEX IF NOT EXISTS idx_yetkiler_kullanici ON yetkiler(yetkili_kullanici);
