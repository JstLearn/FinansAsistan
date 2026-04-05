# Plan: Mobilde Buton Basılı Kalma Sorunu

## Context

Mobile tarayıcıda butona basılınca `isPressed` state'i `true` oluyor. `onPressOut` güvenilir şekilde tetiklenmediğinde buton basılı pozisyonda kalıyor.

## Sebep

React Native Web'in TouchableOpacity'sı mobile'da `touchend` event'ini düzgün yakalayamıyor. `onPressOut`/`onPressCancel` çalışmıyor.

## Çözüm

Timeout-based reset: `onPressIn` tetiklendiğinde 500ms sonra otomatik olarak `isPressed` resetle. Eğer normal `onPressOut` çalışırsa timeout iptal edilir.

### Değiştirilecek Dosyalar

- `front/components/Buttons/MainButton.js`
- `front/components/Buttons/SubButton.js`

### Implementasyon

```javascript
const MainButton = ({ title, onPress, style, textStyle }) => {
  const [isHovered, setIsHovered] = useState(false);
  const [isPressed, setIsPressed] = useState(false);
  const pressTimeoutRef = useRef(null);

  const clearPressTimeout = () => {
    if (pressTimeoutRef.current) {
      clearTimeout(pressTimeoutRef.current);
      pressTimeoutRef.current = null;
    }
  };

  const handlePressIn = () => {
    setIsPressed(true);
    // Timeout ile yedek reset - mobile'da onPressOut çalışmazsa
    clearPressTimeout();
    pressTimeoutRef.current = setTimeout(() => {
      setIsPressed(false);
    }, 500);
  };

  const handlePressOut = () => {
    clearPressTimeout();
    setIsPressed(false);
  };

  useEffect(() => {
    return () => clearPressTimeout();
  }, []);
```

## Doğrulama

1. Telefonda butona bas → basılı görünüm → parmak kaldır → 500ms içinde normal pozisyona döner
2. Butona basılı tut ve scroll yap → 500ms sonunda resetlenir
3. Masaüstünde hover efekti hâlâ çalışır
