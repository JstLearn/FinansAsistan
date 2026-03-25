# FinansAsistan Veritabanı Şeması

PostgreSQL veritabanı tabloları, sütun yapıları ve veri tipleri.

## Veritabanı Bilgileri

- **Database:** FinansAsistan
- **Version:** PostgreSQL 16
- **Encoding:** UTF-8
- **Locale:** tr_TR.UTF-8

## Güncelleme Notları

- **2025-11-11:** Kurulum script'lerine AWS token entegrasyonu eklendi ancak veritabanı şemasında değişiklik yapılmadı. Mevcut tablo yapıları güncelliğini koruyor.

## Tablolar

### 1. kullanicilar

Kullanıcı hesap bilgileri ve doğrulama durumları.

| Kolon | Tip | Null | Varsayılan | Açıklama |
|-------|-----|------|------------|----------|
| id | BIGSERIAL | Hayır | AUTO | Primary key |
| kullanici | VARCHAR(150) | Evet | NULL | Kullanıcı adı (UNIQUE) |
| sifre | VARCHAR(150) | Evet | NULL | Şifrelenmiş parola |
| tarih | DATE | Hayır | CURRENT_DATE | Hesap oluşturma tarihi |
| onaylandi | BOOLEAN | Hayır | FALSE | Email doğrulama durumu |
| verification_token | VARCHAR(50) | Evet | NULL | Email doğrulama token'ı |
| created_at | TIMESTAMP | Evet | CURRENT_TIMESTAMP | Kayıt zamanı |

**Indexes:**
- `idx_kullanicilar_kullanici` ON kullanicilar(kullanici)
- `idx_kullanicilar_verification` ON kullanicilar(verification_token) WHERE verification_token IS NOT NULL

---

### 2. varliklar

Kullanıcı varlıkları (kripto, hisse, emlak, vasıta vb.).

| Kolon | Tip | Null | Varsayılan | Açıklama |
|-------|-----|------|------------|----------|
| id | BIGSERIAL | Hayır | AUTO | Primary key |
| kullanici | VARCHAR(150) | Evet | NULL | Varlık sahibi |
| ekleyen_kullanici | VARCHAR(150) | Evet | NULL | Kaydı ekleyen |
| kategori | VARCHAR(150) | Evet | NULL | KRİPTO PARA, HİSSE SENEDİ, PARA, BONO-TAHVİL, EMLAK, VASITA, DİĞER |
| varlik | VARCHAR(50) | Evet | NULL | Varlık adı/para birimi |
| aciklama | VARCHAR(150) | Evet | NULL | Açıklama |
| saklanildigi_yer | VARCHAR(150) | Evet | NULL | Borsa, cüzdan, banka vb. |
| alis_tarihi | TIMESTAMP | Evet | NULL | Alış tarihi |
| alis_para_birimi | VARCHAR(50) | Evet | NULL | TL, USD, EUR vb. |
| alis_fiyati | NUMERIC(18,8) | Evet | NULL | Alış fiyatı |
| alis_adedi | NUMERIC(18,8) | Evet | NULL | Alınan miktar |
| simdi_fiyati_USD | NUMERIC(18,8) | Evet | NULL | Güncel fiyat (USD) |
| kar_zarar | NUMERIC(18,8) | Evet | NULL | Toplam kar/zarar (USD) |
| kar_zarar_yuzde | NUMERIC(18,8) | Evet | NULL | Yüzdelik kar/zarar |
| min_satis_fiyati_USD | NUMERIC(18,8) | Evet | NULL | Minimum satış fiyatı (USD) |
| link | TEXT | Evet | NULL | Sahibinden link (EMLAK/VASITA) |
| metrekare | INTEGER | Evet | NULL | Metrekare (EMLAK) |
| tarih | TIMESTAMP | Hayır | CURRENT_TIMESTAMP | Kayıt tarihi |

**Indexes:**
- `idx_varliklar_kullanici` ON varliklar(kullanici)
- `idx_varliklar_kategori` ON varliklar(kategori)
- `idx_varliklar_tarih` ON varliklar(tarih DESC)
- `idx_varliklar_kullanici_kategori` ON varliklar(kullanici, kategori)

---

### 3. harcama_borc

Harcama ve borç kayıtları.

| Kolon | Tip | Null | Varsayılan | Açıklama |
|-------|-----|------|------------|----------|
| id | BIGSERIAL | Hayır | AUTO | Primary key |
| kullanici | VARCHAR(150) | Evet | NULL | Harcama sahibi |
| ekleyen_kullanici | VARCHAR(150) | Evet | NULL | Kaydı ekleyen |
| miktar | NUMERIC(18,2) | Evet | NULL | Harcama/borç tutarı |
| miktar_belirsiz | BOOLEAN | Evet | FALSE | Tahmini tutar mı |
| para_birimi | VARCHAR(10) | Evet | 'TRY' | TRY, USD, EUR |
| odeme_tarihi | TIMESTAMP | Evet | NULL | Ödeme tarihi |
| taksit | INTEGER | Evet | 1 | Taksit sayısı |
| odendi_mi | BOOLEAN | Evet | NULL | Ödenme durumu |
| talimat_varmi | BOOLEAN | Evet | FALSE | Otomatik ödeme talimatı |
| faiz_uygulaniyormu | BOOLEAN | Evet | FALSE | Faiz uygulanıyor mu |
| bagimli_oldugu_gelir | VARCHAR(150) | Evet | NULL | Bağlı gelir kaydı |
| aciklama | VARCHAR(150) | Evet | NULL | Açıklama |
| tarih | TIMESTAMP | Hayır | CURRENT_TIMESTAMP | Kayıt tarihi |

**Indexes:**
- `idx_harcama_borc_kullanici` ON harcama_borc(kullanici)
- `idx_harcama_borc_odeme_tarihi` ON harcama_borc(odeme_tarihi)
- `idx_harcama_borc_odendi` ON harcama_borc(odendi_mi)
- `idx_harcama_borc_kullanici_odeme` ON harcama_borc(kullanici, odeme_tarihi)

---

### 4. gelir_alacak

Gelir ve alacak kayıtları.

| Kolon | Tip | Null | Varsayılan | Açıklama |
|-------|-----|------|------------|----------|
| id | BIGSERIAL | Hayır | AUTO | Primary key |
| kullanici | VARCHAR(150) | Evet | NULL | Gelir sahibi |
| ekleyen_kullanici | VARCHAR(150) | Evet | NULL | Kaydı ekleyen |
| miktar | NUMERIC(18,2) | Evet | NULL | Gelir tutarı |
| miktar_belirsiz | BOOLEAN | Evet | FALSE | Tahmini tutar mı |
| para_birimi | VARCHAR(10) | Evet | 'TRY' | TRY, USD, EUR |
| tahsilat_tarihi | TIMESTAMP | Evet | NULL | Tahsilat tarihi |
| taksit | INTEGER | Evet | 1 | Taksit sayısı |
| faiz_uygulaniyormu | BOOLEAN | Evet | FALSE | Faiz uygulanıyor mu |
| alindi_mi | BOOLEAN | Evet | FALSE | Gelir alındı mı |
| talimat_varmi | BOOLEAN | Evet | FALSE | Otomatik tahsilat talimatı |
| bagimli_oldugu_gider | VARCHAR(150) | Evet | NULL | Bağlı gider kaydı |
| aciklama | VARCHAR(150) | Evet | NULL | Açıklama |
| tarih | TIMESTAMP | Hayır | CURRENT_TIMESTAMP | Kayıt tarihi |

**Indexes:**
- `idx_gelir_alacak_kullanici` ON gelir_alacak(kullanici)
- `idx_gelir_alacak_tahsilat_tarihi` ON gelir_alacak(tahsilat_tarihi)
- `idx_gelir_alacak_alindi` ON gelir_alacak(alindi_mi)
- `idx_gelir_alacak_kullanici_tahsilat` ON gelir_alacak(kullanici, tahsilat_tarihi)

---

### 5. istekler

Kullanıcı istek ve önerileri.

| Kolon | Tip | Null | Varsayılan | Açıklama |
|-------|-----|------|------------|----------|
| id | BIGSERIAL | Hayır | AUTO | Primary key |
| kullanici | VARCHAR(150) | Evet | NULL | İsteği yapan |
| ekleyen_kullanici | VARCHAR(150) | Evet | NULL | Kaydı ekleyen |
| kategori | VARCHAR(50) | Evet | NULL | ALIŞVERİŞ, EMLAK, VASITA |
| link | TEXT | Evet | NULL | İlgili link |
| miktar | NUMERIC(18,8) | Evet | NULL | Fiyat bilgisi |
| para_birimi | VARCHAR(50) | Evet | NULL | TL, USD, EUR vb. |
| aciklama | VARCHAR(150) | Evet | NULL | Açıklama |
| oncelik | VARCHAR(50) | Evet | NULL | İstek/İhtiyaç |
| tarih | TIMESTAMP | Hayır | CURRENT_TIMESTAMP | Kayıt tarihi |

**Indexes:**
- `idx_istekler_kullanici` ON istekler(kullanici)
- `idx_istekler_kategori` ON istekler(kategori)
- `idx_istekler_oncelik` ON istekler(oncelik)

---

### 6. hatirlatmalar

Hatırlatma kayıtları.

| Kolon | Tip | Null | Varsayılan | Açıklama |
|-------|-----|------|------------|----------|
| id | BIGSERIAL | Hayır | AUTO | Primary key |
| kullanici | VARCHAR(150) | Evet | NULL | Hatırlatma sahibi |
| ekleyen_kullanici | VARCHAR(150) | Evet | NULL | Kaydı ekleyen |
| hatirlatilacak_olay | TEXT | Evet | NULL | Olay açıklaması |
| olay_zamani | TIMESTAMP | Evet | NULL | Olay tarihi/saati |
| tarih | TIMESTAMP | Hayır | CURRENT_TIMESTAMP | Kayıt tarihi |

**Indexes:**
- `idx_hatirlatmalar_kullanici` ON hatirlatmalar(kullanici)
- `idx_hatirlatmalar_olay_zamani` ON hatirlatmalar(olay_zamani)
- `idx_hatirlatmalar_pending` ON hatirlatmalar(olay_zamani) WHERE olay_zamani > CURRENT_TIMESTAMP

---

### 7. yetkiler

Kullanıcılar arası yetki yönetimi.

| Kolon | Tip | Null | Varsayılan | Açıklama |
|-------|-----|------|------------|----------|
| id | BIGSERIAL | Hayır | AUTO | Primary key |
| yetki_veren_kullanici | VARCHAR(150) | Hayır | - | Yetki veren |
| yetkili_kullanici | VARCHAR(150) | Hayır | - | Yetki alan |
| varlik_ekleme | BOOLEAN | Hayır | FALSE | Varlık ekleme yetkisi |
| gelir_ekleme | BOOLEAN | Hayır | FALSE | Gelir ekleme yetkisi |
| harcama_borc_ekleme | BOOLEAN | Hayır | FALSE | Harcama/borç ekleme yetkisi |
| istek_ekleme | BOOLEAN | Hayır | FALSE | İstek ekleme yetkisi |
| hatirlatma_ekleme | BOOLEAN | Hayır | FALSE | Hatırlatma ekleme yetkisi |
| aktif | BOOLEAN | Hayır | TRUE | Yetki aktif mi |
| tarih | TIMESTAMP | Hayır | CURRENT_TIMESTAMP | Yetki verilme tarihi |

**Constraints:**
- UNIQUE(yetki_veren_kullanici, yetkili_kullanici)

**Indexes:**
- `idx_yetkiler_yetki_veren` ON yetkiler(yetki_veren_kullanici)
- `idx_yetkiler_yetkili` ON yetkiler(yetkili_kullanici)
- `idx_yetkiler_aktif` ON yetkiler(aktif)

---

### 8. pariteler

Borsa ve piyasa pariteleri.

| Kolon | Tip | Null | Varsayılan | Açıklama |
|-------|-----|------|------------|----------|
| id | SERIAL | Hayır | AUTO | Primary key |
| parite | VARCHAR(50) | Evet | NULL | Parite adı (örn: BTC/USDT) |
| borsa | VARCHAR(50) | Evet | NULL | BINANCE, COMMODITY vb. |
| tip | VARCHAR(50) | Evet | NULL | SPOT, FUTURES, COMMODITY |
| ulke | VARCHAR(50) | Evet | NULL | İlgili ülke |
| aciklama | VARCHAR(500) | Evet | NULL | Açıklama |
| aktif | BOOLEAN | Evet | NULL | Aktif mi |
| veri_var | BOOLEAN | Evet | NULL | Veri var mı |
| veriler_guncel | BOOLEAN | Evet | NULL | Veriler güncel mi |
| kayit_tarihi | TIMESTAMP | Hayır | CURRENT_TIMESTAMP | Kayıt tarihi |

**Indexes:**
- `idx_pariteler_parite_kayit` ON pariteler(parite, kayit_tarihi)
- `idx_pariteler_borsa` ON pariteler(borsa)
- `idx_pariteler_aktif` ON pariteler(aktif) WHERE aktif = TRUE

---

### 9. kurlar

Döviz ve kur verileri (Kline/Candlestick).

| Kolon | Tip | Null | Varsayılan | Açıklama |
|-------|-----|------|------------|----------|
| id | BIGSERIAL | Hayır | AUTO | Primary key |
| parite | VARCHAR(50) | Evet | NULL | Kur çifti (örn: BTC/USDT) |
| interval | VARCHAR(50) | Evet | NULL | Veri aralığı (1h, 1d vb.) |
| klines_id | BIGINT | Evet | NULL | Kline ID |
| open_time | TIMESTAMP | Evet | NULL | Açılış zamanı |
| open | NUMERIC(18,8) | Evet | NULL | Açılış fiyatı |
| high | NUMERIC(18,8) | Evet | NULL | En yüksek fiyat |
| low | NUMERIC(18,8) | Evet | NULL | En düşük fiyat |
| close | NUMERIC(18,8) | Evet | NULL | Kapanış fiyatı |
| volume | NUMERIC(18,8) | Evet | NULL | İşlem hacmi |
| close_time | TIMESTAMP | Evet | NULL | Kapanış zamanı |
| quote_asset_volume | NUMERIC(18,8) | Evet | NULL | Quote asset hacmi |
| number_of_trades | INTEGER | Evet | NULL | İşlem sayısı |
| taker_buy_base_asset_volume | NUMERIC(18,8) | Evet | NULL | Taker buy base volume |
| taker_buy_quote_asset_volume | NUMERIC(18,8) | Evet | NULL | Taker buy quote volume |
| created_at | TIMESTAMP | Evet | CURRENT_TIMESTAMP | Kayıt tarihi |

**Indexes:**
- `idx_kurlar_parite_interval` ON kurlar(parite, interval)
- `idx_kurlar_klines_id` ON kurlar(klines_id)
- `idx_kurlar_open_time` ON kurlar(open_time DESC)
- `idx_kurlar_close_time` ON kurlar(close_time DESC)

---

## Veri Tipleri

### Sayısal Tipler
- **BIGSERIAL**: Otomatik artan büyük tam sayı (ID'ler için)
- **SERIAL**: Otomatik artan tam sayı
- **INTEGER**: Tam sayı
- **NUMERIC(p,s)**: Hassas sayısal değer
  - `NUMERIC(18,2)`: Para tutarları (2 ondalık)
  - `NUMERIC(18,8)`: Kur ve varlık hesaplamaları (8 ondalık)

### Metin Tipler
- **VARCHAR(n)**: Değişken uzunlukta metin (max n karakter)
- **TEXT**: Sınırsız metin

### Tarih/Saat Tipler
- **DATE**: Tarih (sadece tarih)
- **TIMESTAMP**: Tarih ve saat

### Mantıksal Tipler
- **BOOLEAN**: TRUE/FALSE

---

## İlişkiler

Tablolar arasında fiziksel foreign key yok, soft reference kullanılıyor:

- `varliklar.kullanici` → `kullanicilar.kullanici`
- `harcama_borc.kullanici` → `kullanicilar.kullanici`
- `gelir_alacak.kullanici` → `kullanicilar.kullanici`
- `harcama_borc.bagimli_oldugu_gelir` → `gelir_alacak.kullanici`
- `gelir_alacak.bagimli_oldugu_gider` → `harcama_borc.kullanici`
- `yetkiler.yetki_veren_kullanici` → `kullanicilar.kullanici`
- `yetkiler.yetkili_kullanici` → `kullanicilar.kullanici`

---

## Migration Script

Tablolar `scripts/migrations/001_initial_schema.sql` dosyasında tanımlıdır.

**Çalıştırma:**
```bash
psql -U finans -d FinansAsistan -f scripts/migrations/001_initial_schema.sql
```

---

**Son Güncelleme:** 2025-01-27  
**PostgreSQL Versiyonu:** 16
