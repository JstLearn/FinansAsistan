# Three.js Efekt Kataloğu

## Hızlı Başlangıç

Katalog demosunu tarayıcınızda açın:

```
http://localhost:9988/threejs-showcase.html
```

## Mevcut Efektler

| Efekt | İkon | Açıklama |
|-------|------|----------|
| **Smoke Trail** | 💨 | Mouse hareket yönünde ileri doğru püsküren duman (sizin isteğiniz) |
| **Fire Particles** | 🔥 | Yukarı yükselen ateş parçacıkları (kırmızı/turuncu) |
| **Sparkles** | ✨ | Mouse'u takip eden ışıltılı parçacıklar |
| **Matrix Rain** | 🌧️ | Aşağı düşen yeşil kod parçacıkları |
| **Warp Stars** | ⭐ | Merkezden dışa doğru hızlanan yıldızlar |
| **Flow Field** | 🌊 | Perlin noise tabanlı akış hareketi |

## Kontroller

### Efekt Seçimi
- Sol üstteki katalog kartlarına tıklayarak efektler arasında geçiş yapın
- Her efektin adı ve açıklaması bilgi panelinde görünür

### Slider Ayarları
| Slider | Aralık | Açıklama |
|--------|--------|----------|
| **Particle Count** | 50-500 | Ekrandaki maksimum parçacık sayısı |
| **Speed** | 1-100 | Hareket/animasyon hızı |
| **Size** | 1-100 | Parçacık boyutu |
| **Hue** | 0-360 | Renk tonu (HSV renk çemberi) |
| **Color Speed** | 0-100 | Renk değişim hızı |

## Teknik Detaylar

- **Three.js Versiyon**: r128 (cdnjs.cloudflare.com)
- **Kamera**: PerspectiveCamera (FOV: 75, z: 5)
- **Renderer**: WebGLRenderer (alpha: true, antialias: true)
- **Blending**: AdditiveBlending (glow efekti için)
- **Geometry**: BufferGeometry (position, color, size attributes)
- **Mouse Tracking**: Three.js NDC koordinatları (-1 ile 1 arası)

## Smoke Trail Efekt Mekanizması

Sizin istediğiniz "mouse nereye gidiyorsa o yöne duman püskürtme" efekti şu şekilde çalışır:

1. Mouse hız vektörü hesaplanır: `vx = newX - prevX`, `vy = newY - prevY`
2. Hareket açısı bulunur: `Math.atan2(vy, vx)`
3. Bu açıya göre parçacıklar ileri doğru püskürtülür
4. Spread açısı: ±0.3 radyan (~17 derece koni)

## Sonraki Adımlar

1. **Efekt Seçimi**: Katalogdaki efektleri deneyin ve hangisini beğendiğinizi seçin
2. **Ana Uygulamaya Entegrasyon**: Seçilen efekti FinansAsistan React uygulamasına entegre edebiliriz
3. **Özelleştirme**: Seçilen efektin parametrelerini (renk, yoğunluk, hız) ayarlayabiliriz

## Dosya Yapısı

```
front/
├── threejs-showcase.html    # Ana katalog demo (6 efekt)
├── demo-smoke.html          # Sadece smoke efekti (debug loglu)
├── test-threejs.html        # Three.js yükleme test sayfası
└── README-THREEJS.md        # Bu dosya
```

## Sorun Giderme

### Efektler Görünmüyorsa
1. Three.js CDN bağlantısını kontrol edin
2. Tarayıcı konsolunu açın (F12) ve hata var mı bakın
3. WebGL desteği olup olmadığını test edin: https://get.webgl.org/

### Performans Sorunları
- Particle Count'u düşürün (200-300 arası ideal)
- Speed'i azaltın
- Daha basit efekt deneyin (Matrix Rain en hafif)
