// front/components/Forms/DynamicForm.js
import React, { useState, useEffect, useRef } from 'react';
import { View, TouchableOpacity, Text, ScrollView } from 'react-native';
import FormField from './FormField';
import styles from '../../styles/styles';

const DynamicForm = ({ 
  formFields, 
  formData, 
  setFormData, 
  errors, 
  setErrors, 
  onSubmit,
  onFieldChange,
  validateField,
  submitButtonStyle,
  submitButtonTextStyle,
  selectOptionsData
}) => {
  const [isSubmitHovered, setIsSubmitHovered] = useState(false);
  const [isSubmitPressed, setIsSubmitPressed] = useState(false);
  const [animationKey, setAnimationKey] = useState(0);
  const previousFieldCountRef = useRef(formFields.length);
  
  // FormFields değiştiğinde animasyonu yeniden tetikle - SADECE kategori değişikliğinde
  useEffect(() => {
    // Kategori field'ının _timestamp'i değişti mi kontrol et
    const firstField = formFields[0];
    const hasTimestamp = firstField && firstField._timestamp;
    
    // Timestamp varsa kategori değişmiş demektir, animasyon tetikle
    if (hasTimestamp) {
      setAnimationKey(prev => prev + 1);
    }
    
    // Field sayısı değişmişse de animasyon tetikle (form değişti demektir)
    const currentFieldCount = formFields.length;
    if (currentFieldCount !== previousFieldCountRef.current) {
      previousFieldCountRef.current = currentFieldCount;
    }
  }, [formFields]);
  const handleChange = (id, value) => {
    const newFormData = { 
      ...formData, 
      [id]: value
    };
    setFormData(newFormData);

    // Real-time validation - field değiştiğinde
    if (validateField) {
      const fieldError = validateField(id, value, newFormData, formFields);
      if (fieldError) {
        setErrors({ ...errors, [id]: fieldError });
      } else {
        const newErrors = { ...errors };
        delete newErrors[id];
        setErrors(newErrors);
      }
    } else if (errors[id]) {
      setErrors({ ...errors, [id]: null });
    }

    // Kategori değişikliğini parent component'e bildir
    if (onFieldChange) {
      onFieldChange(id, value);
    }
  };

  const handleSubmit = () => {
    // Form verilerini hazırla
    const preparedData = {};

    // Tüm form alanlarını kontrol et ve varsayılan değerleri ekle
    formFields.forEach(field => {
      // Eğer değer girilmişse onu kullan, girilmemişse varsayılan değer ata
      if (field.type === 'checkbox') {
        // Checkbox değerlerini 1/0 olarak gönder
        preparedData[field.id] = formData[field.id] ? 1 : 0;
      } else if (field.type === 'checkbox-with-installment') {
        // Checkbox-with-installment değerlerini 1/0 olarak gönder
        preparedData[field.id] = formData[field.id] ? 1 : 0;
        
        // Taksit sayısını ekle
        if (formData[field.id] && field.installmentFieldId) {
          const installmentValue = formData[field.installmentFieldId];
          const customInstallmentValue = formData[`${field.installmentFieldId}_custom`];
          
          if (installmentValue === 'custom' && customInstallmentValue) {
            preparedData[field.installmentFieldId] = parseInt(customInstallmentValue);
          } else if (installmentValue !== 'custom') {
            preparedData[field.installmentFieldId] = parseInt(installmentValue) || 3;
          } else {
            preparedData[field.installmentFieldId] = 3;
          }
        }
      } else if (field.type === 'checkbox-with-select') {
        // Checkbox-with-select değerlerini 1/0 olarak gönder
        preparedData[field.id] = formData[field.id] ? 1 : 0;
        
        // Seçilen değeri ekle
        if (formData[field.id] && field.selectFieldId) {
          preparedData[field.selectFieldId] = formData[field.selectFieldId] || '';
        }
      } else if (field.type === 'checkbox-with-date') {
        // Checkbox-with-date değerlerini 1/0 olarak gönder
        preparedData[field.id] = formData[field.id] ? 1 : 0;
        
        // Tarih değerini ekle
        if (field.dateFieldId) {
          preparedData[field.dateFieldId] = formData[field.dateFieldId] || new Date().toISOString();
        }
      } else if (field.type === 'number') {
        preparedData[field.id] = formData[field.id] ? parseFloat(formData[field.id]) : 0;
      } else if (field.type === 'number-with-currency') {
        // Miktar ve para birimi için composite değerleri ayır
        const value = formData[field.id] || {};
        
        // Amount değerini çıkar - object veya string olabilir
        let amount = 0;
        if (typeof value === 'object' && value.amount !== undefined) {
          amount = value.amount;
        } else if (typeof value === 'string' || typeof value === 'number') {
          amount = value;
        }
        
        // String ise temizle ve parse et
        if (typeof amount === 'string') {
          amount = amount.replace(/[^0-9.-]/g, ''); // Sadece sayı, nokta ve eksi işareti
        }
        
        const parsedAmount = parseFloat(amount);
        const finalAmount = isNaN(parsedAmount) ? 0 : parsedAmount;
        
        const currency = (typeof value === 'object' ? value.currency : null) || field.defaultCurrency || 'TL';
        
        // Field id'yi kullanarak doğru field'a kaydet
        if (field.id === 'tutar' || field.id === 'alis_fiyati' || field.id === 'miktar') {
          preparedData[field.id] = finalAmount;
          preparedData['para_birimi'] = currency;
        }
      } else if (field.type === 'date') {
        preparedData[field.id] = formData[field.id] || new Date().toISOString();
      } else if (field.type === 'datetime-local') {
        preparedData[field.id] = formData[field.id] || new Date().toISOString();
      } else if (field.type === 'select') {
        // Select alanları için değeri olduğu gibi al
        preparedData[field.id] = formData[field.id] || '';
        
        // Kategori PARA ise ve para_birimi_kategori seçiliyse, kategoriyi para birimiyle değiştir
        if (field.id === 'kategori' && formData[field.id] === 'PARA' && formData.para_birimi_kategori) {
          preparedData.kategori = formData.para_birimi_kategori;
        }
      } else {
        // Text alanları için boş string varsayılan değer
        preparedData[field.id] = (formData[field.id] || '').toString().trim();
      }
    });

    // Parent'da (front.js) validation yapılacak, burada direkt gönder
    onSubmit(preparedData);
  };

  const renderFormField = (field, index) => {
    const { id } = field;
    const value = formData[id];
    const hasError = errors[id];

    // checkbox-with-select için uygun data'yı bul
    let fieldSelectOptions = [];
    if (field.type === 'checkbox-with-select' && selectOptionsData) {
      if (field.dataEndpoint === 'gelir') {
        fieldSelectOptions = selectOptionsData.gelir || [];
      } else if (field.dataEndpoint === 'gider') {
        fieldSelectOptions = selectOptionsData.gider || [];
      }
    }
    
    // checkbox-with-date içinde innerDataEndpoint varsa uygun data'yı bul
    if (field.type === 'checkbox-with-date' && field.hasInnerCheckbox && selectOptionsData) {
      if (field.innerDataEndpoint === 'gelir-alacak') {
        fieldSelectOptions = selectOptionsData.gelir || [];
      } else if (field.innerDataEndpoint === 'gider') {
        fieldSelectOptions = selectOptionsData.gider || [];
      }
    }

    // Animasyon sınıfı belirle (ilk 6 field için delay)
    const animationClass = index === 0 ? 'form-field-enter' : `form-field-enter-delay-${Math.min(index, 5)}`;
    
    // Unique key: field id + animation key (kategori değiştiğinde yenilenir)
    const uniqueKey = `${id}-${animationKey}`;

    return (
      <div key={uniqueKey} className={animationClass}>
        <View style={styles.formGroup}>
          <FormField
            field={field}
            value={value}
            onChange={(val) => handleChange(id, val)}
            hasError={hasError}
            formData={formData}
            setFormData={setFormData}
            selectOptions={fieldSelectOptions}
            errors={errors}
            onFieldChange={(fId, fVal) => handleChange(fId, fVal)}
          />
        </View>
      </div>
    );
  };

  return (
    <ScrollView>
      <View style={styles.formContainer}>
        {formFields.map((field, index) => renderFormField(field, index))}
      </View>
      <TouchableOpacity
        style={[
          submitButtonStyle,
          isSubmitPressed ? {
            transform: [{ translateY: -2 }, { scale: 0.98 }],
            boxShadow: '0 6px 18px rgba(0,0,0,0.4), inset 0 4px 10px rgba(21,87,36,0.6)',
            backgroundColor: '#1e7e34',
            border: 'clamp(2px, 0.3vw, 3px) solid #155724',
            borderRadius: 'clamp(10px, 2.5vw, 25px)',
            overflow: 'hidden',
          } : isSubmitHovered ? {
            transform: [{ translateY: -5 }, { scale: 1.08 }],
            boxShadow: `0 20px 45px rgba(40,167,69,0.4), 
                        0 10px 22px rgba(0,0,0,0.3), 
                        0 0 35px rgba(40,167,69,0.2),
                        inset 0 2px 8px rgba(30,126,52,0.3)`,
            backgroundColor: '#28a745',
            border: 'clamp(2px, 0.3vw, 3px) solid #1e7e34',
            borderRadius: 'clamp(10px, 2.5vw, 25px)',
            overflow: 'hidden',
          } : {}
        ]}
        onPress={handleSubmit}
        onPressIn={() => setIsSubmitPressed(true)}
        onPressOut={() => setIsSubmitPressed(false)}
        onMouseEnter={() => setIsSubmitHovered(true)}
        onMouseLeave={() => setIsSubmitHovered(false)}
        activeOpacity={0.8}
      >
        <Text style={submitButtonTextStyle}>Ekle</Text>
      </TouchableOpacity>
    </ScrollView>
  );
};

export default DynamicForm;
