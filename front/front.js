// front/App.js
import React, { useState, useEffect } from 'react';
import { SafeAreaView, View, Text, ScrollView, Alert, Animated, TouchableOpacity } from 'react-native';
import Header from './components/Header/Header';
import UserInfo from './components/UserInfo';
import MainButton from './components/Buttons/MainButton';
import SubButton from './components/Buttons/SubButton';
import DynamicForm from './components/Forms/DynamicForm';
import DataTable from './components/Tables/DataTable';
import styles from './styles/styles';
import { postData, fetchData } from './services/api';
import AlertModal from './components/Modal/AlertModal';
import LoginModal from './components/LoginModal';
import YetkiModal from './components/YetkiModal';
import { UserProvider, useUser } from './context/UserContext';
import Logo from './components/Logo';
import FluidSimulation from './components/FluidSimulation';
import AdminDashboard from './components/AdminDashboard';

const AppContent = () => {
  // State tanımlamaları
  const [isMainButtonsSmall, setIsMainButtonsSmall] = useState(false);
  const [showDataButtons, setShowDataButtons] = useState(false);
  const [showQueryButtons, setShowQueryButtons] = useState(false);
  const [showForm, setShowForm] = useState(false);
  const [currentEndpoint, setCurrentEndpoint] = useState('');
  const [formFields, setFormFields] = useState([]);
  const [formData, setFormData] = useState({});
  const [errors, setErrors] = useState({});
  const [showTable, setShowTable] = useState(false);
  const [tableTitle, setTableTitle] = useState('');
  const [tableData, setTableData] = useState([]);
  const [formTitle, setFormTitle] = useState('Yeni Veri Ekle');
  const [alertModal, setAlertModal] = useState({
    visible: false,
    title: '',
    message: '',
    onClose: null
  });
  const [selectOptionsData, setSelectOptionsData] = useState({
    gelir: [],
    gider: []
  });
  const [isLoginModalVisible, setLoginModalVisible] = useState(false);
  const [currentAction, setCurrentAction] = useState('');
  const [subButtonsAnimationKey, setSubButtonsAnimationKey] = useState(0);
  const [isClosingSubButtons, setIsClosingSubButtons] = useState(false);
  const [mainButtonsAnimationKey, setMainButtonsAnimationKey] = useState(0);
  const [isResetting, setIsResetting] = useState(false);
  const [formAnimationKey, setFormAnimationKey] = useState(0);
  const [tableAnimationKey, setTableAnimationKey] = useState(0);
  const [isYetkiModalVisible, setYetkiModalVisible] = useState(false);
  const [showAdminPanel, setShowAdminPanel] = useState(false);
  const { user, setUser, activeAccount } = useUser();

  // E-posta doğrulama + Admin panel (URL ?admin=1)
  useEffect(() => {
    const params = new URLSearchParams(window.location.search);

    // Admin panel: ?admin=1
    if (params.get('admin') === '1') {
      setShowAdminPanel(true);
    }

    if (params.get('verify') === '1') {
      const email = params.get('email');
      const code = params.get('code');

      if (email && code) {
        postData('kullanicilar/verify', { email, code })
          .then(data => {
            if (data.success && data.data.token) {
              localStorage.setItem('token', data.data.token);
              setUser({
                token: data.data.token,
                username: data.data.username
              });
              // URL'den verify parametrelerini temizle
              const cleanUrl = window.location.pathname;
              window.history.replaceState({}, document.title, cleanUrl);
            }
          })
          .catch(err => {
            console.error('Doğrulama hatası:', err);
          });
      }
    }
  }, [setUser]);

  // Admin panel shortcut: Alt+X
  useEffect(() => {
    const handleKeyDown = (e) => {
      if (e.altKey && (e.key === 'X' || e.key === 'x')) {
        e.preventDefault();
        setShowAdminPanel(prev => !prev);
      }
    };
    document.addEventListener('keydown', handleKeyDown, { capture: true });
    return () => document.removeEventListener('keydown', handleKeyDown, { capture: true });
  }, []);

  // Ana butonların işleyicileri
  const handleAddData = () => {
    setIsMainButtonsSmall(true);
    setShowForm(false);
    setShowTable(false);

    // Eğer Sorgula sub-butonları açıksa, önce onu kapat (huni efekti)
    if (showQueryButtons) {
      setIsClosingSubButtons(true);
      setTimeout(() => {
        setShowQueryButtons(false);
        setIsClosingSubButtons(false);

        // Kapanma animasyonu bittikten sonra Ekle'yi aç
        setTimeout(() => {
          setShowDataButtons(true);
          setSubButtonsAnimationKey(prev => prev + 1);
        }, 50);
      }, 350); // Kapanma animasyonu süresi
    } else if (showDataButtons) {
      // Zaten Ekle açıksa, önce kapat sonra aç (animasyonlu refresh)
      setIsClosingSubButtons(true);
      setTimeout(() => {
        setShowDataButtons(false);
        setIsClosingSubButtons(false);

        // Kapanma animasyonu bittikten sonra tekrar aç
        setTimeout(() => {
          setShowDataButtons(true);
          setSubButtonsAnimationKey(prev => prev + 1);
        }, 50);
      }, 350);
    } else {
      // Hiçbiri açık değilse, direkt aç
      setShowDataButtons(true);
      setSubButtonsAnimationKey(prev => prev + 1);
    }
  };

  const handleQueryData = () => {
    setIsMainButtonsSmall(true);
    setShowForm(false);
    setShowTable(false);

    // Eğer Ekle sub-butonları açıksa, önce onu kapat (huni efekti)
    if (showDataButtons) {
      setIsClosingSubButtons(true);
      setTimeout(() => {
        setShowDataButtons(false);
        setIsClosingSubButtons(false);

        // Kapanma animasyonu bittikten sonra Sorgula'yı aç
        setTimeout(() => {
          setShowQueryButtons(true);
          setSubButtonsAnimationKey(prev => prev + 1);
        }, 50);
      }, 350); // Kapanma animasyonu süresi
    } else if (showQueryButtons) {
      // Zaten Sorgula açıksa, önce kapat sonra aç (animasyonlu refresh)
      setIsClosingSubButtons(true);
      setTimeout(() => {
        setShowQueryButtons(false);
        setIsClosingSubButtons(false);

        // Kapanma animasyonu bittikten sonra tekrar aç
        setTimeout(() => {
          setShowQueryButtons(true);
          setSubButtonsAnimationKey(prev => prev + 1);
        }, 50);
      }, 350);
    } else {
      // Hiçbiri açık değilse, direkt aç
      setShowQueryButtons(true);
      setSubButtonsAnimationKey(prev => prev + 1);
    }
  };

  // Alt menü butonlarının işleyicileri
  const handleAddVarlik = () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    setCurrentEndpoint('varlik');
    setFormTitle('Yeni Varlık Ekle');
    // FormData'yı temizle (önceki formdan kalan değerleri temizle)
    setFormData({});
    setErrors({});
    setFormFields([
      {
        label: 'Kategori',
        id: 'kategori',
        type: 'select',
        required: true,
        options: [
          { value: 'PARA', label: 'PARA' },
          { value: 'KRİPTO PARA', label: 'KRİPTO PARA' },
          { value: 'HİSSE SENEDİ', label: 'HİSSE SENEDİ' },
          { value: 'BONO-TAHVİL', label: 'BONO-TAHVİL' },
          { value: 'EMLAK', label: 'EMLAK' },
          { value: 'VASITA', label: 'VASITA' },
          { value: 'DİĞER', label: 'DİĞER' }
        ],
        _timestamp: Date.now()
      }
    ]);
    setFormAnimationKey(prev => prev + 1);
    setShowForm(true);
  };

  // Varlık form field'larını döndür
  const getVarlikFields = (selectedKategori = null, selectedParaBirimi = null) => {
    const kategori = selectedKategori || formData.kategori;
    const paraBirimi = selectedParaBirimi || formData.para_birimi_kategori || 'TL';

    // Her seferinde yeni bir baseFields oluştur (animasyon için)
    const createBaseFields = () => [{
      label: 'Kategori',
      id: 'kategori',
      type: 'select',
      required: true,
      options: [
        { value: 'PARA', label: 'PARA' },
        { value: 'KRİPTO PARA', label: 'KRİPTO PARA' },
        { value: 'HİSSE SENEDİ', label: 'HİSSE SENEDİ' },
        { value: 'BONO-TAHVİL', label: 'BONO-TAHVİL' },
        { value: 'EMLAK', label: 'EMLAK' },
        { value: 'VASITA', label: 'VASITA' },
        { value: 'DİĞER', label: 'DİĞER' }
      ],
      _timestamp: Date.now() // Unique identifier for animation reset
    }];

    if (!kategori) return createBaseFields();

    // PARA kategorisi için özel logic
    if (kategori === 'PARA') {
      const fields = [
        ...createBaseFields(),
        { label: 'Alış Tarihi', id: 'alis_tarihi', type: 'date', required: true }
      ];

      // TL değilse Fiyat ekle
      if (paraBirimi !== 'TL') {
        fields.push({ label: 'Fiyat', id: 'alis_fiyati', type: 'number-with-currency', required: true, defaultCurrency: 'TL' });
      }

      fields.push(
        { label: 'Miktar', id: 'alis_adedi', type: 'number', required: true },
        {
          label: 'Saklanıldığı Yer',
          id: 'saklanildigi_yer',
          type: 'select',
          required: true,
          hasCustomInput: true,
          options: [
            { value: 'Enpara Bank', label: 'Enpara Bank' },
            { value: 'Ziraat Bankası', label: 'Ziraat Bankası' },
            { value: 'İş Bankası', label: 'İş Bankası' },
            { value: 'Garanti BBVA', label: 'Garanti BBVA' },
            { value: 'Akbank', label: 'Akbank' },
            { value: 'Yapı Kredi', label: 'Yapı Kredi' },
            { value: 'QNB Finansbank', label: 'QNB Finansbank' },
            { value: 'Denizbank', label: 'Denizbank' },
            { value: 'TEB', label: 'TEB' },
            { value: 'Nakit', label: 'Nakit' }
          ]
        },
        { label: 'Açıklama (Opsiyonel)', id: 'aciklama', type: 'text', required: false }
      );

      return fields;
    }

    // KRİPTO PARA kategorisi
    if (kategori === 'KRİPTO PARA') {
      return [
        ...createBaseFields(),
        { label: 'Alış Tarihi', id: 'alis_tarihi', type: 'date', required: true },
        { label: 'Fiyat', id: 'alis_fiyati', type: 'number-with-currency', required: true, defaultCurrency: 'TL' },
        { label: 'Miktar', id: 'alis_adedi', type: 'number', required: true },
        {
          label: 'Saklanıldığı Yer',
          id: 'saklanildigi_yer',
          type: 'select',
          required: true,
          hasCustomInput: true,
          options: [
            { value: 'Binance', label: 'Binance' },
            { value: 'Coinbase', label: 'Coinbase' },
            { value: 'Kraken', label: 'Kraken' },
            { value: 'Bybit', label: 'Bybit' },
            { value: 'Uniswap', label: 'Uniswap' },
            { value: 'PancakeSwap', label: 'PancakeSwap' },
            { value: 'Ledger', label: 'Ledger' },
            { value: 'Trezor', label: 'Trezor' },
            { value: 'MetaMask', label: 'MetaMask' },
            { value: 'Trust Wallet', label: 'Trust Wallet' }
          ]
        },
        { label: 'Açıklama (Opsiyonel)', id: 'aciklama', type: 'text', required: false }
      ];
    }

    // HİSSE SENEDİ kategorisi
    if (kategori === 'HİSSE SENEDİ') {
      return [
        ...createBaseFields(),
        { label: 'Alış Tarihi', id: 'alis_tarihi', type: 'date', required: true },
        { label: 'Fiyat', id: 'alis_fiyati', type: 'number-with-currency', required: true, defaultCurrency: 'TL' },
        { label: 'Miktar', id: 'alis_adedi', type: 'number', required: true },
        {
          label: 'Saklanıldığı Yer',
          id: 'saklanildigi_yer',
          type: 'select',
          required: true,
          hasCustomInput: true,
          options: [
            { value: 'Midas', label: 'Midas' },
            { value: 'İş Yatırım', label: 'İş Yatırım' },
            { value: 'Garanti Yatırım', label: 'Garanti Yatırım' },
            { value: 'Yapı Kredi Yatırım', label: 'Yapı Kredi Yatırım' },
            { value: 'Ak Yatırım', label: 'Ak Yatırım' },
            { value: 'Gedik Yatırım', label: 'Gedik Yatırım' },
            { value: 'Ata Yatırım', label: 'Ata Yatırım' },
            { value: 'Şeker Yatırım', label: 'Şeker Yatırım' },
            { value: 'Deniz Yatırım', label: 'Deniz Yatırım' }
          ]
        },
        { label: 'Açıklama (Opsiyonel)', id: 'aciklama', type: 'text', required: false }
      ];
    }

    // BONO-TAHVİL kategorisi
    if (kategori === 'BONO-TAHVİL') {
      return [
        ...createBaseFields(),
        { label: 'Alış Tarihi', id: 'alis_tarihi', type: 'date', required: true },
        { label: 'Fiyat', id: 'alis_fiyati', type: 'number-with-currency', required: true, defaultCurrency: 'TL' },
        { label: 'Miktar', id: 'alis_adedi', type: 'number', required: true },
        {
          label: 'Saklanıldığı Yer',
          id: 'saklanildigi_yer',
          type: 'select',
          required: true,
          hasCustomInput: true,
          options: [
            { value: 'Ziraat Bankası', label: 'Ziraat Bankası' },
            { value: 'İş Bankası', label: 'İş Bankası' },
            { value: 'Garanti BBVA', label: 'Garanti BBVA' },
            { value: 'Akbank', label: 'Akbank' },
            { value: 'Yapı Kredi', label: 'Yapı Kredi' },
            { value: 'QNB Finansbank', label: 'QNB Finansbank' },
            { value: 'Hazine ve Maliye Bakanlığı', label: 'Hazine ve Maliye Bakanlığı' }
          ]
        },
        { label: 'Açıklama (Opsiyonel)', id: 'aciklama', type: 'text', required: false }
      ];
    }
    else if (kategori === 'EMLAK') {
      return [
        ...createBaseFields(),
        { label: 'Alış Tarihi', id: 'alis_tarihi', type: 'date', required: true },
        { label: 'Fiyat', id: 'alis_fiyati', type: 'number-with-currency', required: true, defaultCurrency: 'TL' },
        { label: 'Sahibinden Link (Aynı mahallede benzer ilanların listelendiği arama linki)', id: 'link', type: 'text', required: true },
        { label: 'Metrekare', id: 'metrekare', type: 'number', required: true },
        { label: 'Açıklama (Opsiyonel)', id: 'aciklama', type: 'text', required: false }
      ];
    }
    else if (kategori === 'VASITA') {
      return [
        ...createBaseFields(),
        { label: 'Alış Tarihi', id: 'alis_tarihi', type: 'date', required: true },
        { label: 'Fiyat', id: 'alis_fiyati', type: 'number-with-currency', required: true, defaultCurrency: 'TL' },
        { label: 'Sahibinden Link (Aynı mahallede benzer ilanların listelendiği arama linki)', id: 'link', type: 'text', required: true },
        { label: 'Açıklama (Opsiyonel)', id: 'aciklama', type: 'text', required: false }
      ];
    }
    else if (kategori === 'DİĞER') {
      return [
        ...createBaseFields(),
        { label: 'Alış Tarihi', id: 'alis_tarihi', type: 'date', required: true },
        { label: 'Fiyat', id: 'alis_fiyati', type: 'number-with-currency', required: true, defaultCurrency: 'TL' },
        { label: 'Miktar', id: 'alis_adedi', type: 'number', required: true },
        { label: 'Saklanıldığı Yer', id: 'saklanildigi_yer', type: 'text', required: true },
        { label: 'Açıklama (Opsiyonel)', id: 'aciklama', type: 'text', required: false }
      ];
    }

    return createBaseFields();
  };

  // Varlık field'larını güncelle
  const updateVarlikFields = (fieldId, value) => {
    if (currentEndpoint === 'varlik') {
      if (fieldId === 'kategori') {
        setFormFields(getVarlikFields(value, null));

        // Kategori değişince tüm input field'leri temizle (sadece yeni kategoriyi sakla)
        if (value === 'PARA') {
          setFormData({
            kategori: value,
            para_birimi_kategori: 'TL'
          });
        } else {
          setFormData({
            kategori: value
          });
        }

        // Errors'ı da temizle
        setErrors({});
      }
      // Para birimi kategori değişirse field'ları yenile (yeni para birimi ile)
      if (fieldId === 'para_birimi_kategori') {
        setFormFields(getVarlikFields(null, value));

        // Fiyat field'ı görünürlüğü değişebileceği için formData'dan temizle
        // Sadece kategori ve para_birimi_kategori kalsın
        setFormData(prev => ({
          kategori: prev.kategori,
          para_birimi_kategori: value
        }));

        // Errors'ı da temizle
        setErrors({});
      }
    }
  };

  const handleAddBorc = async () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    setCurrentEndpoint('harcama-borc');
    setFormTitle('Yeni Harcama - Borç Ekle');
    // FormData ve Errors'ı temizle
    setErrors({});
    // Default değerleri set et
    const today = new Date().toISOString().split('T')[0];
    setFormData({
      sonra_odeyecegim: false, // Default: işaretsiz, bugün ödendi
      odeme_tarihi: today,
      odendi_mi: true,
      taksit: 1 // Default taksit sayısı
    });

    // Gelir-Alacak verilerini çek (bağımlı gelir seçimi için)
    try {
      const gelirResponse = await fetchData('gelir-alacak');
      if (gelirResponse && Array.isArray(gelirResponse.data)) {
        setSelectOptionsData(prev => ({ ...prev, gelir: gelirResponse.data }));
      }
    } catch (error) {
      // Gelir-Alacak verileri çekilemedi
    }

    // İlk başta tüm field'ları göster
    setFormFields(getHarcamaBorcFields(false)); // sonraOdeyecegim=false
    setShowForm(true);
  };

  // Harcama-Borç form field'larını döndür
  const getHarcamaBorcFields = (sonraOdeyecegim = formData.sonra_odeyecegim) => {
    return [
      {
        label: 'Miktar',
        id: 'miktar',
        type: 'number-with-currency',
        required: !formData.miktar_belirsiz,
        defaultCurrency: 'TL'
      },
      { label: 'Açıklama', id: 'aciklama', type: 'text', required: true },
      {
        label: 'İleri Tarihte Ödeyeceğim',
        id: 'sonra_odeyecegim',
        type: 'checkbox-with-date',
        dateFieldId: 'odeme_tarihi',
        dateLabel: 'Ödeme Tarihi',
        // İçinde ek checkbox ve dropdown
        hasInnerCheckbox: true,
        innerCheckboxId: 'gelire_bagimli_checkbox',
        innerCheckboxLabel: 'Ödeme Alınca Ödeyeceğim',
        innerSelectFieldId: 'bagimli_oldugu_gelir',
        innerDataEndpoint: 'gelir-alacak',
        innerDataLabelField: 'aciklama'
      },
      // Taksit sadece "İleri Tarihte Ödeyeceğim" işaretliyse göster
      ...(sonraOdeyecegim ? [
        {
          label: 'Taksit ekle',
          id: 'taksit_ekle_checkbox',
          type: 'checkbox-with-installment',
          installmentFieldId: 'taksit',
          amountFieldId: 'miktar'
        }
      ] : []),
      // Ödeme tutarı değişebilir sadece "İleri Tarihte Ödeyeceğim" işaretliyse göster
      ...(sonraOdeyecegim ? [
        {
          label: 'Ödeme tutarı değişebilir',
          id: 'miktar_belirsiz',
          type: 'checkbox',
          checkedLabel: 'Ödeme günü tutar düzenlemesi hatırlatılacak'
        }
      ] : []),
      // Faiz sadece "İleri Tarihte Ödeyeceğim" işaretliyse göster
      ...(sonraOdeyecegim ? [
        { label: 'Faiz Uygulanıyor mu?', id: 'faiz_uygulaniyormu', type: 'checkbox' }
      ] : []),
      // Talimat sadece "İleri Tarihte Ödeyeceğim" işaretliyse göster
      ...(sonraOdeyecegim ? [
        { label: 'Talimat oluşturdum', id: 'talimat_varmi', type: 'checkbox' }
      ] : []),
    ];
  };

  // Harcama-Borç field'larını güncelle
  const updateHarcamaBorcFields = (fieldId, value) => {
    if (currentEndpoint === 'harcama-borc') {
      // İleri Tarihte Ödeyeceğim checkbox değişirse
      if (fieldId === 'sonra_odeyecegim') {
        // Eğer değer zaten aynıysa güncelleme yapma (sonsuz döngüyü önle)
        if (formData.sonra_odeyecegim === value) {
          return;
        }

        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(today.getDate() + 1);
        const tomorrowStr = tomorrow.toISOString().split('T')[0];
        const todayStr = today.toISOString().split('T')[0];

        if (value) {
          // İşaretli: Sonra ödenecek, default yarın
          setFormData(prev => ({
            ...prev,
            odeme_tarihi: tomorrowStr,
            odendi_mi: false,
            taksit: 1 // Default taksit 1
          }));
        } else {
          // İşaretli değil: Bugün ödendi
          setFormData(prev => ({
            ...prev,
            odeme_tarihi: todayStr,
            odendi_mi: true,
            taksit: 1, // Default taksit 1
            talimat_varmi: false, // Talimat checkbox'ını da kapat
            taksit_ekle_checkbox: false, // Taksit checkbox'ını kapat
            faiz_uygulaniyormu: false, // Faiz checkbox'ını da kapat
            gelire_bagimli_checkbox: false // Gelire bağımlı checkbox'ını da kapat
          }));
        }
        // Field'ları yenile - GÜNCEL DEĞER ile (taksit ve talimat field'larını göster/gizle)
        setFormFields(getHarcamaBorcFields(value));
      }

      // Taksit ekle checkbox değişirse sadece formData'yı güncelle (field'lar artık taksitEkle'ye bağlı değil)
      if (fieldId === 'taksit_ekle_checkbox') {
        if (value) {
          // Taksit checkbox işaretlenirse default taksit sayısı 3
          setFormData(prev => ({
            ...prev,
            taksit: 3
          }));
        } else {
          // Taksit checkbox kapatılırsa taksiti 1'e çevir
          setFormData(prev => ({
            ...prev,
            taksit: 1
          }));
        }
      }

      // Miktar belirsiz checkbox değişirse field'ları güncelle (required durumu için)
      if (fieldId === 'miktar_belirsiz') {
        const currentSonraOdeyecegim = formData.sonra_odeyecegim;
        setFormFields(getHarcamaBorcFields(currentSonraOdeyecegim));
        // Miktar field'ının validation'unu da tetikle
        const miktarError = validateField('miktar', formData.miktar, formData, formFields);
        if (miktarError) {
          setErrors(prev => ({ ...prev, miktar: miktarError }));
        } else {
          setErrors(prev => {
            const newErrors = { ...prev };
            delete newErrors.miktar;
            return newErrors;
          });
        }
      }

      // Gelire bağımlı checkbox değişirse field'ları güncelle (dropdown için)
      if (fieldId === 'gelire_bagimli_checkbox') {
        const currentSonraOdeyecegim = formData.sonra_odeyecegim;
        setFormFields(getHarcamaBorcFields(currentSonraOdeyecegim));
      }
    }
  };

  const handleAddGelir = async () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    setCurrentEndpoint('gelir-alacak');
    setFormTitle('Yeni Gelir - Alacak Ekle');
    // FormData ve Errors'ı temizle
    setErrors({});
    // Default değerleri set et
    const today = new Date().toISOString().split('T')[0];
    setFormData({
      sonra_tahsil_edecegim: false, // Default: işaretsiz, bugün tahsil edildi
      tahsilat_tarihi: today,
      alindi_mi: true,
      taksit: 1 // Default taksit sayısı
    });

    // Gider verilerini çek (bağımlı gider seçimi için)
    try {
      const giderResponse = await fetchData('gider');
      if (giderResponse && Array.isArray(giderResponse.data)) {
        setSelectOptionsData(prev => ({ ...prev, gider: giderResponse.data }));
      }
    } catch (error) {
      // Gider verileri çekilemedi
    }

    // İlk başta tüm field'ları göster
    setFormFields(getGelirFields(false)); // sonraTahsilEdecegim=false
    setShowForm(true);
  };

  // Gelir form field'larını döndür
  const getGelirFields = (sonraTahsilEdecegim = formData.sonra_tahsil_edecegim) => {
    return [
      {
        label: 'Miktar',
        id: 'miktar',
        type: 'number-with-currency',
        required: !formData.miktar_belirsiz,
        defaultCurrency: 'TL'
      },
      { label: 'Açıklama', id: 'aciklama', type: 'text', required: true },
      {
        label: 'İleri Tarihte Tahsil Edeceğim',
        id: 'sonra_tahsil_edecegim',
        type: 'checkbox-with-date',
        dateFieldId: 'tahsilat_tarihi',
        dateLabel: 'Tahsilat Tarihi'
      },
      // Taksit sadece "İleri Tarihte Tahsil Edeceğim" işaretliyse göster
      ...(sonraTahsilEdecegim ? [
        {
          label: 'Taksit ekle',
          id: 'taksit_ekle_checkbox',
          type: 'checkbox-with-installment',
          installmentFieldId: 'taksit',
          amountFieldId: 'miktar',
          isIncome: true
        }
      ] : []),
      // Tahsilat tutarı değişebilir sadece "İleri Tarihte Tahsil Edeceğim" işaretliyse göster
      ...(sonraTahsilEdecegim ? [
        {
          label: 'Tahsilat tutarı değişebilir',
          id: 'miktar_belirsiz',
          type: 'checkbox',
          checkedLabel: 'Tahsilat günü tutar düzenlemesi hatırlatılacak'
        }
      ] : []),
      // Faiz sadece "İleri Tarihte Tahsil Edeceğim" işaretliyse göster
      ...(sonraTahsilEdecegim ? [
        { label: 'Faiz Uygulanıyor mu?', id: 'faiz_uygulaniyormu', type: 'checkbox' }
      ] : []),
      // Talimat sadece "İleri Tarihte Tahsil Edeceğim" işaretliyse göster
      ...(sonraTahsilEdecegim ? [
        { label: 'Gönderici talimat oluşturdu', id: 'talimat_varmi', type: 'checkbox' }
      ] : []),
    ];
  };

  // Gelir field'larını güncelle
  const updateGelirFields = (fieldId, value) => {
    if (currentEndpoint === 'gelir-alacak') {
      // İleri Tarihte Tahsil Edeceğim checkbox değişirse
      if (fieldId === 'sonra_tahsil_edecegim') {
        // Eğer değer zaten aynıysa güncelleme yapma (sonsuz döngüyü önle)
        if (formData.sonra_tahsil_edecegim === value) {
          return;
        }

        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(today.getDate() + 1);
        const tomorrowStr = tomorrow.toISOString().split('T')[0];
        const todayStr = today.toISOString().split('T')[0];

        if (value) {
          // İşaretli: Sonra tahsil edilecek, default yarın
          setFormData(prev => ({
            ...prev,
            tahsilat_tarihi: tomorrowStr,
            alindi_mi: false,
            taksit: 1
          }));
        } else {
          // İşaretli değil: Bugün tahsil edildi
          setFormData(prev => ({
            ...prev,
            tahsilat_tarihi: todayStr,
            alindi_mi: true,
            taksit: 1,
            talimat_varmi: false,
            taksit_ekle_checkbox: false,
            faiz_uygulaniyormu: false
          }));
        }
        // Field'ları yenile
        setFormFields(getGelirFields(value));
      }

      // Taksit ekle checkbox değişirse sadece formData'yı güncelle (field'lar artık taksitEkle'ye bağlı değil)
      if (fieldId === 'taksit_ekle_checkbox') {
        if (value) {
          // Taksit checkbox işaretlenirse default taksit sayısı 3
          setFormData(prev => ({
            ...prev,
            taksit: 3
          }));
        } else {
          // Taksit checkbox kapatılırsa taksiti 1'e çevir
          setFormData(prev => ({
            ...prev,
            taksit: 1
          }));
        }
      }

      // Tahsilat tarihi değiştiğinde real-time validation DynamicForm'da yapılıyor

      // Miktar belirsiz checkbox değişirse field'ları güncelle (required durumu için)
      if (fieldId === 'miktar_belirsiz') {
        const currentSonraTahsilEdecegim = formData.sonra_tahsil_edecegim;
        setFormFields(getGelirFields(currentSonraTahsilEdecegim));
        // Miktar field'ının validation'unu da tetikle
        const miktarError = validateField('miktar', formData.miktar, formData, formFields);
        if (miktarError) {
          setErrors(prev => ({ ...prev, miktar: miktarError }));
        } else {
          setErrors(prev => {
            const newErrors = { ...prev };
            delete newErrors.miktar;
            return newErrors;
          });
        }
      }
    }
  };

  const handleAddGider = () => {
    setCurrentEndpoint('gider');
    setFormTitle('Yeni Gider Ekle');
    // FormData ve Errors'ı temizle
    setFormData({});
    setErrors({});
    setFormFields([
      { label: 'Gider', id: 'gider', type: 'text', required: true },
      { label: 'Düzenli mi', id: 'duzenlimi', type: 'checkbox' },
      { label: 'Tutar', id: 'tutar', type: 'number', required: true },
      { label: 'Para Birimi', id: 'para_birimi', type: 'text', required: true },
      { label: 'Kalan Taksit', id: 'kalan_taksit', type: 'number', required: true },
      { label: 'Ödeme Tarihi', id: 'odeme_tarihi', type: 'date', required: true },
      { label: 'Faiz Binecek mi', id: 'faiz_binecekmi', type: 'checkbox' },
      { label: 'Ödendi mi', id: 'odendi_mi', type: 'checkbox' },
      { label: 'Talimat Var mı', id: 'talimat_varmi', type: 'checkbox' },
      { label: 'Bağımlı Olduğu Gelir', id: 'bagimli_oldugu_gelir', type: 'text' },
    ]);
    setFormAnimationKey(prev => prev + 1);
    setShowForm(true);
  };

  const handleAddIstek = () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    setCurrentEndpoint('istek');
    setFormTitle('Yeni İstek Ekle');
    // FormData'yı temizle (önceki formdan kalan değerleri temizle)
    setFormData({
      kategori: 'HARCAMA PLANI', // Default kategori
      oncelik: 'İstek' // Default öncelik
    });
    setErrors({});

    // HARCAMA PLANI için field'ları direkt göster
    updateIstekFields('HARCAMA PLANI');

    // Form animasyonunu tetikle
    setFormAnimationKey(prev => prev + 1);
    setShowForm(true);
  };

  // Kategori değiştiğinde form field'larını güncelle
  const updateIstekFields = (kategori) => {
    const timestamp = Date.now(); // Unique identifier for animation reset
    const baseFields = [
      {
        label: 'Kategori',
        id: 'kategori',
        type: 'select',
        required: true,
        options: [
          { value: 'HARCAMA PLANI', label: 'HARCAMA PLANI' },
          { value: 'EMLAK', label: 'EMLAK' },
          { value: 'VASITA', label: 'VASITA' }
        ],
        _timestamp: timestamp
      }
    ];

    if (kategori === 'HARCAMA PLANI') {
      setFormFields([
        ...baseFields,
        {
          label: 'Öncelik',
          id: 'oncelik',
          type: 'select',
          required: true,
          options: [
            { value: 'İstek', label: 'İstek' },
            { value: 'İhtiyaç', label: 'İhtiyaç' }
          ]
        },
        {
          label: 'Link veya Fiyat',
          id: 'link_or_price',
          type: 'link-or-price',
          required: true,
          defaultCurrency: 'TL'
        },
        { label: 'Açıklama', id: 'aciklama', type: 'text', required: true }
      ]);
      // HARCAMA PLANI için öncelik default "İstek"
      setFormData(prev => ({ ...prev, oncelik: 'İstek' }));
    } else if (kategori === 'EMLAK') {
      setFormFields([
        ...baseFields,
        {
          label: 'Sahibinden Link veya Fiyat',
          id: 'link_or_price',
          type: 'link-or-price',
          required: true,
          defaultCurrency: 'TL'
        },
        { label: 'Açıklama', id: 'aciklama', type: 'text', required: true }
      ]);
      // EMLAK için öncelik otomatik "İstek"
      setFormData(prev => ({ ...prev, oncelik: 'İstek' }));
    } else if (kategori === 'VASITA') {
      setFormFields([
        ...baseFields,
        {
          label: 'Sahibinden Link veya Fiyat',
          id: 'link_or_price',
          type: 'link-or-price',
          required: true,
          defaultCurrency: 'TL'
        },
        { label: 'Açıklama', id: 'aciklama', type: 'text', required: true }
      ]);
      // VASITA için öncelik otomatik "İstek"
      setFormData(prev => ({ ...prev, oncelik: 'İstek' }));
    }
  };

  const handleAddHatirlatma = () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    setCurrentEndpoint('hatirlatma');
    setFormTitle('Yeni Hatırlatma Ekle');
    // FormData ve Errors'ı temizle
    setFormData({});
    setErrors({});
    setFormFields([
      { label: 'Hatırlatılacak Olay', id: 'hatirlatilacak_olay', type: 'text', required: true },
      { label: 'Olay Zamanı', id: 'olay_zamani', type: 'datetime-local', required: true },
    ]);
    setFormAnimationKey(prev => prev + 1);
    setShowForm(true);
  };

  // Tek field için real-time validation
  const validateField = (fieldId, fieldValue, allFormData, fields) => {
    const field = fields.find(f => f.id === fieldId);
    if (!field) return null;

    const value = fieldValue;
    const data = allFormData;

    // Miktar belirsiz ise miktar kontrolünü atla
    if (fieldId === 'miktar' && data.miktar_belirsiz) {
      return null;
    }

    // link-or-price için özel link validation
    if (fieldId === 'link_or_price' && currentEndpoint === 'istek') {
      // Eğer link modundaysa (string ise)
      if (typeof value === 'string' && value.trim() !== '') {
        const linkLower = value.toLowerCase();

        // HARCAMA PLANI kategorisi için
        if (data.kategori === 'HARCAMA PLANI') {
          const allowedSites = ['akakce.com', 'epey.com', 'cimri.com'];
          const isValidSite = allowedSites.some(site => linkLower.includes(site));

          if (!isValidSite) {
            return 'Lütfen sadece Akakçe, Epey veya Cimri sitelerinden link giriniz';
          }
        }

        // EMLAK ve VASITA kategorileri için
        if (data.kategori === 'EMLAK' || data.kategori === 'VASITA') {
          if (!linkLower.includes('sahibinden.com')) {
            return 'Lütfen sadece Sahibinden.com sitesinden link giriniz';
          }
        }
      }
    }

    // Zorunlu alan kontrolü
    if (field.required) {
      if (field.type === 'checkbox' && value !== true && value !== false) {
        return 'Bu alan zorunludur';
      } else if (field.type !== 'checkbox' && (!value || value.toString().trim() === '')) {
        return 'Bu alan zorunludur';
      }
    }

    // Sayısal değer kontrolü
    if (field.type === 'number' && value) {
      if (isNaN(Number(value))) {
        return 'Geçerli bir sayı giriniz';
      }
    }

    // Tarih formatı kontrolü
    if (field.type === 'date' && value) {
      const date = new Date(value);
      if (isNaN(date.getTime())) {
        return 'Geçerli bir tarih giriniz';
      }
    }

    // number-with-currency kontrolü
    if (field.type === 'number-with-currency' && field.required && !data.miktar_belirsiz) {
      const amount = typeof value === 'object' ? value?.amount : value;
      if (!amount || amount.toString().trim() === '') {
        return 'Bu alan zorunludur';
      }
      if (isNaN(parseFloat(amount))) {
        return 'Geçerli bir sayı giriniz';
      }
    }

    // Özel validasyonlar
    // PARA kategorisi için para_birimi_kategori kontrolü kaldırıldı
    // Çünkü updateVarlikFields otomatik olarak TL set ediyor

    if (fieldId === 'sonra_odeyecegim' && data.sonra_odeyecegim === true && (!data.odeme_tarihi || data.odeme_tarihi.trim() === '')) {
      return 'Ödeme tarihi seçmelisiniz';
    }

    if (fieldId === 'tahsilat_tarihi' && data.sonra_tahsil_edecegim === true && value) {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);

      const selectedDate = new Date(value);
      selectedDate.setHours(0, 0, 0, 0);

      if (selectedDate < tomorrow) {
        return 'Tahsilat tarihi yarından önce olamaz';
      }
    }

    if (fieldId === 'odeme_tarihi' && data.sonra_odeyecegim === true && value) {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);

      const selectedDate = new Date(value);
      selectedDate.setHours(0, 0, 0, 0);

      if (selectedDate < tomorrow) {
        return 'Ödeme tarihi yarından önce olamaz';
      }
    }

    return null;
  };

  // Form verilerini doğrulama fonksiyonu (Tüm form için)
  const validateFormData = (data, fields) => {
    const errors = {};

    fields.forEach((field) => {
      const value = data[field.id];

      // Miktar belirsiz ise miktar kontrolünü atla
      if (field.id === 'miktar' && data.miktar_belirsiz) {
        return; // Bu field için validation yapma
      }

      // Zorunlu alan kontrolü
      if (field.required) {
        if (field.type === 'checkbox' && value !== true && value !== false) {
          errors[field.id] = 'Bu alan zorunludur';
        } else if (field.type === 'number-with-currency') {
          // number-with-currency için özel kontrol
          const amount = typeof value === 'object' ? value?.amount : value;
          if (!amount || amount.toString().trim() === '' || isNaN(parseFloat(amount))) {
            errors[field.id] = 'Bu alan zorunludur';
          }
        } else if (field.type !== 'checkbox' && (!value || value.toString().trim() === '')) {
          errors[field.id] = 'Bu alan zorunludur';
        }
      }

      // Sayısal değer kontrolü
      if (field.type === 'number' && value) {
        if (isNaN(Number(value))) {
          errors[field.id] = 'Geçerli bir sayı giriniz';
        }
      }

      // Tarih formatı kontrolü
      if (field.type === 'date' && value) {
        const date = new Date(value);
        if (isNaN(date.getTime())) {
          errors[field.id] = 'Geçerli bir tarih giriniz';
        }
      }
    });

    // PARA kategorisi seçilmişse para_birimi_kategori kontrolü (TL default olarak kabul edilir)
    // Eğer para_birimi_kategori yoksa bile TL kabul edileceği için bu kontrolü atlayalım
    // Çünkü updateVarlikFields otomatik olarak TL set ediyor

    // Sonra ödeyeceğim işaretliyse odeme_tarihi zorunlu
    if (data.sonra_odeyecegim === true && (!data.odeme_tarihi || data.odeme_tarihi.trim() === '')) {
      errors.sonra_odeyecegim = 'Ödeme tarihi seçmelisiniz';
    }

    // Sonra tahsil edeceğim işaretliyse tahsilat_tarihi zorunlu
    if (data.sonra_tahsil_edecegim === true && (!data.tahsilat_tarihi || data.tahsilat_tarihi.trim() === '')) {
      errors.sonra_tahsil_edecegim = 'Tahsilat tarihi seçmelisiniz';
    }

    // Sonra tahsil edeceğim işaretliyse tahsilat_tarihi yarından önce olamaz
    if (data.sonra_tahsil_edecegim === true && data.tahsilat_tarihi) {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);

      const selectedDate = new Date(data.tahsilat_tarihi);
      selectedDate.setHours(0, 0, 0, 0);

      if (selectedDate < tomorrow) {
        errors.tahsilat_tarihi = 'Tahsilat tarihi yarından önce olamaz';
      }
    }

    // Sonra ödeyeceğim işaretliyse odeme_tarihi yarından önce olamaz
    if (data.sonra_odeyecegim === true && data.odeme_tarihi) {
      const tomorrow = new Date();
      tomorrow.setDate(tomorrow.getDate() + 1);
      tomorrow.setHours(0, 0, 0, 0);

      const selectedDate = new Date(data.odeme_tarihi);
      selectedDate.setHours(0, 0, 0, 0);

      if (selectedDate < tomorrow) {
        errors.odeme_tarihi = 'Ödeme tarihi yarından önce olamaz';
      }
    }

    return errors;
  };

  const showAlert = (title, message, onClose, success = false) => {
    setAlertModal({
      visible: true,
      title,
      message,
      onClose: () => {
        // Modalı kapat
        setAlertModal(prev => ({ ...prev, visible: false }));

        // Sadece başarılı durumda form verilerini temizle ve görünümü sıfırla
        if (success) {
          setFormData({});
          setErrors({});
          setCurrentEndpoint('');
          setShowTable(false);
          setShowForm(false);
          setShowDataButtons(false);
          setShowQueryButtons(false);
        }

        // Callback'i çağır
        if (onClose) onClose();
      },
      success
    });
  };

  // ---------------------------------------------------------
  // Formu Gönderme (POST)
  // ---------------------------------------------------------
  const handleSubmitForm = async () => {
    try {
      // PARA kategorisi için para_birimi_kategori'yi düzelt
      let correctedFormData = { ...formData };
      if (correctedFormData.kategori === 'PARA' && !correctedFormData.para_birimi_kategori) {
        correctedFormData.para_birimi_kategori = 'TL';
      }

      // Mevcut real-time errors'ları da kontrol et
      if (Object.keys(errors).length > 0) {
        showAlert('Uyarı', 'Kırmızı işaretli alanları kontrol edin ve gerekli bilgileri eksiksiz girin.', null, false);
        return;
      }

      // Form verilerini kontrol et
      const validationErrors = validateFormData(correctedFormData, formFields);

      if (Object.keys(validationErrors).length > 0) {
        setErrors(validationErrors);
        showAlert('Uyarı', 'Kırmızı işaretli alanları kontrol edin ve gerekli bilgileri eksiksiz girin.', null, false);
        return;
      }

      // Endpoint'i sakla
      const endpoint = currentEndpoint;

      // Form datasını temizle (helper checkbox'ları kaldır ve default değerleri ekle)
      const cleanedData = { ...correctedFormData };

      if (endpoint === 'harcama-borc') {
        // Helper checkbox'ları kaldır (bunlar sadece UI için)
        delete cleanedData.taksit_ekle_checkbox;
        delete cleanedData.gelire_bagimli_checkbox;
        delete cleanedData.sonra_odeyecegim;

        // Miktar object'ini parse et
        if (cleanedData.miktar && typeof cleanedData.miktar === 'object') {
          const miktarObj = cleanedData.miktar;
          cleanedData.miktar = parseFloat(miktarObj.amount) || 0;
          cleanedData.para_birimi = miktarObj.currency || 'TL';
        } else if (cleanedData.miktar) {
          cleanedData.miktar = parseFloat(cleanedData.miktar) || 0;
        }

        // Miktar belirsiz kontrolü: Checkbox işaretli VEYA faiz uygulanıyorsa
        if (cleanedData.miktar_belirsiz || cleanedData.faiz_uygulaniyormu) {
          cleanedData.miktar_belirsiz = 1;
        } else {
          cleanedData.miktar_belirsiz = 0;
        }

        // Sonra ödeyeceğim checkbox'ına göre değerleri ayarla
        if (correctedFormData.sonra_odeyecegim) {
          // İşaretli: sonra ödenecek, kullanıcı tarih seçti
          cleanedData.odendi_mi = false;
        } else {
          // İşaretli değil: bugün ödendi
          const today = new Date().toISOString().split('T')[0];
          cleanedData.odeme_tarihi = today;
          cleanedData.odendi_mi = true;
        }

        // Taksit: Taksit eklenmemişse default 1
        if (!cleanedData.taksit) {
          cleanedData.taksit = 1;
        }

        // Bağımlı gelir: Boşsa null
        if (!cleanedData.bagimli_oldugu_gelir || cleanedData.bagimli_oldugu_gelir.trim() === '') {
          cleanedData.bagimli_oldugu_gelir = null;
        }

        // Açıklama: Boşsa null
        if (!cleanedData.aciklama || cleanedData.aciklama.trim() === '') {
          cleanedData.aciklama = null;
        }
      }

      if (endpoint === 'gelir-alacak') {
        // Helper checkbox'ları kaldır (bunlar sadece UI için)
        delete cleanedData.taksit_ekle_checkbox;
        delete cleanedData.gidere_bagimli_checkbox;
        delete cleanedData.sonra_tahsil_edecegim;

        // Miktar object'ini parse et
        if (cleanedData.miktar && typeof cleanedData.miktar === 'object') {
          const miktarObj = cleanedData.miktar;
          cleanedData.miktar = parseFloat(miktarObj.amount) || 0;
          cleanedData.para_birimi = miktarObj.currency || 'TL';
        } else if (cleanedData.miktar) {
          cleanedData.miktar = parseFloat(cleanedData.miktar) || 0;
        }

        // Miktar belirsiz kontrolü: Checkbox işaretli VEYA faiz uygulanıyorsa
        if (cleanedData.miktar_belirsiz || cleanedData.faiz_uygulaniyormu) {
          cleanedData.miktar_belirsiz = 1;
        } else {
          cleanedData.miktar_belirsiz = 0;
        }

        // Sonra tahsil edeceğim checkbox'ına göre değerleri ayarla
        if (correctedFormData.sonra_tahsil_edecegim) {
          // İşaretli: sonra tahsil edilecek, kullanıcı tarih seçti
          cleanedData.alindi_mi = false;
        } else {
          // İşaretli değil: bugün tahsil edildi
          const today = new Date().toISOString().split('T')[0];
          cleanedData.tahsilat_tarihi = today;
          cleanedData.alindi_mi = true;
        }

        // Taksit: Taksit eklenmemişse default 1
        if (!cleanedData.taksit) {
          cleanedData.taksit = 1;
        }

        // Bağımlı gider: Boşsa null
        if (!cleanedData.bagimli_oldugu_gider || cleanedData.bagimli_oldugu_gider.trim() === '') {
          cleanedData.bagimli_oldugu_gider = null;
        }

        // Açıklama: Boşsa null
        if (!cleanedData.aciklama || cleanedData.aciklama.trim() === '') {
          cleanedData.aciklama = null;
        }
      }

      if (endpoint === 'istek') {
        // link-or-price için özel işlem
        if (cleanedData.link_or_price) {
          const value = cleanedData.link_or_price;

          // Eğer object ise (miktar+para_birimi)
          if (typeof value === 'object' && value.amount !== undefined) {
            cleanedData.miktar = parseFloat(value.amount) || null;
            cleanedData.para_birimi = value.currency || null;
            cleanedData.link = null;
          }
          // Eğer string ise (link)
          else if (typeof value === 'string' && value.trim() !== '') {
            cleanedData.link = value.trim();
            cleanedData.miktar = null;
            cleanedData.para_birimi = null;
          }

          delete cleanedData.link_or_price;
        }

        // Açıklama: Boşsa null
        if (!cleanedData.aciklama || cleanedData.aciklama.trim() === '') {
          cleanedData.aciklama = null;
        }
      }

      if (endpoint === 'varlik') {
        // PARA kategorisi için özel mantık
        if (cleanedData.kategori === 'PARA') {
          // para_birimi_kategori -> varlik
          cleanedData.varlik = cleanedData.para_birimi_kategori || 'TL';
          delete cleanedData.para_birimi_kategori;

          // TL seçildiyse alış fiyatı ve para birimi otomatik ayarla
          if (cleanedData.varlik === 'TL') {
            cleanedData.alis_fiyati = 1;
            cleanedData.alis_para_birimi = 'TL';
          }
        }

        // KRİPTO PARA için
        if (cleanedData.kategori === 'KRİPTO PARA' && cleanedData.varlik_kripto) {
          cleanedData.varlik = cleanedData.varlik_kripto;
          delete cleanedData.varlik_kripto;
        }

        // HİSSE SENEDİ için
        if (cleanedData.kategori === 'HİSSE SENEDİ' && cleanedData.varlik_hisse) {
          cleanedData.varlik = cleanedData.varlik_hisse;
          delete cleanedData.varlik_hisse;
        }

        // BONO-TAHVİL için
        if (cleanedData.kategori === 'BONO-TAHVİL' && cleanedData.varlik_bono) {
          cleanedData.varlik = cleanedData.varlik_bono;
          delete cleanedData.varlik_bono;
        }

        // Alış fiyatı object'ini parse et (TL için zaten ayarlandıysa atla)
        if (cleanedData.kategori !== 'PARA' || cleanedData.varlik !== 'TL') {
          if (cleanedData.alis_fiyati && typeof cleanedData.alis_fiyati === 'object') {
            const fiyatObj = cleanedData.alis_fiyati;
            cleanedData.alis_fiyati = parseFloat(fiyatObj.amount) || 0;
            cleanedData.alis_para_birimi = fiyatObj.currency || 'TL';
          } else if (cleanedData.alis_fiyati) {
            cleanedData.alis_fiyati = parseFloat(cleanedData.alis_fiyati) || 0;
          }
        }
      }

      if (endpoint === 'istek') {
        // EMLAK veya VASITA için otomatik öncelik
        if (cleanedData.kategori === 'EMLAK' || cleanedData.kategori === 'VASITA') {
          cleanedData.oncelik = 'İstek';
        }
      }

      // Veriyi gönder
      const response = await postData(endpoint, cleanedData);

      if (response && response.success) {
        showAlert('Başarılı', 'Veri başarıyla eklendi.', async () => {
          // Eklenen verinin türüne göre ilgili tabloyu göster
          if (endpoint === 'varlik') {
            await handleFetchVarlik();
          } else if (endpoint === 'harcama-borc') {
            await handleFetchBorc();
          } else if (endpoint === 'gelir') {
            await handleFetchGelir();
          } else if (endpoint === 'gider') {
            await handleFetchGider();
          } else if (endpoint === 'istek') {
            await handleFetchIstek();
          } else if (endpoint === 'hatirlatma') {
            await handleFetchHatirlatma();
          }

          // Ana butonları küçült
          setIsMainButtonsSmall(true);
        }, true);
      } else {
        showAlert('Uyarı', response?.message || 'Veri eklenirken bir hata oluştu.', null, false);
      }
    } catch (error) {
      showAlert('Uyarı', 'Veri eklenirken bir hata oluştu. Lütfen tekrar deneyin.', null, false);
    }
  };

  // ---------------------------------------------------------
  // Verileri Sorgulama (GET)
  // ---------------------------------------------------------
  const handleFetchVarlik = async () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    try {
      setShowTable(false);
      setCurrentEndpoint('varlik'); // Endpoint'i set et
      const response = await fetchData('varlik');
      if (response && Array.isArray(response.data)) {
        setTableData(response.data);
        setTableTitle('Varlıklar');
        setTableAnimationKey(prev => prev + 1);
        setShowTable(true);
        setShowForm(false);
      } else {
        throw new Error('Geçersiz veri formatı');
      }
    } catch (error) {
      showAlert('Hata', 'Varlık verileri çekilirken hata oluştu: ' + error.message);
    }
  };

  const handleFetchBorc = async () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    try {
      setShowTable(false);
      setCurrentEndpoint('harcama-borc'); // Endpoint'i set et
      const response = await fetchData('harcama-borc');
      if (response && Array.isArray(response.data)) {
        setTableData(response.data);
        setTableTitle('Harcama - Borç');
        setTableAnimationKey(prev => prev + 1);
        setShowTable(true);
        setShowForm(false);
      } else {
        throw new Error('Geçersiz veri formatı');
      }
    } catch (error) {
      showAlert('Hata', 'Harcama-Borç verileri çekilirken hata oluştu: ' + error.message);
    }
  };

  const handleFetchGelir = async () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    try {
      setShowTable(false);
      setCurrentEndpoint('gelir-alacak'); // Endpoint'i set et
      const response = await fetchData('gelir-alacak');
      if (response && Array.isArray(response.data)) {
        setTableData(response.data);
        setTableTitle('Gelir - Alacak');
        setTableAnimationKey(prev => prev + 1);
        setShowTable(true);
        setShowForm(false);
      } else {
        throw new Error('Geçersiz veri formatı');
      }
    } catch (error) {
      showAlert('Hata', 'Gelir-Alacak verileri çekilirken hata oluştu: ' + error.message);
    }
  };

  const handleFetchGider = async () => {
    try {
      setShowTable(false);
      setCurrentEndpoint('gider'); // Endpoint'i set et
      const response = await fetchData('gider');
      if (response && Array.isArray(response.data)) {
        setTableData(response.data);
        setTableTitle('Giderler');
        setTableAnimationKey(prev => prev + 1);
        setShowTable(true);
        setShowForm(false);
      } else {
        throw new Error('Geçersiz veri formatı');
      }
    } catch (error) {
      showAlert('Hata', 'Gider verileri çekilirken hata oluştu: ' + error.message);
    }
  };

  const handleFetchIstek = async () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    try {
      setShowTable(false);
      setCurrentEndpoint('istek'); // Endpoint'i set et
      const response = await fetchData('istek');
      if (response && Array.isArray(response.data)) {
        setTableData(response.data);
        setTableTitle('İstekler');
        setTableAnimationKey(prev => prev + 1);
        setShowTable(true);
        setShowForm(false);
      } else {
        throw new Error('Geçersiz veri formatı');
      }
    } catch (error) {
      showAlert('Hata', 'İstek verileri çekilirken hata oluştu: ' + error.message);
    }
  };

  const handleFetchHatirlatma = async () => {
    if (isYetkiModalVisible) setYetkiModalVisible(false);
    try {
      setShowTable(false);
      setCurrentEndpoint('hatirlatma'); // Endpoint'i set et
      const response = await fetchData('hatirlatma');
      if (response && Array.isArray(response.data)) {
        setTableData(response.data);
        setTableTitle('Hatırlatmalar');
        setTableAnimationKey(prev => prev + 1);
        setShowTable(true);
        setShowForm(false);
      } else {
        throw new Error('Geçersiz veri formatı');
      }
    } catch (error) {
      showAlert('Hata', 'Hatırlatma verileri çekilirken hata oluştu: ' + error.message);
    }
  };

  const handleActionClick = (action) => {
    // Eğer YetkiModal açıksa, önce kapat
    if (isYetkiModalVisible) {
      setYetkiModalVisible(false);
    }

    if (user) {
      // Kullanıcı giriş yapmışsa direkt işlemi başlat
      if (action === 'ekle') {
        handleAddData();
      } else if (action === 'sorgula') {
        handleQueryData();
      }
    } else {
      // Kullanıcı giriş yapmamışsa modal'ı göster
      setCurrentAction(action);
      setLoginModalVisible(true);
    }
  };

  const handleModalClose = () => {
    setLoginModalVisible(false);
    setCurrentAction('');
    resetAllStates(); // Ana ekrana dönmek için tüm state'leri sıfırla
  };

  // Hesap değişince açık UI'yi sıfırla
  useEffect(() => {
    resetAllStates();
  }, [activeAccount]);

  const resetAllStates = () => {
    setIsMainButtonsSmall(false);  // Ana butonları büyük göster
    setShowDataButtons(false);
    setShowQueryButtons(false);
    setShowForm(false);
    setShowTable(false);
    setCurrentEndpoint('');
    setFormFields([]);
    setFormData({});
    setErrors({});
    setTableTitle('');
    setTableData([]);
    setCurrentAction('');  // Mevcut aksiyonu sıfırla
    setLoginModalVisible(false);  // Login modalını kapat
  };

  const handleModalSuccess = () => {
    // Kullanıcı girişi başarılı olduğunda yapılacak işlemler
    if (currentAction === 'ekle') {
      handleAddData();
    } else if (currentAction === 'sorgula') {
      handleQueryData();
    }
    setLoginModalVisible(false);
    setCurrentAction('');
  };

  const handleLogoClick = () => {
    // Eğer herhangi bir şey açıksa (sub-butonlar, form, tablo), önce kapat
    if (showDataButtons || showQueryButtons || showForm || showTable) {
      setIsResetting(true);
      setIsClosingSubButtons(true);

      setTimeout(() => {
        // Tüm state'leri sıfırla
        setShowDataButtons(false);
        setShowQueryButtons(false);
        setShowForm(false);
        setShowTable(false);
        setCurrentEndpoint('');
        setFormFields([]);
        setFormData({});
        setErrors({});
        setTableTitle('');
        setTableData([]);
        setCurrentAction('');
        setLoginModalVisible(false);
        setIsClosingSubButtons(false);

        // Ana butonları büyütme animasyonuyla getir
        setTimeout(() => {
          // Butonları büyüt (CSS transition otomatik çalışır - key değiştirme!)
          setIsMainButtonsSmall(false);
          setIsResetting(false);
        }, 50);
      }, 350); // Kapanma animasyonu süresi
    } else {
      // Hiçbir şey açık değilse, nokta halinden başlat
      setIsMainButtonsSmall(false);
      setMainButtonsAnimationKey(prev => prev + 1);
    }

    // Yetki modalı açıksa kapat
    setYetkiModalVisible(false);

    // Sayfayı en üste kaydır
    window.scrollTo(0, 0);
  };

  return (
    <View style={{ flex: 1 }}>
      <FluidSimulation />
      {/* Header Container - Logo left, UserInfo right */}
      <View style={{
        position: 'absolute',
        top: 0,
        left: 0,
        right: 0,
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'flex-start',
        paddingTop: '8px',
        paddingLeft: '8px',
        paddingRight: '8px',
        zIndex: 10002,
      }}>
        <Logo onReset={handleLogoClick} isModalOpen={isYetkiModalVisible} onCloseModal={() => setYetkiModalVisible(false)} />
        <UserInfo onLogout={resetAllStates} onOpenYetkiModal={() => setYetkiModalVisible(true)} isModalOpen={isYetkiModalVisible} onCloseModal={() => setYetkiModalVisible(false)} />
      </View>
      <YetkiModal
        visible={isYetkiModalVisible}
        onClose={() => setYetkiModalVisible(false)}
      />
      <SafeAreaView style={[styles.container, { pointerEvents: 'box-none' }]}>
      <ScrollView
        contentContainerStyle={[
          styles.scrollViewContent,
          {
            paddingLeft: '5%',
            paddingRight: '5%',
            paddingTop: '5%',
            paddingBottom: '5%'
          }
        ]}
        showsVerticalScrollIndicator={true}
        showsHorizontalScrollIndicator={true}
      >
        <Header onReset={handleLogoClick} />

        {/* Ana Butonlar */}
        <div
          key={`main-buttons-${mainButtonsAnimationKey}`}
          className={(!isMainButtonsSmall && !isResetting) ? "main-buttons-enter" : ""}
        >
          <View style={[
            styles.mainButtonsContainer,
            isMainButtonsSmall && styles.mainButtonsContainerSmall
          ]}>
            <MainButton
              title="Ekle"
              onPress={() => handleActionClick('ekle')}
              style={[
                styles.mainButton,
                isMainButtonsSmall && styles.mainButtonSmall
              ]}
              textStyle={[
                styles.mainButtonText,
                isMainButtonsSmall && styles.mainButtonTextSmall
              ]}
            />
            <MainButton
              title="Sorgula"
              onPress={() => handleActionClick('sorgula')}
              style={[
                styles.mainButton,
                isMainButtonsSmall && styles.mainButtonSmall
              ]}
              textStyle={[
                styles.mainButtonText,
                isMainButtonsSmall && styles.mainButtonTextSmall
              ]}
            />
          </View>
        </div>

        {/* Alt Menüler */}
        {showDataButtons && !showForm && (
          <div
            key={`add-buttons-${subButtonsAnimationKey}`}
            className={isClosingSubButtons ? "sub-buttons-exit-left" : "sub-buttons-enter-left"}
          >
            <View style={styles.glassCard} onClick={() => { if (isYetkiModalVisible) setYetkiModalVisible(false); }}>
              <Text style={styles.cardTitle}>Ne eklemek istersiniz?</Text>
              <View style={styles.flexRowWrap}>
                <SubButton title="Varlık" onPress={handleAddVarlik} />
                <SubButton title="Gelir - Alacak" onPress={handleAddGelir} />
                <SubButton title="Harcama - Borç" onPress={handleAddBorc} />
                <SubButton title="İstek" onPress={handleAddIstek} />
                <SubButton title="Hatırlatma" onPress={handleAddHatirlatma} />
              </View>
            </View>
          </div>
        )}

        {/* Sorgulama Butonları */}
        {showQueryButtons && !showTable && (
          <div
            key={`query-buttons-${subButtonsAnimationKey}`}
            className={isClosingSubButtons ? "sub-buttons-exit-right" : "sub-buttons-enter-right"}
          >
            <View style={styles.glassCard} onClick={() => { if (isYetkiModalVisible) setYetkiModalVisible(false); }}>
              <Text style={styles.cardTitle}>Hangisini sorgulayacaksınız?</Text>
              <View style={styles.flexRowWrap}>
                <SubButton title="Varlık" onPress={handleFetchVarlik} />
                <SubButton title="Gelir - Alacak" onPress={handleFetchGelir} />
                <SubButton title="Harcama - Borç" onPress={handleFetchBorc} />
                <SubButton title="İstek" onPress={handleFetchIstek} />
                <SubButton title="Hatırlatma" onPress={handleFetchHatirlatma} />
              </View>
            </View>
          </div>
        )}

        {/* Form */}
        {showForm && (
          <div
            key={`form-${formAnimationKey}`}
            className={isResetting ? "sub-buttons-exit-left" : "container-enter"}
          >
            <View style={styles.glassCard}>
              <Text style={styles.cardTitle}>{formTitle}</Text>
              <DynamicForm
                formFields={formFields}
                formData={formData}
                setFormData={setFormData}
                errors={errors}
                setErrors={setErrors}
                onSubmit={handleSubmitForm}
                validateField={validateField}
                selectOptionsData={selectOptionsData}
                onFieldChange={(fieldId, value) => {
                  // Varlık formu için kategori veya para_birimi_kategori değişikliğini kontrol et
                  if (currentEndpoint === 'varlik' && (fieldId === 'kategori' || fieldId === 'para_birimi_kategori')) {
                    updateVarlikFields(fieldId, value);
                  }
                  // İstek formu için kategori değişikliğini kontrol et
                  if (currentEndpoint === 'istek' && fieldId === 'kategori') {
                    updateIstekFields(value);
                    // Form animasyonunu tetikle (kategori değiştiğinde)
                    setFormAnimationKey(prev => prev + 1);
                  }
                  // Harcama-Borç formu için checkbox değişikliklerini kontrol et
                  if (currentEndpoint === 'harcama-borc' &&
                    (fieldId === 'taksit_ekle_checkbox' ||
                      fieldId === 'gelire_bagimli_checkbox' ||
                      fieldId === 'sonra_odeyecegim' ||
                      fieldId === 'miktar_belirsiz')) {
                    updateHarcamaBorcFields(fieldId, value);
                  }
                  // Gelir formu için checkbox ve tarih değişikliklerini kontrol et
                  if (currentEndpoint === 'gelir-alacak' &&
                    (fieldId === 'taksit_ekle_checkbox' ||
                      fieldId === 'sonra_tahsil_edecegim' ||
                      fieldId === 'miktar_belirsiz' ||
                      fieldId === 'tahsilat_tarihi')) {
                    updateGelirFields(fieldId, value);
                  }
                }}
                submitButtonStyle={styles.formSubmitButton}
                submitButtonTextStyle={styles.formSubmitButtonText}
              />
            </View>
          </div>
        )}

        {/* Tablo */}
        {showTable && (
          <div
            key={`table-${tableAnimationKey}`}
            className={isResetting ? "sub-buttons-exit-right" : "container-enter"}
          >
            <View style={[styles.glassCard, {
              maxWidth: '98%',
              width: 'fit-content',
              paddingLeft: 0,
              paddingRight: 0,
              paddingTop: 0,
              paddingBottom: 0,
              overflow: 'visible'
            }]}>
              <DataTable
                data={tableData}
                title={tableTitle}
                endpoint={currentEndpoint}
                onUpdate={() => {
                  // Veriyi yeniden yükle
                  if (currentEndpoint === 'varlik') {
                    handleFetchVarlik();
                  } else if (currentEndpoint === 'harcama-borc') {
                    handleFetchBorc();
                  } else if (currentEndpoint === 'gelir-alacak') {
                    handleFetchGelir();
                  } else if (currentEndpoint === 'gider') {
                    handleFetchGider();
                  } else if (currentEndpoint === 'istek') {
                    handleFetchIstek();
                  } else if (currentEndpoint === 'hatirlatma') {
                    handleFetchHatirlatma();
                  }
                }}
              />
            </View>
          </div>
        )}
      </ScrollView>

      <AlertModal
        visible={alertModal.visible}
        title={alertModal.title}
        message={alertModal.message}
        onClose={alertModal.onClose}
        success={alertModal.title === 'Başarılı'}
      />

      <LoginModal
        visible={isLoginModalVisible}
        onClose={handleModalClose}
        onSuccess={handleModalSuccess}
      />

      {showAdminPanel && (
        <AdminDashboard onClose={() => setShowAdminPanel(false)} />
      )}
    </SafeAreaView>
    </View>
  );
};

export default function App() {
  return (
    <UserProvider>
      <AppContent />
    </UserProvider>
  );
}
