-- ════════════════════════════════════════════════════════════
-- FinansAsistan - PostgreSQL Database Migration Script
-- Migration: MS SQL Server → PostgreSQL
-- ════════════════════════════════════════════════════════════

-- Database oluştur (eğer yoksa)
-- CREATE DATABASE "FinansAsistan" WITH ENCODING 'UTF8' LC_COLLATE='tr_TR.UTF-8' LC_CTYPE='tr_TR.UTF-8';

-- Connect to database
-- \c "FinansAsistan"

-- 1. kullanicilar
CREATE TABLE IF NOT EXISTS kullanicilar (
    id BIGSERIAL PRIMARY KEY,
    kullanici VARCHAR(150) UNIQUE,
    sifre VARCHAR(150),
    tarih DATE NOT NULL DEFAULT CURRENT_DATE,
    onaylandi BOOLEAN NOT NULL DEFAULT FALSE,
    verification_token VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_kullanicilar_kullanici ON kullanicilar(kullanici);
CREATE INDEX IF NOT EXISTS idx_kullanicilar_verification ON kullanicilar(verification_token) WHERE verification_token IS NOT NULL;

-- 2. varliklar
CREATE TABLE IF NOT EXISTS varliklar (
    id BIGSERIAL PRIMARY KEY,
    kullanici VARCHAR(150),
    ekleyen_kullanici VARCHAR(150),
    kategori VARCHAR(150),
    varlik VARCHAR(50),
    aciklama VARCHAR(150),
    saklanildigi_yer VARCHAR(150),
    alis_tarihi TIMESTAMP,
    alis_para_birimi VARCHAR(50),
    alis_fiyati NUMERIC(18,8),
    alis_adedi NUMERIC(18,8),
    simdi_fiyati_USD NUMERIC(18,8),
    kar_zarar NUMERIC(18,8),
    kar_zarar_yuzde NUMERIC(18,8),
    min_satis_fiyati_USD NUMERIC(18,8),
    link TEXT,
    metrekare INTEGER,
    tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_varliklar_kullanici ON varliklar(kullanici);
CREATE INDEX IF NOT EXISTS idx_varliklar_kategori ON varliklar(kategori);
CREATE INDEX IF NOT EXISTS idx_varliklar_tarih ON varliklar(tarih DESC);
CREATE INDEX IF NOT EXISTS idx_varliklar_kullanici_kategori ON varliklar(kullanici, kategori);

-- 3. harcama_borc
CREATE TABLE IF NOT EXISTS harcama_borc (
    id BIGSERIAL PRIMARY KEY,
    kullanici VARCHAR(150),
    ekleyen_kullanici VARCHAR(150),
    miktar NUMERIC(18,2),
    miktar_belirsiz BOOLEAN DEFAULT FALSE,
    para_birimi VARCHAR(10) DEFAULT 'TRY',
    odeme_tarihi TIMESTAMP,
    taksit INTEGER DEFAULT 1,
    odendi_mi BOOLEAN,
    talimat_varmi BOOLEAN DEFAULT FALSE,
    faiz_uygulaniyormu BOOLEAN DEFAULT FALSE,
    bagimli_oldugu_gelir VARCHAR(150),
    aciklama VARCHAR(150),
    tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_harcama_borc_kullanici ON harcama_borc(kullanici);
CREATE INDEX IF NOT EXISTS idx_harcama_borc_odeme_tarihi ON harcama_borc(odeme_tarihi);
CREATE INDEX IF NOT EXISTS idx_harcama_borc_odendi ON harcama_borc(odendi_mi);
CREATE INDEX IF NOT EXISTS idx_harcama_borc_kullanici_odeme ON harcama_borc(kullanici, odeme_tarihi);

-- 4. gelir_alacak
CREATE TABLE IF NOT EXISTS gelir_alacak (
    id BIGSERIAL PRIMARY KEY,
    kullanici VARCHAR(150),
    ekleyen_kullanici VARCHAR(150),
    miktar NUMERIC(18,2),
    miktar_belirsiz BOOLEAN DEFAULT FALSE,
    para_birimi VARCHAR(10) DEFAULT 'TRY',
    tahsilat_tarihi TIMESTAMP,
    taksit INTEGER DEFAULT 1,
    faiz_uygulaniyormu BOOLEAN DEFAULT FALSE,
    alindi_mi BOOLEAN DEFAULT FALSE,
    talimat_varmi BOOLEAN DEFAULT FALSE,
    bagimli_oldugu_gider VARCHAR(150),
    aciklama VARCHAR(150),
    tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_gelir_alacak_kullanici ON gelir_alacak(kullanici);
CREATE INDEX IF NOT EXISTS idx_gelir_alacak_tahsilat_tarihi ON gelir_alacak(tahsilat_tarihi);
CREATE INDEX IF NOT EXISTS idx_gelir_alacak_alindi ON gelir_alacak(alindi_mi);
CREATE INDEX IF NOT EXISTS idx_gelir_alacak_kullanici_tahsilat ON gelir_alacak(kullanici, tahsilat_tarihi);

-- 5. istekler
CREATE TABLE IF NOT EXISTS istekler (
    id BIGSERIAL PRIMARY KEY,
    kullanici VARCHAR(150),
    ekleyen_kullanici VARCHAR(150),
    kategori VARCHAR(50),
    link TEXT,
    miktar NUMERIC(18,8),
    para_birimi VARCHAR(50),
    aciklama VARCHAR(150),
    oncelik VARCHAR(50),
    tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_istekler_kullanici ON istekler(kullanici);
CREATE INDEX IF NOT EXISTS idx_istekler_kategori ON istekler(kategori);
CREATE INDEX IF NOT EXISTS idx_istekler_oncelik ON istekler(oncelik);

-- 6. hatirlatmalar
CREATE TABLE IF NOT EXISTS hatirlatmalar (
    id BIGSERIAL PRIMARY KEY,
    kullanici VARCHAR(150),
    ekleyen_kullanici VARCHAR(150),
    hatirlatilacak_olay TEXT,
    olay_zamani TIMESTAMP,
    tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_hatirlatmalar_kullanici ON hatirlatmalar(kullanici);
CREATE INDEX IF NOT EXISTS idx_hatirlatmalar_olay_zamani ON hatirlatmalar(olay_zamani);
-- Note: Partial index with CURRENT_TIMESTAMP removed - CURRENT_TIMESTAMP is not immutable
-- Use application-level filtering for pending reminders instead

-- 7. yetkiler
CREATE TABLE IF NOT EXISTS yetkiler (
    id BIGSERIAL PRIMARY KEY,
    yetki_veren_kullanici VARCHAR(150) NOT NULL,
    yetkili_kullanici VARCHAR(150) NOT NULL,
    varlik_ekleme BOOLEAN NOT NULL DEFAULT FALSE,
    gelir_ekleme BOOLEAN NOT NULL DEFAULT FALSE,
    harcama_borc_ekleme BOOLEAN NOT NULL DEFAULT FALSE,
    istek_ekleme BOOLEAN NOT NULL DEFAULT FALSE,
    hatirlatma_ekleme BOOLEAN NOT NULL DEFAULT FALSE,
    aktif BOOLEAN NOT NULL DEFAULT TRUE,
    tarih TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(yetki_veren_kullanici, yetkili_kullanici)
);

CREATE INDEX IF NOT EXISTS idx_yetkiler_yetki_veren ON yetkiler(yetki_veren_kullanici);
CREATE INDEX IF NOT EXISTS idx_yetkiler_yetkili ON yetkiler(yetkili_kullanici);
CREATE INDEX IF NOT EXISTS idx_yetkiler_aktif ON yetkiler(aktif);

-- 8. pariteler
CREATE TABLE IF NOT EXISTS pariteler (
    id SERIAL PRIMARY KEY,
    parite VARCHAR(50),
    borsa VARCHAR(50),
    tip VARCHAR(50),
    ulke VARCHAR(50),
    aciklama VARCHAR(500),
    aktif BOOLEAN,
    veri_var BOOLEAN,
    veriler_guncel BOOLEAN,
    kayit_tarihi TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_pariteler_parite_kayit ON pariteler(parite, kayit_tarihi);
CREATE INDEX IF NOT EXISTS idx_pariteler_borsa ON pariteler(borsa);
CREATE INDEX IF NOT EXISTS idx_pariteler_aktif ON pariteler(aktif) WHERE aktif = TRUE;

-- 9. kurlar
CREATE TABLE IF NOT EXISTS kurlar (
    id BIGSERIAL PRIMARY KEY,
    parite VARCHAR(50),
    interval VARCHAR(50),
    klines_id BIGINT,
    open_time TIMESTAMP,
    open NUMERIC(18,8),
    high NUMERIC(18,8),
    low NUMERIC(18,8),
    close NUMERIC(18,8),
    volume NUMERIC(18,8),
    close_time TIMESTAMP,
    quote_asset_volume NUMERIC(18,8),
    number_of_trades INTEGER,
    taker_buy_base_asset_volume NUMERIC(18,8),
    taker_buy_quote_asset_volume NUMERIC(18,8),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_kurlar_parite_interval ON kurlar(parite, interval);
CREATE INDEX IF NOT EXISTS idx_kurlar_klines_id ON kurlar(klines_id);
CREATE INDEX IF NOT EXISTS idx_kurlar_open_time ON kurlar(open_time DESC);
CREATE INDEX IF NOT EXISTS idx_kurlar_close_time ON kurlar(close_time DESC);

-- Migration complete
SELECT 'Migration completed successfully!' AS status;

