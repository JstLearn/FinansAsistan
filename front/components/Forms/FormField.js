// front/components/Forms/FormField.js
import React, { useState, useEffect, useRef } from 'react';
import { View, Text, TextInput, TouchableOpacity } from 'react-native';
import { createPortal } from 'react-dom';
import styles, { GLOBAL_FONT_FAMILY } from '../../styles/styles';

// Helper: Dropdown genişliğini metinlere göre hesapla
const calculateDynamicDropdownWidth = (options, minWidth = 150, extraPadding = 45) => {
  let maxLength = 0;
  options.forEach(opt => {
    const label = typeof opt === 'string' ? opt : (opt.label || opt.value || '');
    let charWidth = 0;
    
    for (let i = 0; i < label.length; i++) {
      const char = label[i];
      if (/[A-ZÇĞİÖŞÜ]/.test(char)) charWidth += 12;
      else if (/[a-zçğıöşü]/.test(char)) charWidth += 9;
      else if (/[0-9]/.test(char)) charWidth += 10;
      else if (char === ' ') charWidth += 6;
      else charWidth += 8;
    }
    
    if (charWidth > maxLength) maxLength = charWidth;
  });
  
  return Math.max(maxLength + extraPadding, minWidth);
};

const FormField = ({ field, value, onChange, hasError, formData, setFormData, selectOptions, errors, onFieldChange }) => {
  const { label, type, required } = field;
  const [isFocused, setIsFocused] = useState(false);
  const [isCheckboxHovered, setIsCheckboxHovered] = useState(false);
  const [isCheckboxPressed, setIsCheckboxPressed] = useState(false);
  const customInstallmentInputRef = useRef(null);
  const [showCustomDropdown, setShowCustomDropdown] = useState(false);
  const [dropdownPosition, setDropdownPosition] = useState({ top: 0, left: 0 });
  const customDropdownButtonRef = useRef(null);
  const [hoveredOption, setHoveredOption] = useState(null);
  const [showParaBirimiDropdown, setShowParaBirimiDropdown] = useState(false);
  const [paraBirimiDropdownPosition, setParaBirimiDropdownPosition] = useState({ top: 0, left: 0 });
  const paraBirimiDropdownButtonRef = useRef(null);
  const [customParaBirimi, setCustomParaBirimi] = useState('');
  const customParaBirimiInputRef = useRef(null);
  
  // select-with-custom dropdown states (KRİPTO PARA, HİSSE, BONO için)
  const [showSelectWithCustomDropdown, setShowSelectWithCustomDropdown] = useState(false);
  const [selectWithCustomDropdownPosition, setSelectWithCustomDropdownPosition] = useState({ top: 0, left: 0 });
  const selectWithCustomDropdownButtonRef = useRef(null);
  const [customVarlik, setCustomVarlik] = useState('');
  const customVarlikInputRef = useRef(null);
  
  // checkbox-with-select custom dropdown states
  const [showCheckboxSelectDropdown, setShowCheckboxSelectDropdown] = useState(false);
  const [checkboxSelectDropdownPosition, setCheckboxSelectDropdownPosition] = useState({ top: 0, left: 0 });
  const checkboxSelectDropdownButtonRef = useRef(null);
  
  // checkbox-with-installment custom dropdown states
  const [showInstallmentDropdown, setShowInstallmentDropdown] = useState(false);
  const [installmentDropdownPosition, setInstallmentDropdownPosition] = useState({ top: 0, left: 0 });
  const installmentDropdownButtonRef = useRef(null);
  
  // number-with-currency custom dropdown states
  const [showCurrencyDropdown, setShowCurrencyDropdown] = useState(false);
  const [currencyDropdownPosition, setCurrencyDropdownPosition] = useState({ top: 0, left: 0 });
  const currencyDropdownButtonRef = useRef(null);
  
  // Özel taksit seçildiğinde otomatik focus
  useEffect(() => {
    if (type === 'checkbox-with-installment') {
      const installmentCount = formData?.[field.installmentFieldId];
      if (installmentCount === 'custom' && customInstallmentInputRef.current) {
        setTimeout(() => {
          customInstallmentInputRef.current?.focus();
          customInstallmentInputRef.current?.select();
        }, 100);
      }
    }
  }, [formData?.[field.installmentFieldId], type, field.installmentFieldId]);
  
  // Custom dropdown için click outside listener
  useEffect(() => {
    if (!showCustomDropdown && !showParaBirimiDropdown && !showSelectWithCustomDropdown && !showCheckboxSelectDropdown && !showInstallmentDropdown && !showCurrencyDropdown) return;
    
    const handleClickOutside = (e) => {
      if (showCustomDropdown && customDropdownButtonRef.current && !customDropdownButtonRef.current.contains(e.target)) {
        const isDropdownClick = e.target.closest('[data-custom-dropdown="true"]');
        if (!isDropdownClick) {
          setShowCustomDropdown(false);
        }
      }
      
      if (showParaBirimiDropdown && paraBirimiDropdownButtonRef.current && !paraBirimiDropdownButtonRef.current.contains(e.target)) {
        const isParaBirimiClick = e.target.closest('[data-para-birimi-dropdown="true"]');
        if (!isParaBirimiClick) {
          setShowParaBirimiDropdown(false);
        }
      }
      
      if (showSelectWithCustomDropdown && selectWithCustomDropdownButtonRef.current && !selectWithCustomDropdownButtonRef.current.contains(e.target)) {
        const isSelectWithCustomClick = e.target.closest('[data-select-with-custom-dropdown="true"]');
        if (!isSelectWithCustomClick) {
          setShowSelectWithCustomDropdown(false);
        }
      }
      
      if (showCheckboxSelectDropdown && checkboxSelectDropdownButtonRef.current && !checkboxSelectDropdownButtonRef.current.contains(e.target)) {
        const isCheckboxSelectClick = e.target.closest('[data-checkbox-select-dropdown="true"]');
        if (!isCheckboxSelectClick) {
          setShowCheckboxSelectDropdown(false);
        }
      }
      
      if (showInstallmentDropdown && installmentDropdownButtonRef.current && !installmentDropdownButtonRef.current.contains(e.target)) {
        const isInstallmentClick = e.target.closest('[data-installment-dropdown="true"]');
        if (!isInstallmentClick) {
          setShowInstallmentDropdown(false);
        }
      }
      
      if (showCurrencyDropdown && currencyDropdownButtonRef.current && !currencyDropdownButtonRef.current.contains(e.target)) {
        const isCurrencyClick = e.target.closest('[data-currency-dropdown="true"]');
        if (!isCurrencyClick) {
          setShowCurrencyDropdown(false);
        }
      }
    };
    
    const handleScroll = () => {
      if (showCustomDropdown && customDropdownButtonRef.current) {
        const rect = customDropdownButtonRef.current.getBoundingClientRect();
        setDropdownPosition({
          top: rect.bottom + 4,
          left: rect.left,
          width: rect.width
        });
      }
      
      if (showParaBirimiDropdown && paraBirimiDropdownButtonRef.current) {
        const rect = paraBirimiDropdownButtonRef.current.getBoundingClientRect();
        setParaBirimiDropdownPosition({
          top: rect.bottom + 4,
          left: rect.left,
          width: 90
        });
      }
      
      if (showSelectWithCustomDropdown && selectWithCustomDropdownButtonRef.current) {
        const rect = selectWithCustomDropdownButtonRef.current.getBoundingClientRect();
        setSelectWithCustomDropdownPosition({
          top: rect.bottom + 4,
          left: rect.left
        });
      }
      
      if (showCheckboxSelectDropdown && checkboxSelectDropdownButtonRef.current) {
        const rect = checkboxSelectDropdownButtonRef.current.getBoundingClientRect();
        setCheckboxSelectDropdownPosition({
          top: rect.bottom + 4,
          left: rect.left
        });
      }
      
      if (showInstallmentDropdown && installmentDropdownButtonRef.current) {
        const rect = installmentDropdownButtonRef.current.getBoundingClientRect();
        setInstallmentDropdownPosition({
          top: rect.bottom + 4,
          left: rect.left
        });
      }
      
      if (showCurrencyDropdown && currencyDropdownButtonRef.current) {
        const rect = currencyDropdownButtonRef.current.getBoundingClientRect();
        setCurrencyDropdownPosition({
          top: rect.bottom + 4,
          left: rect.left
        });
      }
    };
    
    setTimeout(() => {
      document.addEventListener('mousedown', handleClickOutside);
    }, 100);
    document.addEventListener('scroll', handleScroll, true);
    
    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('scroll', handleScroll, true);
    };
  }, [showCustomDropdown, showParaBirimiDropdown, showSelectWithCustomDropdown, showCheckboxSelectDropdown, showInstallmentDropdown, showCurrencyDropdown]);
  
  // Label yukarıda mı olmalı? (Focus veya value varsa)
  // number-with-currency için özel kontrol
  const getActualValue = () => {
    if (type === 'number-with-currency') {
      return typeof value === 'object' ? (value?.amount || '') : (value || '');
    }
    return value;
  };
  
  const actualValue = getActualValue();
  // number-with-currency için label her zaman yukarıda (placeholder olduğu için)
  const isFloating = type === 'number-with-currency' || isFocused || (actualValue && actualValue.toString().trim() !== '');
  
  // Input'un rengi: zorunlu ve boşsa kırmızı, doluysa veya zorunlu değilse yeşil
  // Sadece gerçekten elle girilmiş değer varsa yeşil olmalı
  const hasValue = actualValue && actualValue.toString().trim() !== '';
  const isRequired = required && !hasValue;
  const glowColor = isRequired ? 'red' : 'green';

  const formatDate = (date) => {
    const d = new Date(date);
    return d.toISOString().split('T')[0];
  };

  const formatDateTime = (date) => {
    const d = new Date(date);
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const hours = String(d.getHours()).padStart(2, '0');
    const minutes = String(d.getMinutes()).padStart(2, '0');
    return `${year}-${month}-${day}T${hours}:${minutes}`;
  };

  useEffect(() => {
    if (type === 'date' && !value) {
      onChange(formatDate(new Date()));
    }
    if (type === 'datetime-local' && !value) {
      onChange(formatDateTime(new Date()));
    }
  }, []);

  const handleDateChange = (event) => {
    const selectedDate = event.target.value;
    if (selectedDate) {
      onChange(selectedDate);
    }
  };

  const renderInput = () => {
    switch (type) {
      case 'checkbox-with-installment':
        // Taksit checkbox'ı + Taksit sayısı dropdown + Taksit tutarı gösterimi
        const installmentCount = formData?.[field.installmentFieldId] || 3;
        const customInstallmentCount = formData?.[`${field.installmentFieldId}_custom`] || '';
        const isCustomInstallment = installmentCount === 'custom';
        const finalInstallmentCount = isCustomInstallment && customInstallmentCount 
          ? parseInt(customInstallmentCount) 
          : (isCustomInstallment ? 3 : installmentCount);
        
        const amountData = formData?.[field.amountFieldId] || {};
        const totalAmount = typeof amountData === 'object' ? parseFloat(amountData.amount) : parseFloat(amountData) || 0;
        const currency = typeof amountData === 'object' ? (amountData.currency || 'TL') : 'TL';
        
        // Gelir için çarpma, Harcama-Borç için bölme
        const installmentAmount = value && totalAmount > 0 
          ? (field.isIncome 
              ? (totalAmount * finalInstallmentCount).toFixed(2)  // Gelir: çarpma
              : (totalAmount / finalInstallmentCount).toFixed(2)) // Harcama-Borç: bölme
          : 0;
        
        const isInstallmentCheckboxRequired = required && !value;
        const installmentCheckboxGlowColor = isInstallmentCheckboxRequired ? 'rgba(220, 53, 69, 0.3)' : 'rgba(40, 167, 69, 0.3)';
        const installmentCheckboxBoxShadow = isInstallmentCheckboxRequired 
          ? 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)'
          : 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)';
        
        const installmentDynamicStyle = isCheckboxPressed ? {
          transform: [{ translateY: 0 }, { scale: 0.98 }],
          filter: 'brightness(1.25)',
        } : isCheckboxHovered ? {
          transform: [{ translateY: -2 }],
          filter: 'brightness(1.1)',
        } : {};
        
        return (
          <View style={{ position: 'relative', width: '100%' }}>
            {/* Floating Label */}
            {value && (
              <Text style={{
                ...styles.formLabelFloating,
                color: 'rgba(0, 123, 255, 0.8)',
                fontSize: 'clamp(9px, 1.8vw, 12px)',
              }}>
                {label}
              </Text>
            )}
            
            <TouchableOpacity
              style={[
                styles.checkboxButton,
                hasError && styles.errorBorder,
                {
                  borderColor: installmentCheckboxGlowColor,
                  boxShadow: installmentCheckboxBoxShadow,
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'flex-start',
                  gap: 'clamp(12px, 2vw, 16px)',
                  paddingRight: 'clamp(12px, 2vw, 16px)',
                  paddingTop: value ? 'clamp(14px, 2.5vw, 18px)' : 'clamp(8px, 1.5vw, 12px)',
                  paddingBottom: value ? 'clamp(10px, 2vw, 14px)' : 'clamp(8px, 1.5vw, 12px)',
                  minHeight: value ? 56 : 44
                },
                installmentDynamicStyle
              ]}
              onPress={() => {
                onChange(!value);
                // Checkbox değişikliği front.js'deki updateHarcamaBorcFields/updateGelirFields tarafından hallediliyor
              }}
              onPressIn={() => setIsCheckboxPressed(true)}
              onPressOut={() => setIsCheckboxPressed(false)}
              onMouseEnter={() => setIsCheckboxHovered(true)}
              onMouseLeave={() => setIsCheckboxHovered(false)}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <View
                  style={{
                    width: 16,
                    height: 16,
                    borderRadius: 4,
                    backgroundColor: value ? (isInstallmentCheckboxRequired ? '#dc3545' : '#28a745') : 'transparent',
                    borderWidth: 1,
                    borderColor: value ? (isInstallmentCheckboxRequired ? '#dc3545' : '#28a745') : '#fff',
                    justifyContent: 'center',
                    alignItems: 'center',
                    transition: 'all 0.3s ease',
                    display: 'flex'
                  }}
                >
                  {value && (
                    <Text style={{ color: '#fff', fontSize: 12, lineHeight: 16 }}>✓</Text>
                  )}
                </View>
                {!value && (
                  <Text style={[styles.checkboxText, { marginLeft: 8, lineHeight: 28 }]}>{label}</Text>
                )}
              </View>
              
              {value && (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                  {/* Custom Taksit Dropdown */}
                  <div
                    ref={installmentDropdownButtonRef}
                    style={{
                      width: 65,
                      height: 24,
                      borderRadius: 6,
                      border: finalInstallmentCount > 0 
                        ? '1px solid rgba(40, 167, 69, 0.4)' 
                        : '1px solid rgba(0, 123, 255, 0.4)',
                      backgroundColor: 'rgba(30, 40, 50, 0.95)',
                      color: finalInstallmentCount > 0 
                        ? 'rgba(40, 167, 69, 0.95)' 
                        : '#fff',
                      fontSize: 'clamp(10px, 2vw, 13px)',
                      fontFamily: GLOBAL_FONT_FAMILY,
                      cursor: 'pointer',
                      outline: 'none',
                      boxShadow: finalInstallmentCount > 0
                        ? '0 2px 6px rgba(0, 0, 0, 0.2), 0 0 6px rgba(40, 167, 69, 0.15)'
                        : '0 2px 6px rgba(0, 0, 0, 0.2), 0 0 6px rgba(0, 123, 255, 0.15)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '0 4px',
                      boxSizing: 'border-box',
                      transition: 'all 0.3s ease'
                    }}
                    onClick={(e) => {
                      e.stopPropagation();
                      if (!showInstallmentDropdown && installmentDropdownButtonRef.current) {
                        const rect = installmentDropdownButtonRef.current.getBoundingClientRect();
                        setInstallmentDropdownPosition({
                          top: rect.bottom + 4,
                          left: rect.left
                        });
                      }
                      setShowInstallmentDropdown(!showInstallmentDropdown);
                    }}
                  >
                    <span style={{ flex: 1, textAlign: 'center' }}>
                      {isCustomInstallment ? customInstallmentCount || '?' : installmentCount}
                    </span>
                    <span style={{ 
                      fontSize: '8px',
                      color: showInstallmentDropdown ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.7)',
                      transition: 'transform 0.3s ease',
                      transform: showInstallmentDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                      display: 'inline-block'
                    }}>
                      ▼
                    </span>
                  </div>
                  
                  {/* Taksit Dropdown Options */}
                  {showInstallmentDropdown && createPortal(
                    <div
                      data-installment-dropdown="true"
                      style={{
                        position: 'fixed',
                        top: installmentDropdownPosition.top,
                        left: installmentDropdownPosition.left,
                        width: calculateDynamicDropdownWidth(
                          ['3', '6', '9', '12', '18', '24', '36', 'Özel'], 
                          65, 
                          40
                        ),
                        backgroundColor: 'rgba(20, 25, 30, 0.98)',
                        borderRadius: '12px',
                        padding: '6px',
                        boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                        border: '1px solid rgba(0, 123, 255, 0.5)',
                        zIndex: 99999,
                        backdropFilter: 'blur(12px)',
                        maxHeight: '300px',
                        overflowY: 'auto'
                      }}
                    >
                      {[3, 6, 9, 12, 18, 24, 36, 'custom'].map((option, index) => {
                        const isActive = installmentCount === option;
                        const label = option === 'custom' ? 'Özel' : option;
                        
                        return (
                          <div
                            key={index}
                            style={{
                              padding: '5px 8px',
                              cursor: 'pointer',
                              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                              borderRadius: '8px',
                              marginBottom: '2px',
                              border: isActive ? '1px solid rgba(0, 123, 255, 0.6)' : '1px solid transparent',
                              backgroundColor: isActive ? 'rgba(0, 123, 255, 0.25)' : 'transparent',
                              borderLeft: isActive ? '3px solid rgba(0,123,255,1)' : '3px solid transparent',
                              paddingLeft: isActive ? '6px' : '8px',
                              boxShadow: isActive ? '0 0 12px rgba(0,123,255,0.4), inset 0 0 8px rgba(0,123,255,0.1)' : 'none',
                              fontFamily: GLOBAL_FONT_FAMILY,
                              fontSize: 'clamp(10px, 2vw, 13px)',
                              color: isActive ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.9)',
                              fontWeight: isActive ? '700' : '400',
                              textAlign: 'center',
                              whiteSpace: 'nowrap'
                            }}
                            onMouseEnter={(e) => {
                              if (!isActive) {
                                e.currentTarget.style.backgroundColor = 'rgba(0, 123, 255, 0.15)';
                                e.currentTarget.style.border = '1px solid rgba(0, 123, 255, 0.3)';
                                e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,123,255,0.2)';
                              }
                              e.currentTarget.style.transform = 'translateX(2px)';
                            }}
                            onMouseLeave={(e) => {
                              if (!isActive) {
                                e.currentTarget.style.backgroundColor = 'transparent';
                                e.currentTarget.style.border = '1px solid transparent';
                                e.currentTarget.style.boxShadow = 'none';
                              }
                              e.currentTarget.style.transform = 'translateX(0)';
                            }}
                            onClick={(e) => {
                              e.stopPropagation();
                              if (setFormData) {
                                if (option === 'custom') {
                                  setFormData(prev => ({ 
                                    ...prev, 
                                    [field.installmentFieldId]: 'custom',
                                    [`${field.installmentFieldId}_custom`]: ''
                                  }));
                                } else {
                                  setFormData(prev => ({ 
                                    ...prev, 
                                    [field.installmentFieldId]: parseInt(option),
                                    [`${field.installmentFieldId}_custom`]: ''
                                  }));
                                }
                              }
                              setShowInstallmentDropdown(false);
                            }}
                          >
                            {label}
                          </div>
                        );
                      })}
                    </div>,
                    document.body
                  )}
                  
                  {isCustomInstallment && (
                    <input
                      ref={customInstallmentInputRef}
                      type="number"
                      style={{
                        width: 55,
                        height: 24,
                        borderRadius: 6,
                        border: customInstallmentCount && parseInt(customInstallmentCount) >= 2
                          ? '1px solid rgba(40, 167, 69, 0.4)'
                          : '1px solid rgba(220, 53, 69, 0.4)',
                        backgroundColor: 'rgba(30, 40, 50, 0.95)',
                        color: customInstallmentCount && parseInt(customInstallmentCount) >= 2
                          ? 'rgba(40, 167, 69, 0.95)'
                          : '#fff',
                        fontSize: 'clamp(10px, 2vw, 13px)',
                        fontFamily: GLOBAL_FONT_FAMILY,
                        padding: '2px 4px',
                        outline: 'none',
                        textAlign: 'center',
                        boxSizing: 'border-box',
                        boxShadow: customInstallmentCount && parseInt(customInstallmentCount) >= 2
                          ? '0 2px 6px rgba(0, 0, 0, 0.2), 0 0 6px rgba(40, 167, 69, 0.15)'
                          : '0 2px 6px rgba(0, 0, 0, 0.2), 0 0 6px rgba(220, 53, 69, 0.15)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        lineHeight: '20px'
                      }}
                      placeholder="?"
                      value={customInstallmentCount}
                      onClick={(e) => e.stopPropagation()}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                          e.target.blur();
                          e.stopPropagation();
                        }
                      }}
                      onChange={(e) => {
                        e.stopPropagation();
                        let val = e.target.value;
                        
                        // Real-time kontrol kaldırıldı - sadece değeri kaydet
                        if (setFormData) {
                          setFormData(prev => ({ 
                            ...prev, 
                            [`${field.installmentFieldId}_custom`]: val
                          }));
                        }
                      }}
                      onBlur={(e) => {
                        // Blur olduğunda boşsa veya 2'den küçükse 2 yap
                        e.stopPropagation();
                        const val = e.target.value;
                        if (!val || parseInt(val) < 2) {
                          if (setFormData) {
                            setFormData(prev => ({ 
                              ...prev, 
                              [`${field.installmentFieldId}_custom`]: '2'
                            }));
                          }
                        }
                      }}
                      min="2"
                      max="999"
                    />
                  )}
                  
                  <View style={{ 
                    flex: 1, 
                    display: 'flex', 
                    alignItems: 'center', 
                    justifyContent: 'center'
                  }}>
                    <Text style={{ 
                      color: finalInstallmentCount > 0 && totalAmount > 0
                        ? 'rgba(40, 167, 69, 0.9)'
                        : 'rgba(255, 255, 255, 0.5)', 
                      fontSize: 'clamp(10px, 1.8vw, 13px)',
                      fontFamily: GLOBAL_FONT_FAMILY,
                      textAlign: 'center'
                    }}>
                      {finalInstallmentCount} x {installmentAmount} {currency}
                    </Text>
                  </View>
                </View>
              )}
            </TouchableOpacity>
          </View>
        );

      case 'checkbox-with-select':
        // Checkbox + Data listesi dropdown (Gelir/Gider seçimi için)
        const selectedValue = formData?.[field.selectFieldId] || '';
        const isSelectCheckboxRequired = required && !value;
        const selectCheckboxGlowColor = isSelectCheckboxRequired ? 'rgba(220, 53, 69, 0.3)' : 'rgba(40, 167, 69, 0.3)';
        const selectCheckboxBoxShadow = isSelectCheckboxRequired 
          ? 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)'
          : 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)';
        
        const selectDynamicStyle = isCheckboxPressed ? {
          transform: [{ translateY: 0 }, { scale: 0.98 }],
          filter: 'brightness(1.25)',
        } : isCheckboxHovered ? {
          transform: [{ translateY: -2 }],
          filter: 'brightness(1.1)',
        } : {};
        
        return (
          <View style={{ position: 'relative', width: '100%' }}>
            {/* Floating Label */}
            {value && (
              <Text style={{
                ...styles.formLabelFloating,
                color: 'rgba(0, 123, 255, 0.8)',
                fontSize: 'clamp(9px, 1.8vw, 12px)',
              }}>
                {label}
              </Text>
            )}
            
            <TouchableOpacity
              style={[
                styles.checkboxButton,
                hasError && styles.errorBorder,
                {
                  borderColor: selectCheckboxGlowColor,
                  boxShadow: selectCheckboxBoxShadow,
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'flex-start',
                  gap: 'clamp(12px, 2vw, 16px)',
                  paddingRight: 'clamp(12px, 2vw, 16px)',
                  paddingTop: value ? 'clamp(14px, 2.5vw, 18px)' : 'clamp(8px, 1.5vw, 12px)',
                  paddingBottom: value ? 'clamp(10px, 2vw, 14px)' : 'clamp(8px, 1.5vw, 12px)',
                  minHeight: value ? 56 : 44
                },
                selectDynamicStyle
              ]}
              onPress={() => {
                onChange(!value);
                // Checkbox kapatılırsa seçimi sıfırla
                if (value && setFormData) {
                  setFormData(prev => ({ ...prev, [field.selectFieldId]: '' }));
                }
              }}
              onPressIn={() => setIsCheckboxPressed(true)}
              onPressOut={() => setIsCheckboxPressed(false)}
              onMouseEnter={() => setIsCheckboxHovered(true)}
              onMouseLeave={() => setIsCheckboxHovered(false)}
            >
              <View style={{ flexDirection: 'row', alignItems: 'center' }}>
                <View
                  style={{
                    width: 16,
                    height: 16,
                    borderRadius: 4,
                    backgroundColor: value ? (isSelectCheckboxRequired ? '#dc3545' : '#28a745') : 'transparent',
                    borderWidth: 1,
                    borderColor: value ? (isSelectCheckboxRequired ? '#dc3545' : '#28a745') : '#fff',
                    justifyContent: 'center',
                    alignItems: 'center',
                    transition: 'all 0.3s ease',
                    display: 'flex'
                  }}
                >
                  {value && (
                    <Text style={{ color: '#fff', fontSize: 12, lineHeight: 16 }}>✓</Text>
                  )}
                </View>
                {!value && (
                  <Text style={[styles.checkboxText, { marginLeft: 8, lineHeight: 28 }]}>{label}</Text>
                )}
              </View>
              
              {value && (
                <View style={{ flexDirection: 'row', alignItems: 'center', gap: 8 }}>
                  {/* Custom Checkbox-Select Dropdown */}
                  <div
                    ref={checkboxSelectDropdownButtonRef}
                    style={{
                      minWidth: 150,
                      maxWidth: 350,
                      height: 24,
                      borderRadius: 6,
                      border: selectedValue 
                        ? '1px solid rgba(40, 167, 69, 0.4)' 
                        : '1px solid rgba(220, 53, 69, 0.4)',
                      backgroundColor: 'rgba(30, 40, 50, 0.95)',
                      color: selectedValue 
                        ? 'rgba(40, 167, 69, 0.95)' 
                        : '#fff',
                      fontSize: 'clamp(10px, 2vw, 13px)',
                      fontFamily: GLOBAL_FONT_FAMILY,
                      cursor: 'pointer',
                      outline: 'none',
                      boxShadow: selectedValue
                        ? '0 2px 6px rgba(0, 0, 0, 0.2), 0 0 6px rgba(40, 167, 69, 0.15)'
                        : '0 2px 6px rgba(0, 0, 0, 0.2), 0 0 6px rgba(220, 53, 69, 0.15)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      padding: '0 4px',
                      boxSizing: 'border-box',
                      transition: 'all 0.3s ease'
                    }}
                    onClick={(e) => {
                      e.stopPropagation();
                      if (!showCheckboxSelectDropdown && checkboxSelectDropdownButtonRef.current) {
                        const rect = checkboxSelectDropdownButtonRef.current.getBoundingClientRect();
                        setCheckboxSelectDropdownPosition({
                          top: rect.bottom + 4,
                          left: rect.left
                        });
                      }
                      setShowCheckboxSelectDropdown(!showCheckboxSelectDropdown);
                    }}
                  >
                    <span style={{ 
                      flex: 1,
                      overflow: 'hidden',
                      textOverflow: 'ellipsis',
                      whiteSpace: 'nowrap',
                      fontStyle: selectedValue ? 'normal' : 'italic',
                      color: selectedValue ? 'rgba(40, 167, 69, 0.95)' : 'rgba(255, 255, 255, 0.5)'
                    }}>
                      {selectedValue || ''}
                    </span>
                    <span style={{ 
                      fontSize: '8px',
                      color: showCheckboxSelectDropdown ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.7)',
                      transition: 'transform 0.3s ease',
                      transform: showCheckboxSelectDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                      display: 'inline-block',
                      marginLeft: '4px'
                    }}>
                      ▼
                    </span>
                  </div>
                  
                  {/* Checkbox-Select Dropdown Options */}
                  {showCheckboxSelectDropdown && createPortal(
                    <div
                      data-checkbox-select-dropdown="true"
                      style={{
                        position: 'fixed',
                        top: checkboxSelectDropdownPosition.top,
                        left: checkboxSelectDropdownPosition.left,
                        width: calculateDynamicDropdownWidth(
                          selectOptions?.map(opt => opt[field.dataLabelField] || '') || [], 
                          150, 
                          45
                        ),
                        backgroundColor: 'rgba(20, 25, 30, 0.98)',
                        borderRadius: '12px',
                        padding: '6px',
                        boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                        border: '1px solid rgba(0, 123, 255, 0.5)',
                        zIndex: 99999,
                        backdropFilter: 'blur(12px)',
                        maxHeight: '300px',
                        overflowY: 'auto'
                      }}
                    >
                      {selectOptions && selectOptions.length > 0 && selectOptions.map((option, index) => {
                        const optionValue = option[field.dataLabelField];
                        const isActive = selectedValue === optionValue;
                        
                        return (
                          <div
                            key={index}
                            style={{
                              padding: '5px 8px',
                              cursor: 'pointer',
                              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                              borderRadius: '8px',
                              marginBottom: '2px',
                              border: isActive ? '1px solid rgba(0, 123, 255, 0.6)' : '1px solid transparent',
                              backgroundColor: isActive ? 'rgba(0, 123, 255, 0.25)' : 'transparent',
                              borderLeft: isActive ? '3px solid rgba(0,123,255,1)' : '3px solid transparent',
                              paddingLeft: isActive ? '6px' : '8px',
                              boxShadow: isActive ? '0 0 12px rgba(0,123,255,0.4), inset 0 0 8px rgba(0,123,255,0.1)' : 'none',
                              fontFamily: GLOBAL_FONT_FAMILY,
                              fontSize: 'clamp(10px, 2vw, 13px)',
                              color: isActive ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.9)',
                              fontWeight: isActive ? '700' : '400',
                              whiteSpace: 'nowrap',
                              overflow: 'hidden',
                              textOverflow: 'ellipsis'
                            }}
                            onMouseEnter={(e) => {
                              if (!isActive) {
                                e.currentTarget.style.backgroundColor = 'rgba(0, 123, 255, 0.15)';
                                e.currentTarget.style.border = '1px solid rgba(0, 123, 255, 0.3)';
                                e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,123,255,0.2)';
                              }
                              e.currentTarget.style.transform = 'translateX(2px)';
                            }}
                            onMouseLeave={(e) => {
                              if (!isActive) {
                                e.currentTarget.style.backgroundColor = 'transparent';
                                e.currentTarget.style.border = '1px solid transparent';
                                e.currentTarget.style.boxShadow = 'none';
                              }
                              e.currentTarget.style.transform = 'translateX(0)';
                            }}
                            onClick={(e) => {
                              e.stopPropagation();
                              if (setFormData) {
                                setFormData(prev => ({ 
                                  ...prev, 
                                  [field.selectFieldId]: optionValue
                                }));
                              }
                              setShowCheckboxSelectDropdown(false);
                            }}
                          >
                            {optionValue}
                          </div>
                        );
                      })}
                    </div>,
                    document.body
                  )}
                </View>
              )}
            </TouchableOpacity>
          </View>
        );

      case 'checkbox-with-date':
        // Checkbox + Tarih seçimi (İleri Tarihte Ödeyeceğim için)
        const dateValue = formData?.[field.dateFieldId] || '';
        const dateFieldHasError = hasError || (errors && errors[field.dateFieldId]);
        
        // Tarih geçerli mi kontrol et (yarından önce ise geçersiz)
        let isDateInvalid = false;
        if (value && dateValue) {
          const tomorrow = new Date();
          tomorrow.setDate(tomorrow.getDate() + 1);
          tomorrow.setHours(0, 0, 0, 0);
          
          const selectedDate = new Date(dateValue);
          selectedDate.setHours(0, 0, 0, 0);
          
          isDateInvalid = selectedDate < tomorrow;
        }
        
        const isDateCheckboxRequired = required && !value;
        const dateCheckboxGlowColor = isDateCheckboxRequired ? 'rgba(220, 53, 69, 0.3)' : 'rgba(40, 167, 69, 0.3)';
        const dateCheckboxBoxShadow = isDateCheckboxRequired 
          ? 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)'
          : 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)';
        
        const dateDynamicStyle = isCheckboxPressed ? {
          transform: [{ translateY: 0 }, { scale: 0.98 }],
          filter: 'brightness(1.25)',
        } : isCheckboxHovered ? {
          transform: [{ translateY: -2 }],
          filter: 'brightness(1.1)',
        } : {};
        
        return (
          <View style={{ position: 'relative', width: '100%' }}>
            {/* Floating Label - checkbox işaretliyse göster */}
            {value && (
              <Text style={{
                ...styles.formLabelFloating,
                color: 'rgba(0, 123, 255, 0.8)',
                fontSize: 'clamp(9px, 1.8vw, 12px)',
              }}>
                {field.dateLabel || label}
              </Text>
            )}
            
            <View
              style={[
                styles.checkboxButton,
                hasError && styles.errorBorder,
                {
                  borderColor: dateCheckboxGlowColor,
                  boxShadow: dateCheckboxBoxShadow,
                  flexDirection: 'row',
                  alignItems: 'center',
                  justifyContent: 'flex-start',
                  gap: 'clamp(12px, 2vw, 16px)',
                  paddingRight: 'clamp(12px, 2vw, 16px)',
                  paddingTop: value ? 'clamp(14px, 2.5vw, 18px)' : 'clamp(8px, 1.5vw, 12px)',
                  paddingBottom: value ? 'clamp(10px, 2vw, 14px)' : 'clamp(8px, 1.5vw, 12px)',
                  minHeight: value ? 56 : 44
                }
              ]}
            >
              {/* Ana checkbox ve tarih - sadece innerCheckbox işaretli değilse göster */}
              {!formData?.[field.innerCheckboxId] && (
                <>
                  <View style={{ flexDirection: 'row', alignItems: 'center', position: 'relative', zIndex: 10 }}>
                    <View
                      style={{
                        width: 16,
                        height: 16,
                        borderRadius: 4,
                        backgroundColor: value ? (isDateCheckboxRequired ? '#dc3545' : '#28a745') : 'transparent',
                        borderWidth: 1,
                        borderColor: value ? (isDateCheckboxRequired ? '#dc3545' : '#28a745') : '#fff',
                        justifyContent: 'center',
                        alignItems: 'center',
                        transition: 'all 0.3s ease',
                        display: 'flex',
                        cursor: 'pointer',
                        position: 'relative',
                        zIndex: 11
                      }}
                      onClick={(e) => {
                        e.stopPropagation();
                        e.preventDefault();
                        // Sadece onChange callback'ini çağır, parent'ta halledilecek
                        onChange(!value);
                      }}
                    >
                      {value && (
                        <Text style={{ color: '#fff', fontSize: 12, lineHeight: 16, pointerEvents: 'none' }}>✓</Text>
                      )}
                    </View>
                    <Text 
                      style={[styles.checkboxText, { marginLeft: 8, lineHeight: 28, cursor: 'pointer', position: 'relative', zIndex: 11 }]}
                      onClick={(e) => {
                        e.stopPropagation();
                        e.preventDefault();
                        // Sadece onChange callback'ini çağır, parent'ta halledilecek
                        onChange(!value);
                      }}
                    >
                      {label}
                    </Text>
                  </View>
                  
                  {/* Tarih input'u sadece checkbox işaretliyse göster */}
                  {value && (
                <div style={{ 
                  display: 'flex', 
                  flexDirection: 'row', 
                  alignItems: 'center', 
                  flexShrink: 0,
                  width: '110px',
                  marginRight: '8px',
                  position: 'relative',
                  zIndex: 1
                }}>
                  <input
                    type="date"
                    className="table-date-input custom-date-compact"
                    data-has-value={dateValue ? 'true' : 'false'}
                    style={{
                      width: 90,
                      maxWidth: 90,
                      height: 24,
                      borderRadius: 6,
                      flexShrink: 0,
                      border: (dateFieldHasError || isDateInvalid)
                        ? '1px solid rgba(220, 53, 69, 0.6)'  // Error veya geçersiz → Kırmızı
                        : (dateValue 
                          ? '1px solid rgba(40, 167, 69, 0.4)'  // Geçerli tarih → Yeşil
                          : '1px solid rgba(220, 53, 69, 0.4)'), // Tarih yok → Kırmızı
                      backgroundColor: 'rgba(30, 40, 50, 0.95)',
                      fontSize: '11px',
                      fontFamily: GLOBAL_FONT_FAMILY,
                      padding: '0 2px',
                      outline: 'none',
                      textAlign: 'left',
                      boxShadow: (dateFieldHasError || isDateInvalid)
                        ? '0 2px 6px rgba(0, 0, 0, 0.2), 0 0 8px rgba(220, 53, 69, 0.25)'  // Error → Kırmızı glow
                        : (dateValue
                          ? '0 2px 6px rgba(0, 0, 0, 0.2), 0 0 6px rgba(40, 167, 69, 0.15)'
                          : '0 2px 6px rgba(0, 0, 0, 0.2), 0 0 6px rgba(220, 53, 69, 0.15)'),
                      lineHeight: '20px',
                      boxSizing: 'border-box'
                    }}
                    value={dateValue}
                    onClick={(e) => e.stopPropagation()}
                    onChange={(e) => {
                      e.stopPropagation();
                      const newDate = e.target.value;
                      
                      // Tarih değişince validation tetiklensin diye manuel kontrol
                      if (onFieldChange) {
                        onFieldChange(field.dateFieldId, newDate);
                      }
                    }}
                  />
                </div>
                  )}
                </>
              )}
              
              {/* İç checkbox (Ödeme Alınca Ödeyeceğim) - innerCheckbox işaretli değilse göster */}
              {field.hasInnerCheckbox && (
                <div style={{ 
                  display: 'flex', 
                  flexDirection: 'row', 
                  alignItems: 'center', 
                  gap: '8px',
                  flexShrink: 0
                }}>
                  {/* Checkbox */}
                  <View
                    style={{
                      width: 16,
                      height: 16,
                      borderRadius: 4,
                      backgroundColor: formData?.[field.innerCheckboxId] ? '#28a745' : 'transparent',
                      borderWidth: 1,
                      borderColor: formData?.[field.innerCheckboxId] ? '#28a745' : '#fff',
                      justifyContent: 'center',
                      alignItems: 'center',
                      transition: 'all 0.3s ease',
                      display: 'flex',
                      cursor: 'pointer'
                    }}
                    onClick={(e) => {
                      e.stopPropagation();
                      const newValue = !formData?.[field.innerCheckboxId];
                      if (onFieldChange) {
                        onFieldChange(field.innerCheckboxId, newValue);
                      }
                    }}
                  >
                    {formData?.[field.innerCheckboxId] && (
                      <Text style={{ color: '#fff', fontSize: 12, lineHeight: 16 }}>✓</Text>
                    )}
                  </View>
                  
                  {/* Label */}
                  <Text 
                    style={{
                      color: '#fff',
                      fontSize: 'clamp(10px, 2vw, 13px)',
                      fontFamily: GLOBAL_FONT_FAMILY,
                      lineHeight: 16,
                      cursor: 'pointer'
                    }}
                    onClick={(e) => {
                      e.stopPropagation();
                      const newValue = !formData?.[field.innerCheckboxId];
                      if (onFieldChange) {
                        onFieldChange(field.innerCheckboxId, newValue);
                      }
                    }}
                  >
                    {field.innerCheckboxLabel}
                  </Text>
                  
                  {/* Dropdown - Checkbox işaretliyse göster */}
                  {formData?.[field.innerCheckboxId] && field.innerSelectFieldId && (
                    <View 
                      style={{ 
                        position: 'relative'
                      }}
                      onClick={(e) => e.stopPropagation()}
                    >
                      <div
                        ref={checkboxSelectDropdownButtonRef}
                        style={{
                          width: 150,
                          height: 24,
                          borderRadius: 6,
                          border: formData?.[field.innerSelectFieldId]
                            ? '1px solid rgba(40, 167, 69, 0.4)'
                            : '1px solid rgba(220, 53, 69, 0.4)',
                          backgroundColor: 'rgba(30, 40, 50, 0.95)',
                          color: formData?.[field.innerSelectFieldId]
                            ? 'rgba(40, 167, 69, 0.95)'
                            : '#fff',
                          fontSize: 'clamp(9px, 1.8vw, 11px)',
                          fontFamily: GLOBAL_FONT_FAMILY,
                          cursor: 'pointer',
                          padding: '0 4px',
                          outline: 'none',
                          boxShadow: formData?.[field.innerSelectFieldId]
                            ? '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(40, 167, 69, 0.2)'
                            : '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(220, 53, 69, 0.2)',
                          transition: 'all 0.3s ease',
                          lineHeight: '24px',
                          display: 'flex',
                          alignItems: 'center',
                          justifyContent: 'space-between',
                          fontWeight: formData?.[field.innerSelectFieldId] ? '700' : '400',
                          zIndex: 10,
                          boxSizing: 'border-box'
                        }}
                        onClick={(e) => {
                          e.stopPropagation();
                          if (!showCheckboxSelectDropdown && checkboxSelectDropdownButtonRef.current) {
                            const rect = checkboxSelectDropdownButtonRef.current.getBoundingClientRect();
                            setCheckboxSelectDropdownPosition({
                              top: rect.bottom + 4,
                              left: rect.left
                            });
                            // Diğer dropdown'ları kapat
                            setShowCustomDropdown(false);
                            setShowParaBirimiDropdown(false);
                            setShowSelectWithCustomDropdown(false);
                          }
                          setShowCheckboxSelectDropdown(!showCheckboxSelectDropdown);
                        }}
                      >
                        <span style={{ flex: 1, textAlign: 'center', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {formData?.[field.innerSelectFieldId] || 'Seçiniz...'}
                        </span>
                        <span style={{ 
                          fontSize: '8px',
                          color: showCheckboxSelectDropdown ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.7)',
                          transition: 'transform 0.3s ease',
                          transform: showCheckboxSelectDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                          display: 'inline-block'
                        }}>
                          ▼
                        </span>
                      </div>
                      
                      {/* Custom Dropdown */}
                      {showCheckboxSelectDropdown && createPortal(
                        <div
                          data-checkbox-select-dropdown="true"
                          style={{
                            position: 'fixed',
                            top: checkboxSelectDropdownPosition.top,
                            left: checkboxSelectDropdownPosition.left,
                            width: calculateDynamicDropdownWidth(
                              (selectOptions || []).map(opt => opt[field.innerDataLabelField] || opt), 
                              150, 
                              40
                            ),
                            backgroundColor: 'rgba(20, 25, 30, 0.98)',
                            borderRadius: '12px',
                            padding: '6px',
                            boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                            border: '1px solid rgba(0, 123, 255, 0.5)',
                            zIndex: 99999,
                            backdropFilter: 'blur(12px)',
                            maxHeight: '250px',
                            overflowY: 'auto'
                          }}
                        >
                          {(selectOptions || []).map((option, index) => {
                            const optionLabel = option[field.innerDataLabelField] || option;
                            const optionValue = option[field.innerDataLabelField] || option;
                            const isActive = formData?.[field.innerSelectFieldId] === optionValue;
                            
                            return (
                              <div
                                key={index}
                                style={{
                                  padding: '5px 8px',
                                  cursor: 'pointer',
                                  transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                                  borderRadius: '8px',
                                  marginBottom: '2px',
                                  border: isActive ? '1px solid rgba(40, 167, 69, 0.6)' : '1px solid transparent',
                                  backgroundColor: isActive ? 'rgba(40, 167, 69, 0.25)' : 'transparent',
                                  borderLeft: isActive ? '3px solid rgba(40,167,69,1)' : '3px solid transparent',
                                  paddingLeft: isActive ? '6px' : '8px',
                                  boxShadow: isActive ? '0 0 12px rgba(40,167,69,0.4), inset 0 0 8px rgba(40,167,69,0.1)' : 'none',
                                  fontFamily: GLOBAL_FONT_FAMILY,
                                  fontSize: 'clamp(9px, 1.8vw, 11px)',
                                  color: isActive ? 'rgba(40, 167, 69, 1)' : 'rgba(255, 255, 255, 0.9)',
                                  fontWeight: isActive ? '700' : '400',
                                  textAlign: 'center',
                                  whiteSpace: 'nowrap'
                                }}
                                onMouseEnter={(e) => {
                                  if (!isActive) {
                                    e.currentTarget.style.backgroundColor = 'rgba(0, 123, 255, 0.15)';
                                    e.currentTarget.style.border = '1px solid rgba(0, 123, 255, 0.3)';
                                    e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,123,255,0.2)';
                                  }
                                  e.currentTarget.style.transform = 'translateX(2px)';
                                }}
                                onMouseLeave={(e) => {
                                  if (!isActive) {
                                    e.currentTarget.style.backgroundColor = 'transparent';
                                    e.currentTarget.style.border = '1px solid transparent';
                                    e.currentTarget.style.boxShadow = 'none';
                                  }
                                  e.currentTarget.style.transform = 'translateX(0)';
                                }}
                                onClick={(e) => {
                                  e.stopPropagation();
                                  if (onFieldChange) {
                                    onFieldChange(field.innerSelectFieldId, optionValue);
                                  }
                                  setShowCheckboxSelectDropdown(false);
                                }}
                              >
                                {optionLabel}
                              </div>
                            );
                          })}
                        </div>,
                        document.body
                      )}
                    </View>
                  )}
                </div>
              )}
            </View>
          </View>
        );

      case 'checkbox':
        // Checkbox için de aynı renk mantığı
        const isCheckboxRequired = required && !value;
        const checkboxGlowColor = isCheckboxRequired ? 'rgba(220, 53, 69, 0.3)' : 'rgba(40, 167, 69, 0.3)';
        const checkboxBoxShadow = isCheckboxRequired 
          ? 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)'
          : 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)';
        
        // Hover ve pressed durumları için stil
        const checkboxDynamicStyle = isCheckboxPressed ? {
          transform: [{ translateY: 0 }, { scale: 0.98 }],
          filter: 'brightness(1.25)',
        } : isCheckboxHovered ? {
          transform: [{ translateY: -2 }],
          filter: 'brightness(1.1)',
        } : {};
        
        return (
          <TouchableOpacity
            style={[
              styles.checkboxButton,
              hasError && styles.errorBorder,
              {
                borderColor: checkboxGlowColor,
                boxShadow: checkboxBoxShadow,
              },
              checkboxDynamicStyle
            ]}
            onPress={() => onChange(!value)}
            onPressIn={() => setIsCheckboxPressed(true)}
            onPressOut={() => setIsCheckboxPressed(false)}
            onMouseEnter={() => setIsCheckboxHovered(true)}
            onMouseLeave={() => setIsCheckboxHovered(false)}
          >
            <View
              style={{
                width: 16,
                height: 16,
                borderRadius: 4,
                backgroundColor: value ? (isCheckboxRequired ? '#dc3545' : '#28a745') : 'transparent',
                borderWidth: 1,
                borderColor: value ? (isCheckboxRequired ? '#dc3545' : '#28a745') : '#fff',
                justifyContent: 'center',
                alignItems: 'center',
                transition: 'all 0.3s ease'
              }}
            >
              {value && (
                <Text style={{ color: '#fff', fontSize: 12, lineHeight: 16 }}>✓</Text>
              )}
            </View>
            <Text style={styles.checkboxText}>
              {value && field.checkedLabel ? field.checkedLabel : label}
            </Text>
          </TouchableOpacity>
        );

      case 'date':
        const today = new Date().toISOString().split('T')[0];
        return (
          <View style={[
            {
              width: '100%',
              position: 'relative'
            }
          ]}>
            <input
              type="date"
              onChange={handleDateChange}
              onFocus={() => setIsFocused(true)}
              onBlur={() => setIsFocused(false)}
              value={value || today}
              data-required={isRequired ? 'true' : 'false'}
              data-has-value={hasValue ? 'true' : 'false'}
              style={{
                width: '100%',
                backgroundColor: 'transparent'
              }}
            />
          </View>
        );

      case 'datetime-local':
        const now = formatDateTime(new Date());
        return (
          <View style={[
            {
              width: '100%',
              position: 'relative'
            }
          ]}>
            <input
              type="datetime-local"
              onChange={handleDateChange}
              onFocus={() => setIsFocused(true)}
              onBlur={() => setIsFocused(false)}
              value={value || now}
              data-required={isRequired ? 'true' : 'false'}
              data-has-value={hasValue ? 'true' : 'false'}
              style={{
                width: '100%',
                backgroundColor: 'transparent'
              }}
            />
          </View>
        );

      case 'select':
        const selectStyle = {
          ...styles.formInput,
          ...(hasError && styles.errorBorder),
          borderColor: isRequired ? 'rgba(220, 53, 69, 0.3)' : 'rgba(40, 167, 69, 0.3)',
          boxShadow: isRequired 
            ? `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)`
            : `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)`,
          width: '100%',
          cursor: 'pointer',
          color: hasValue ? 'rgba(40, 167, 69, 0.95)' : 'rgba(255, 255, 255, 0.9)',
          transition: 'all 0.3s ease',
          fontWeight: hasValue ? '700' : '400',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'space-between',
          paddingRight: 'clamp(12px, 2vw, 16px)',
          position: 'relative'
        };
        
        // Kategori select ve özel kategoriler seçiliyse varlık dropdown'u göster
        const isParaCategory = field.id === 'kategori' && value === 'PARA';
        const isKriptoCategory = field.id === 'kategori' && value === 'KRİPTO PARA';
        const isHisseCategory = field.id === 'kategori' && value === 'HİSSE SENEDİ';
        const isBonoCategory = field.id === 'kategori' && value === 'BONO-TAHVİL';
        const showVarlikDropdown = isKriptoCategory || isHisseCategory || isBonoCategory;
        
        const paraBirimiValue = formData?.para_birimi_kategori || '';
        const varlikKriptoValue = formData?.varlik_kripto || '';
        const varlikHisseValue = formData?.varlik_hisse || '';
        const varlikBonoValue = formData?.varlik_bono || '';
        
        // Hangi varlık değerini kullanacağımızı belirle
        let currentVarlikValue = '';
        let currentVarlikFieldId = '';
        let currentVarlikOptions = [];
        
        if (isKriptoCategory) {
          currentVarlikValue = varlikKriptoValue;
          currentVarlikFieldId = 'varlik_kripto';
          currentVarlikOptions = ['BTC', 'ETH', 'BNB', 'SOL', 'XRP'];
        } else if (isHisseCategory) {
          currentVarlikValue = varlikHisseValue;
          currentVarlikFieldId = 'varlik_hisse';
          currentVarlikOptions = ['AAPL', 'GOOGL', 'MSFT', 'TSLA', 'AMZN'];
        } else if (isBonoCategory) {
          currentVarlikValue = varlikBonoValue;
          currentVarlikFieldId = 'varlik_bono';
          currentVarlikOptions = ['ABD 10Y', 'EUR 10Y', 'TÜRKİYE 10Y', 'JGB 10Y', 'UK 10Y'];
        }
        
        // Seçili option'ın label'ını bul
        const selectedOption = field.options?.find(opt => (opt.value || opt) === value);
        const selectedLabel = selectedOption ? (selectedOption.label || selectedOption) : (value || '');
        
        // En uzun option'ı bul ve genişliği hesapla (hasCustomInput varsa "Diğer" de hesaba kat)
        const optionsForWidth = field.hasCustomInput 
          ? [...(field.options || []), { value: 'Diğer', label: 'Diğer' }] 
          : (field.options || []);
        const dropdownWidth = calculateDynamicDropdownWidth(optionsForWidth, 150, 45);
        
        return (
          <View style={{ 
            flexDirection: 'row', 
            alignItems: 'center', 
            width: '100%',
            position: 'relative'
          }}>
            {/* Custom Dropdown Button */}
            <div
              ref={customDropdownButtonRef}
              style={{
                ...selectStyle,
                flex: (isParaCategory || showVarlikDropdown) ? 1 : undefined,
                paddingRight: (isParaCategory || showVarlikDropdown) ? 30 : selectStyle.paddingRight,
                position: 'relative'
              }}
              onClick={() => {
                if (!showCustomDropdown && customDropdownButtonRef.current) {
                  const rect = customDropdownButtonRef.current.getBoundingClientRect();
                  setDropdownPosition({
                    top: rect.bottom + 4,
                    left: rect.left,
                    width: rect.width
                  });
                  // Diğer dropdown'u kapat
                  setShowSelectWithCustomDropdown(false);
                  setShowParaBirimiDropdown(false);
                }
                setShowCustomDropdown(!showCustomDropdown);
              }}
            >
              <span style={{ 
                color: hasValue ? 'rgba(40, 167, 69, 0.95)' : 'rgba(255, 255, 255, 0.5)',
                fontStyle: hasValue ? 'normal' : 'italic'
              }}>
                {selectedLabel}
              </span>
              <span style={{ 
                fontSize: '12px',
                color: showCustomDropdown ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.7)',
                transition: 'transform 0.3s ease',
                display: 'inline-block',
                position: 'absolute',
                right: '12px',
                top: '50%',
                transform: showCustomDropdown ? 'translateY(-50%) rotate(180deg)' : 'translateY(-50%) rotate(0deg)'
              }}>
                ▼
              </span>
            </div>
            
            {/* Custom Dropdown Options - Portal ile body'e render */}
            {showCustomDropdown && createPortal(
              <div
                data-custom-dropdown="true"
                style={{
                  position: 'fixed',
                  top: dropdownPosition.top,
                  left: dropdownPosition.left,
                  width: dropdownWidth,
                  backgroundColor: 'rgba(20, 25, 30, 0.98)',
                  borderRadius: '12px',
                  padding: '6px',
                  boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                  border: '1px solid rgba(0, 123, 255, 0.5)',
                  zIndex: 99999,
                  backdropFilter: 'blur(12px)',
                  maxHeight: '300px',
                  overflowY: 'auto'
                }}
              >
                {field.options && field.options.map((option, index) => {
                  const optionValue = option.value || option;
                  const optionLabel = option.label || option;
                  const isActive = value === optionValue;
                  
                  return (
                    <div
                      key={index}
                      style={{
                        padding: '6px 10px',
                        cursor: 'pointer',
                        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                        borderRadius: '8px',
                        marginBottom: '2px',
                        border: isActive ? '1px solid rgba(0, 123, 255, 0.6)' : '1px solid transparent',
                        backgroundColor: isActive ? 'rgba(0, 123, 255, 0.25)' : 'transparent',
                        borderLeft: isActive ? '3px solid rgba(0,123,255,1)' : '3px solid transparent',
                        paddingLeft: isActive ? '8px' : '10px',
                        boxShadow: isActive ? '0 0 12px rgba(0,123,255,0.4), inset 0 0 8px rgba(0,123,255,0.1)' : 'none',
                        fontFamily: GLOBAL_FONT_FAMILY,
                        fontSize: 'clamp(11px, 2vw, 14px)',
                        color: isActive ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.9)',
                        fontWeight: isActive ? '700' : '400'
                      }}
                      onMouseEnter={(e) => {
                        setHoveredOption(index);
                        if (!isActive) {
                          e.currentTarget.style.backgroundColor = 'rgba(0, 123, 255, 0.15)';
                          e.currentTarget.style.border = '1px solid rgba(0, 123, 255, 0.3)';
                          e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,123,255,0.2)';
                        }
                        e.currentTarget.style.transform = 'translateX(4px)';
                      }}
                      onMouseLeave={(e) => {
                        setHoveredOption(null);
                        if (!isActive) {
                          e.currentTarget.style.backgroundColor = 'transparent';
                          e.currentTarget.style.border = '1px solid transparent';
                          e.currentTarget.style.boxShadow = 'none';
                        }
                        e.currentTarget.style.transform = 'translateX(0)';
                      }}
                      onClick={() => {
                        onChange(optionValue);
                        setShowCustomDropdown(false);
                      }}
                    >
                      {optionLabel}
                    </div>
                  );
                })}
                
                {/* Diğer - Custom Input (sadece hasCustomInput varsa) */}
                {field.hasCustomInput && (
                  <div style={{
                    padding: '5px 8px',
                    borderRadius: '8px',
                    marginBottom: '2px'
                  }}>
                    <input
                      ref={customVarlikInputRef}
                      type="text"
                      placeholder="Diğer"
                      maxLength={50}
                      value={customVarlik}
                      onClick={(e) => {
                        e.stopPropagation();
                        setTimeout(() => {
                          customVarlikInputRef.current?.focus();
                        }, 0);
                      }}
                      onChange={(e) => {
                        e.stopPropagation();
                        const val = e.target.value;
                        setCustomVarlik(val);
                      }}
                      onKeyDown={(e) => {
                        if (e.key === 'Enter' && customVarlik.trim() !== '') {
                          e.stopPropagation();
                          onChange(customVarlik.trim());
                          setCustomVarlik('');
                          setShowCustomDropdown(false);
                        }
                      }}
                      style={{
                        width: '100%',
                        height: '24px',
                        borderRadius: '4px',
                        border: customVarlik.trim() !== '' 
                          ? '1px solid rgba(0, 123, 255, 0.4)' 
                          : '1px solid rgba(255, 255, 255, 0.2)',
                        backgroundColor: 'rgba(20, 25, 30, 0.95)',
                        color: customVarlik.trim() !== '' 
                          ? 'rgba(0, 123, 255, 1)' 
                          : 'rgba(255, 255, 255, 0.9)',
                        fontSize: 'clamp(9px, 1.8vw, 12px)',
                        fontFamily: GLOBAL_FONT_FAMILY,
                        padding: '2px 6px',
                        outline: 'none',
                        textAlign: 'center',
                        boxSizing: 'border-box',
                        transition: 'all 0.3s ease'
                      }}
                    />
                  </div>
                )}
              </div>,
              document.body
            )}
            
            {isParaCategory && (
              <>
                <div
                  ref={paraBirimiDropdownButtonRef}
                  style={{
                    position: 'absolute',
                    right: 50,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    width: 90,
                    height: 24,
                    borderRadius: 6,
                    border: paraBirimiValue 
                      ? '1px solid rgba(40, 167, 69, 0.4)' 
                      : '1px solid rgba(220, 53, 69, 0.4)',
                    backgroundColor: 'rgba(30, 40, 50, 0.95)',
                    color: paraBirimiValue 
                      ? 'rgba(40, 167, 69, 0.95)' 
                      : '#fff',
                    fontSize: 'clamp(9px, 1.8vw, 12px)',
                    fontFamily: GLOBAL_FONT_FAMILY,
                    cursor: 'pointer',
                    padding: '0 4px',
                    outline: 'none',
                    boxShadow: paraBirimiValue
                      ? '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(40, 167, 69, 0.2)'
                      : '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(220, 53, 69, 0.2)',
                    transition: 'all 0.3s ease',
                    lineHeight: '24px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    fontWeight: paraBirimiValue ? '700' : '400',
                    zIndex: 10,
                    boxSizing: 'border-box'
                  }}
                  onClick={(e) => {
                    e.stopPropagation();
                    if (!showParaBirimiDropdown && paraBirimiDropdownButtonRef.current) {
                      const rect = paraBirimiDropdownButtonRef.current.getBoundingClientRect();
                      setParaBirimiDropdownPosition({
                        top: rect.bottom + 4,
                        left: rect.left,
                        width: 90
                      });
                      // Diğer dropdown'ları kapat
                      setShowCustomDropdown(false);
                      setShowSelectWithCustomDropdown(false);
                    }
                    setShowParaBirimiDropdown(!showParaBirimiDropdown);
                  }}
                >
                  <span style={{ flex: 1, textAlign: 'center' }}>
                    {paraBirimiValue || 'Seç...'}
                  </span>
                  <span style={{ 
                    fontSize: '8px',
                    color: showParaBirimiDropdown ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.7)',
                    transition: 'transform 0.3s ease',
                    transform: showParaBirimiDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                    display: 'inline-block'
                  }}>
                    ▼
                  </span>
                </div>
                
                {/* Para Birimi Custom Dropdown */}
                {showParaBirimiDropdown && createPortal(
                  <div
                    data-para-birimi-dropdown="true"
                    style={{
                      position: 'fixed',
                      top: paraBirimiDropdownPosition.top,
                      left: paraBirimiDropdownPosition.left,
                      width: calculateDynamicDropdownWidth(
                        ['TL', 'USD', 'EUR', 'GBP', 'Gram Altın', 'Gram Gümüş', 'Diğer'], 
                        90, 
                        40
                      ),
                      backgroundColor: 'rgba(20, 25, 30, 0.98)',
                      borderRadius: '12px',
                      padding: '6px',
                      boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                      border: '1px solid rgba(0, 123, 255, 0.5)',
                      zIndex: 99999,
                      backdropFilter: 'blur(12px)',
                      maxHeight: '250px',
                      overflowY: 'auto'
                    }}
                  >
                    {['TL', 'USD', 'EUR', 'GBP', 'Gram Altın', 'Gram Gümüş'].map((currency, index) => {
                      const isActive = paraBirimiValue === currency;
                      
                      return (
                        <div
                          key={index}
                          style={{
                            padding: '5px 8px',
                            cursor: 'pointer',
                            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                            borderRadius: '8px',
                            marginBottom: '2px',
                            border: isActive ? '1px solid rgba(0, 123, 255, 0.6)' : '1px solid transparent',
                            backgroundColor: isActive ? 'rgba(0, 123, 255, 0.25)' : 'transparent',
                            borderLeft: isActive ? '3px solid rgba(0,123,255,1)' : '3px solid transparent',
                            paddingLeft: isActive ? '6px' : '8px',
                            boxShadow: isActive ? '0 0 12px rgba(0,123,255,0.4), inset 0 0 8px rgba(0,123,255,0.1)' : 'none',
                            fontFamily: GLOBAL_FONT_FAMILY,
                            fontSize: 'clamp(9px, 1.8vw, 12px)',
                            color: isActive ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.9)',
                            fontWeight: isActive ? '700' : '400',
                            textAlign: 'center',
                            whiteSpace: 'nowrap'
                          }}
                          onMouseEnter={(e) => {
                            if (!isActive) {
                              e.currentTarget.style.backgroundColor = 'rgba(0, 123, 255, 0.15)';
                              e.currentTarget.style.border = '1px solid rgba(0, 123, 255, 0.3)';
                              e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,123,255,0.2)';
                            }
                            e.currentTarget.style.transform = 'translateX(2px)';
                          }}
                          onMouseLeave={(e) => {
                            if (!isActive) {
                              e.currentTarget.style.backgroundColor = 'transparent';
                              e.currentTarget.style.border = '1px solid transparent';
                              e.currentTarget.style.boxShadow = 'none';
                            }
                            e.currentTarget.style.transform = 'translateX(0)';
                          }}
                          onClick={(e) => {
                            e.stopPropagation();
                            if (setFormData) {
                              setFormData(prev => ({ 
                                ...prev, 
                                para_birimi_kategori: currency
                              }));
                            }
                            // Para birimi değişikliğini parent'a bildir
                            if (onFieldChange) {
                              onFieldChange('para_birimi_kategori', currency);
                            }
                            setShowParaBirimiDropdown(false);
                          }}
                        >
                          {currency}
                        </div>
                      );
                    })}
                    
                    {/* Diğer - Custom Input */}
                    <div style={{
                      padding: '5px 8px',
                      borderRadius: '8px',
                      marginBottom: '2px'
                    }}>
                      <input
                        ref={customParaBirimiInputRef}
                        type="text"
                        placeholder="Diğer"
                        maxLength={10}
                        value={customParaBirimi}
                        onClick={(e) => {
                          e.stopPropagation();
                          setTimeout(() => {
                            customParaBirimiInputRef.current?.focus();
                          }, 0);
                        }}
                        onChange={(e) => {
                          e.stopPropagation();
                          const val = e.target.value.toUpperCase();
                          setCustomParaBirimi(val);
                        }}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' && customParaBirimi.trim() !== '') {
                            e.stopPropagation();
                            if (setFormData) {
                              setFormData(prev => ({ 
                                ...prev, 
                                para_birimi_kategori: customParaBirimi.trim()
                              }));
                            }
                            if (onFieldChange) {
                              onFieldChange('para_birimi_kategori', customParaBirimi.trim());
                            }
                            setCustomParaBirimi('');
                            setShowParaBirimiDropdown(false);
                          }
                        }}
                        style={{
                          width: '100%',
                          height: '24px',
                          borderRadius: '4px',
                          border: customParaBirimi.trim() !== '' 
                            ? '1px solid rgba(0, 123, 255, 0.4)' 
                            : '1px solid rgba(255, 255, 255, 0.2)',
                          backgroundColor: 'rgba(20, 25, 30, 0.95)',
                          color: customParaBirimi.trim() !== '' 
                            ? 'rgba(0, 123, 255, 1)' 
                            : 'rgba(255, 255, 255, 0.9)',
                          fontSize: 'clamp(9px, 1.8vw, 12px)',
                          fontFamily: GLOBAL_FONT_FAMILY,
                          padding: '2px 6px',
                          outline: 'none',
                          textAlign: 'center',
                          boxSizing: 'border-box',
                          transition: 'all 0.3s ease'
                        }}
                      />
                    </div>
                  </div>,
                  document.body
                )}
              </>
            )}
            
            {showVarlikDropdown && (
              <>
                <div
                  ref={selectWithCustomDropdownButtonRef}
                  style={{
                    position: 'absolute',
                    right: 50,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    width: 120,
                    height: 24,
                    borderRadius: 6,
                    border: currentVarlikValue 
                      ? '1px solid rgba(40, 167, 69, 0.4)' 
                      : '1px solid rgba(220, 53, 69, 0.4)',
                    backgroundColor: 'rgba(30, 40, 50, 0.95)',
                    color: currentVarlikValue 
                      ? 'rgba(40, 167, 69, 0.95)' 
                      : '#fff',
                    fontSize: 'clamp(9px, 1.8vw, 12px)',
                    fontFamily: GLOBAL_FONT_FAMILY,
                    cursor: 'pointer',
                    padding: '0 4px',
                    outline: 'none',
                    boxShadow: currentVarlikValue
                      ? '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(40, 167, 69, 0.2)'
                      : '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(220, 53, 69, 0.2)',
                    transition: 'all 0.3s ease',
                    lineHeight: '24px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    fontWeight: currentVarlikValue ? '700' : '400',
                    zIndex: 10,
                    boxSizing: 'border-box'
                  }}
                  onClick={(e) => {
                    e.stopPropagation();
                    if (!showSelectWithCustomDropdown && selectWithCustomDropdownButtonRef.current) {
                      const rect = selectWithCustomDropdownButtonRef.current.getBoundingClientRect();
                      setSelectWithCustomDropdownPosition({
                        top: rect.bottom + 4,
                        left: rect.left
                      });
                      // Diğer dropdown'ları kapat
                      setShowCustomDropdown(false);
                      setShowParaBirimiDropdown(false);
                    }
                    setShowSelectWithCustomDropdown(!showSelectWithCustomDropdown);
                  }}
                >
                  <span style={{ flex: 1, textAlign: 'center' }}>
                    {currentVarlikValue || 'Seç...'}
                  </span>
                  <span style={{ 
                    fontSize: '8px',
                    color: showSelectWithCustomDropdown ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.7)',
                    transition: 'transform 0.3s ease',
                    transform: showSelectWithCustomDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                    display: 'inline-block'
                  }}>
                    ▼
                  </span>
                </div>
                
                {/* Varlık Custom Dropdown */}
                {showSelectWithCustomDropdown && createPortal(
                  <div
                    data-select-with-custom-dropdown="true"
                    style={{
                      position: 'fixed',
                      top: selectWithCustomDropdownPosition.top,
                      left: selectWithCustomDropdownPosition.left,
                      width: calculateDynamicDropdownWidth(
                        [...currentVarlikOptions, 'Diğer'], 
                        120, 
                        40
                      ),
                      backgroundColor: 'rgba(20, 25, 30, 0.98)',
                      borderRadius: '12px',
                      padding: '6px',
                      boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                      border: '1px solid rgba(0, 123, 255, 0.5)',
                      zIndex: 99999,
                      backdropFilter: 'blur(12px)',
                      maxHeight: '300px',
                      overflowY: 'auto'
                    }}
                  >
                    {currentVarlikOptions.map((option, index) => {
                      const isActive = currentVarlikValue === option;
                      
                      return (
                        <div
                          key={index}
                          style={{
                            padding: '5px 8px',
                            cursor: 'pointer',
                            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                            borderRadius: '8px',
                            marginBottom: '2px',
                            border: isActive ? '1px solid rgba(40, 167, 69, 0.6)' : '1px solid transparent',
                            backgroundColor: isActive ? 'rgba(40, 167, 69, 0.25)' : 'transparent',
                            borderLeft: isActive ? '3px solid rgba(40,167,69,1)' : '3px solid transparent',
                            paddingLeft: isActive ? '6px' : '8px',
                            boxShadow: isActive ? '0 0 12px rgba(40,167,69,0.4), inset 0 0 8px rgba(40,167,69,0.1)' : 'none',
                            fontFamily: GLOBAL_FONT_FAMILY,
                            fontSize: 'clamp(9px, 1.8vw, 12px)',
                            color: isActive ? 'rgba(40, 167, 69, 1)' : 'rgba(255, 255, 255, 0.9)',
                            fontWeight: isActive ? '700' : '400',
                            textAlign: 'center',
                            whiteSpace: 'nowrap'
                          }}
                          onMouseEnter={(e) => {
                            if (!isActive) {
                              e.currentTarget.style.backgroundColor = 'rgba(0, 123, 255, 0.15)';
                              e.currentTarget.style.border = '1px solid rgba(0, 123, 255, 0.3)';
                              e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,123,255,0.2)';
                            }
                            e.currentTarget.style.transform = 'translateX(2px)';
                          }}
                          onMouseLeave={(e) => {
                            if (!isActive) {
                              e.currentTarget.style.backgroundColor = 'transparent';
                              e.currentTarget.style.border = '1px solid transparent';
                              e.currentTarget.style.boxShadow = 'none';
                            }
                            e.currentTarget.style.transform = 'translateX(0)';
                          }}
                          onClick={(e) => {
                            e.stopPropagation();
                            if (setFormData) {
                              setFormData(prev => ({ 
                                ...prev, 
                                [currentVarlikFieldId]: option
                              }));
                            }
                            setShowSelectWithCustomDropdown(false);
                          }}
                        >
                          {option}
                        </div>
                      );
                    })}
                    
                    {/* Diğer - Custom Input */}
                    <div style={{
                      padding: '5px 8px',
                      borderRadius: '8px',
                      marginBottom: '2px'
                    }}>
                      <input
                        ref={customVarlikInputRef}
                        type="text"
                        placeholder="Diğer"
                        maxLength={10}
                        value={customVarlik}
                        onClick={(e) => {
                          e.stopPropagation();
                          setTimeout(() => {
                            customVarlikInputRef.current?.focus();
                          }, 0);
                        }}
                        onChange={(e) => {
                          e.stopPropagation();
                          const val = e.target.value.toUpperCase();
                          setCustomVarlik(val);
                        }}
                        onKeyDown={(e) => {
                          if (e.key === 'Enter' && customVarlik.trim() !== '') {
                            e.stopPropagation();
                            if (setFormData) {
                              setFormData(prev => ({ 
                                ...prev, 
                                [currentVarlikFieldId]: customVarlik.trim()
                              }));
                            }
                            setCustomVarlik('');
                            setShowSelectWithCustomDropdown(false);
                          }
                        }}
                        style={{
                          width: '100%',
                          height: '24px',
                          borderRadius: '4px',
                          border: customVarlik.trim() !== '' 
                            ? '1px solid rgba(0, 123, 255, 0.4)' 
                            : '1px solid rgba(255, 255, 255, 0.2)',
                          backgroundColor: 'rgba(20, 25, 30, 0.95)',
                          color: customVarlik.trim() !== '' 
                            ? 'rgba(0, 123, 255, 1)' 
                            : 'rgba(255, 255, 255, 0.9)',
                          fontSize: 'clamp(9px, 1.8vw, 12px)',
                          fontFamily: GLOBAL_FONT_FAMILY,
                          padding: '2px 6px',
                          outline: 'none',
                          textAlign: 'center',
                          boxSizing: 'border-box',
                          transition: 'all 0.3s ease'
                        }}
                      />
                    </div>
                  </div>,
                  document.body
                )}
              </>
            )}
          </View>
        );

      case 'link-or-price':
        // Link veya Fiyat seçimi - number-with-currency tasarımı
        const [inputMode, setInputMode] = useState(() => {
          // Başlangıçta link modunda olsun
          if (typeof value === 'object' && value?.amount) return 'price';
          return 'link';
        });
        const linkOrPriceNumberValue = typeof value === 'object' ? (value?.amount || '') : '';
        const linkOrPriceCurrencyValue = typeof value === 'object' ? (value?.currency || field.defaultCurrency || 'TL') : (field.defaultCurrency || 'TL');
        const linkValue = typeof value === 'string' ? value : '';
        
        // Link-or-price para birimi dropdown için state
        const [showLinkOrPriceCurrencyDropdown, setShowLinkOrPriceCurrencyDropdown] = useState(false);
        const [linkOrPriceCurrencyDropdownPosition, setLinkOrPriceCurrencyDropdownPosition] = useState({ top: 0, left: 0 });
        const linkOrPriceCurrencyDropdownButtonRef = useRef(null);
        const [hoveredLinkOrPriceCurrency, setHoveredLinkOrPriceCurrency] = useState(null);

        // Değer varsa modu otomatik belirle
        useEffect(() => {
          if (typeof value === 'object' && value?.amount) {
            setInputMode('price');
          } else if (typeof value === 'string' && value.trim()) {
            setInputMode('link');
          }
        }, [value]);
        
        // Link-or-price currency dropdown click-outside ve scroll handling
        useEffect(() => {
          if (!showLinkOrPriceCurrencyDropdown) return;

          const handleClickOutside = (e) => {
            // Dropdown dışına veya button dışına tıklanınca kapat
            if (!e.target.closest('[data-link-or-price-currency-dropdown]') && 
                !linkOrPriceCurrencyDropdownButtonRef.current?.contains(e.target)) {
              setShowLinkOrPriceCurrencyDropdown(false);
            }
          };

          const handleScroll = () => {
            if (linkOrPriceCurrencyDropdownButtonRef.current && showLinkOrPriceCurrencyDropdown) {
              const rect = linkOrPriceCurrencyDropdownButtonRef.current.getBoundingClientRect();
              setLinkOrPriceCurrencyDropdownPosition({
                top: rect.bottom + 4,
                left: rect.left
              });
            }
          };

          // Timeout ile handleClickOutside'ı sonra ekle, böylece onClick handler önce çalışır
          const timeoutId = setTimeout(() => {
            document.addEventListener('click', handleClickOutside);
          }, 0);
          
          window.addEventListener('scroll', handleScroll, true);

          return () => {
            clearTimeout(timeoutId);
            document.removeEventListener('click', handleClickOutside);
            window.removeEventListener('scroll', handleScroll, true);
          };
        }, [showLinkOrPriceCurrencyDropdown]);

        const formatLinkOrPriceNumber = (text, currency) => {
          const isLinkPriceCrypto = ['BTC', 'ETH'].includes(currency);
          const linkPriceDecimals = isLinkPriceCrypto ? 8 : 2;
          
          // Virgülü noktaya çevir
          let cleaned = text.replace(/,/g, '.');
          // Sadece sayı ve nokta karakterine izin ver
          cleaned = cleaned.replace(/[^0-9.]/g, '');
          // Birden fazla nokta varsa sadece ilkini tut
          const parts = cleaned.split('.');
          if (parts.length > 2) {
            cleaned = parts[0] + '.' + parts.slice(1).join('');
          }
          // Ondalık basamak sayısını sınırla
          if (parts.length === 2 && parts[1].length > linkPriceDecimals) {
            cleaned = parts[0] + '.' + parts[1].substring(0, linkPriceDecimals);
          }
          return cleaned;
        };

        const linkOrPriceHasValue = inputMode === 'link' ? linkValue.trim() !== '' : linkOrPriceNumberValue !== '';
        const linkOrPriceIsRequired = required && !linkOrPriceHasValue;
        
        // number-with-currency ile aynı tasarım
        return (
          <View style={{ 
            flexDirection: 'row', 
            alignItems: 'center', 
            width: '100%',
            position: 'relative'
          }}>
            {/* Mod Seçici (Link/Fiyat) - SOLDA */}
            <View style={{
              position: 'absolute',
              left: 8,
              top: '50%',
              transform: 'translateY(-50%)',
              flexDirection: 'row',
              gap: 8,
              zIndex: 10
            }}>
              {/* Link Radio */}
              <TouchableOpacity
                onPress={() => {
                  setInputMode('link');
                  onChange('');
                  if (onFieldChange) onFieldChange(id, '');
                }}
                style={{
                  width: 28,
                  height: 24,
                  borderRadius: 6,
                  backgroundColor: inputMode === 'link' ? 'rgba(40, 167, 69, 0.3)' : 'rgba(30, 40, 50, 0.95)',
                  borderWidth: 1,
                  borderColor: inputMode === 'link' ? '#28a745' : 'rgba(255, 255, 255, 0.2)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  boxShadow: inputMode === 'link' 
                    ? '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(40, 167, 69, 0.3)'
                    : '0 2px 6px rgba(0, 0, 0, 0.2)'
                }}
              >
                <Text style={{ 
                  fontSize: 'clamp(10px, 1.8vw, 14px)'
                }}>
                  🔗
                </Text>
              </TouchableOpacity>

              {/* Fiyat Radio */}
              <TouchableOpacity
                onPress={() => {
                  setInputMode('price');
                  onChange({ amount: '', currency: field.defaultCurrency || 'TL' });
                  if (onFieldChange) onFieldChange(id, { amount: '', currency: field.defaultCurrency || 'TL' });
                }}
                style={{
                  width: 28,
                  height: 24,
                  borderRadius: 6,
                  backgroundColor: inputMode === 'price' ? 'rgba(40, 167, 69, 0.3)' : 'rgba(30, 40, 50, 0.95)',
                  borderWidth: 1,
                  borderColor: inputMode === 'price' ? '#28a745' : 'rgba(255, 255, 255, 0.2)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  cursor: 'pointer',
                  boxShadow: inputMode === 'price' 
                    ? '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(40, 167, 69, 0.3)'
                    : '0 2px 6px rgba(0, 0, 0, 0.2)'
                }}
              >
                <Text style={{ 
                  fontSize: 'clamp(10px, 1.8vw, 14px)'
                }}>
                  💰
                </Text>
              </TouchableOpacity>
            </View>

            {inputMode === 'link' ? (
              // Link Input
              <TextInput
                style={[
                  styles.formInput,
                  hasError && styles.errorBorder,
                  {
                    borderColor: linkValue.trim() !== ''
                      ? 'rgba(40, 167, 69, 0.3)'
                      : 'rgba(220, 53, 69, 0.3)',
                    boxShadow: linkValue.trim() !== ''
                      ? `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)`
                      : `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)`,
                    flex: 1,
                    paddingLeft: 75,
                    paddingTop: 'clamp(14px, 2.5vw, 18px)',
                    paddingBottom: 'clamp(10px, 2vw, 14px)',
                    paddingRight: 'clamp(10px, 2vw, 14px)'
                  }
                ]}
                value={linkValue}
                onChangeText={(text) => {
                  onChange(text);
                  if (onFieldChange) onFieldChange(id, text);
                }}
                placeholder={
                  label.includes('Sahibinden') 
                    ? "örn: https://www.sahibinden.com/ilan/araba-sedan"
                    : "örn: https://www.akakce.com/laptop"
                }
                placeholderTextColor="rgba(255, 255, 255, 0.3)"
                onFocus={() => setIsFocused(true)}
                onBlur={() => setIsFocused(false)}
              />
            ) : (
              // Fiyat Input - Para Birimi Dropdown ile
              <>
                {/* Para Birimi Dropdown - SOLDA (Link/Fiyat seçicinin sağında) - Custom */}
                <div
                  ref={linkOrPriceCurrencyDropdownButtonRef}
                  onMouseDown={(e) => {
                    e.stopPropagation();
                  }}
                  onClick={(e) => {
                    e.stopPropagation();
                    if (!showLinkOrPriceCurrencyDropdown && linkOrPriceCurrencyDropdownButtonRef.current) {
                      const rect = linkOrPriceCurrencyDropdownButtonRef.current.getBoundingClientRect();
                      setLinkOrPriceCurrencyDropdownPosition({
                        top: rect.bottom + 4,
                        left: rect.left
                      });
                    }
                    setShowLinkOrPriceCurrencyDropdown(!showLinkOrPriceCurrencyDropdown);
                  }}
                  style={{
                    position: 'absolute',
                    left: 80,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    width: 90,
                    height: 24,
                    borderRadius: 6,
                    border: '1px solid rgba(40, 167, 69, 0.4)',
                    backgroundColor: 'rgba(30, 40, 50, 0.95)',
                    color: 'rgba(40, 167, 69, 0.95)',
                    fontSize: 'clamp(9px, 1.8vw, 12px)',
                    fontFamily: GLOBAL_FONT_FAMILY,
                    cursor: 'pointer',
                    padding: '0 4px',
                    outline: 'none',
                    boxShadow: '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(40, 167, 69, 0.2)',
                    transition: 'all 0.3s ease',
                    lineHeight: '24px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'space-between',
                    zIndex: 10,
                    boxSizing: 'border-box'
                  }}
                >
                  <span style={{
                    flex: 1,
                    overflow: 'hidden',
                    textOverflow: 'ellipsis',
                    whiteSpace: 'nowrap'
                  }}>
                    {linkOrPriceCurrencyValue}
                  </span>
                  <span style={{
                    fontSize: '8px',
                    color: showLinkOrPriceCurrencyDropdown ? 'rgba(40, 167, 69, 1)' : 'rgba(255, 255, 255, 0.7)',
                    transition: 'transform 0.3s ease',
                    transform: showLinkOrPriceCurrencyDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                    display: 'inline-block',
                    marginLeft: '4px'
                  }}>
                    ▼
                  </span>
                </div>
                
                {/* Link-or-price Currency Dropdown Options */}
                {showLinkOrPriceCurrencyDropdown && createPortal(
                  <div
                    data-link-or-price-currency-dropdown="true"
                    style={{
                      position: 'fixed',
                      top: linkOrPriceCurrencyDropdownPosition.top,
                      left: linkOrPriceCurrencyDropdownPosition.left,
                      width: calculateDynamicDropdownWidth(
                        ['TL', 'USD', 'EUR', 'GBP', 'Gram Altın', 'Gram Gümüş'], 
                        90, 
                        40
                      ),
                      backgroundColor: 'rgba(20, 25, 30, 0.98)',
                      borderRadius: '12px',
                      padding: '6px',
                      boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                      border: '1px solid rgba(0, 123, 255, 0.5)',
                      zIndex: 99999,
                      backdropFilter: 'blur(12px)',
                      maxHeight: '300px',
                      overflowY: 'auto'
                    }}
                  >
                    {[
                      { value: 'TL', label: 'TL' },
                      { value: 'USD', label: 'USD' },
                      { value: 'EUR', label: 'EUR' },
                      { value: 'GBP', label: 'GBP' },
                      { value: 'Gram Altın', label: 'Gram Altın' },
                      { value: 'Gram Gümüş', label: 'Gram Gümüş' }
                    ].map((curr, idx) => {
                      const isActive = linkOrPriceCurrencyValue === curr.value;
                      const isHovered = hoveredLinkOrPriceCurrency === curr.value;
                      
                      return (
                        <div
                          key={idx}
                          data-link-or-price-currency-item="true"
                          style={{
                            padding: '5px 8px',
                            cursor: 'pointer',
                            transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                            borderRadius: '8px',
                            marginBottom: '2px',
                            border: isActive ? '1px solid rgba(40, 167, 69, 0.6)' : (isHovered ? '1px solid rgba(0, 123, 255, 0.3)' : '1px solid transparent'),
                            backgroundColor: isActive ? 'rgba(40, 167, 69, 0.25)' : (isHovered ? 'rgba(0, 123, 255, 0.15)' : 'transparent'),
                            borderLeft: isActive ? '3px solid rgba(40,167,69,1)' : (isHovered ? '3px solid rgba(0,123,255,0.5)' : '3px solid transparent'),
                            paddingLeft: isActive ? '6px' : '8px',
                            boxShadow: isActive ? '0 0 12px rgba(40,167,69,0.4), inset 0 0 8px rgba(40,167,69,0.1)' : (isHovered ? '0 2px 8px rgba(0,123,255,0.2)' : 'none'),
                            fontFamily: GLOBAL_FONT_FAMILY,
                            fontSize: 'clamp(10px, 1.8vw, 13px)',
                            color: isActive ? 'rgba(40, 167, 69, 1)' : 'rgba(255, 255, 255, 0.9)',
                            fontWeight: isActive ? '700' : '400',
                            whiteSpace: 'nowrap',
                            overflow: 'hidden',
                            textOverflow: 'ellipsis',
                            transform: isHovered ? 'translateX(2px)' : 'translateX(0)'
                          }}
                          onMouseEnter={() => setHoveredLinkOrPriceCurrency(curr.value)}
                          onMouseLeave={() => setHoveredLinkOrPriceCurrency(null)}
                          onMouseDown={(e) => {
                            e.preventDefault();
                            e.stopPropagation();
                          }}
                          onClick={(e) => {
                            e.preventDefault();
                            e.stopPropagation();
                            const newCurrency = curr.value;
                            // Önce dropdown'u kapat
                            setShowLinkOrPriceCurrencyDropdown(false);
                            // Sonra değeri güncelle
                            onChange({ amount: linkOrPriceNumberValue, currency: newCurrency });
                            if (onFieldChange) onFieldChange(id, { amount: linkOrPriceNumberValue, currency: newCurrency });
                          }}
                        >
                          {curr.label}
                        </div>
                      );
                    })}
                  </div>,
                  document.body
                )}
                
                {/* Miktar Input */}
                <TextInput
                  style={[
                    styles.formInput,
                    hasError && styles.errorBorder,
                    {
                      borderColor: linkOrPriceNumberValue !== ''
                        ? 'rgba(40, 167, 69, 0.3)'
                        : 'rgba(220, 53, 69, 0.3)',
                      boxShadow: linkOrPriceNumberValue !== ''
                        ? `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)`
                        : `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)`,
                      flex: 1,
                      paddingLeft: 180,
                      paddingTop: 'clamp(14px, 2.5vw, 18px)',
                      paddingBottom: 'clamp(10px, 2vw, 14px)',
                      paddingRight: 'clamp(10px, 2vw, 14px)'
                    }
                  ]}
                  value={linkOrPriceNumberValue}
                  onChangeText={(text) => {
                    const formatted = formatLinkOrPriceNumber(text, linkOrPriceCurrencyValue);
                    onChange({ amount: formatted, currency: linkOrPriceCurrencyValue });
                    if (onFieldChange) onFieldChange(id, { amount: formatted, currency: linkOrPriceCurrencyValue });
                  }}
                  placeholder="örn: 1500.00"
                  placeholderTextColor="rgba(255, 255, 255, 0.3)"
                  keyboardType="numeric"
                  onFocus={() => setIsFocused(true)}
                  onBlur={() => setIsFocused(false)}
                />
              </>
            )}
            
            {/* Floating Label - Her zaman yukarıda */}
            <Text style={[
              styles.formLabelFloating,
              {
                color: 'rgba(0, 123, 255, 0.8)',
                fontSize: 'clamp(9px, 1.8vw, 12px)',
              }
            ]}>
              {label}
            </Text>
          </View>
        );

      case 'number-with-currency':
        // Miktar ve para birimi için composite input
        const numberValue = typeof value === 'object' ? (value?.amount || '') : (value || '');
        const currencyValue = typeof value === 'object' ? (value?.currency || field.defaultCurrency || 'TL') : (field.defaultCurrency || 'TL');
        
        // Para birimi her zaman seçili sayılır (default TL bile seçilmiş kabul edilir)
        const isCurrencySelected = true;
        
        // Para birimine göre decimal basamak sayısı ve placeholder
        const isCrypto = ['BTC', 'ETH'].includes(currencyValue);
        const decimals = isCrypto ? 8 : 2;
        const placeholderExample = isCrypto ? '0.00000001' : '1.78';
        
        // Input değerini formatla
        const formatNumber = (val) => {
          if (!val) return '';
          // Virgülü noktaya çevir
          let formatted = val.replace(/,/g, '.');
          // Sadece sayı ve nokta karakterine izin ver
          formatted = formatted.replace(/[^0-9.]/g, '');
          // Birden fazla nokta varsa sadece ilkini tut
          const parts = formatted.split('.');
          if (parts.length > 2) {
            formatted = parts[0] + '.' + parts.slice(1).join('');
          }
          // Ondalık basamak sayısını sınırla
          if (parts.length === 2 && parts[1].length > decimals) {
            formatted = parts[0] + '.' + parts[1].substring(0, decimals);
          }
          return formatted;
        };
        
        // Checkbox sağda mı ortalanacak mı hesapla
        const hasCheckbox = field.hasUncertainCheckbox;
        const checkboxWidth = hasCheckbox ? 180 : 0;
        
        return (
          <View style={{ 
            flexDirection: 'row', 
            alignItems: 'center', 
            width: '100%',
            position: 'relative'
          }}>
            {/* Floating Label - Her zaman yukarıda */}
            <Text style={[
              styles.formLabelFloating,
              {
                color: 'rgba(0, 123, 255, 0.8)',
                fontSize: 'clamp(9px, 1.8vw, 12px)',
              }
            ]}>
              {label}
            </Text>
            
            {/* Para Birimi Custom Dropdown - SOLDA */}
            <div
              ref={currencyDropdownButtonRef}
              style={{
                position: 'absolute',
                left: 8,
                top: '50%',
                transform: 'translateY(-50%)',
                width: 90,
                height: 24,
                borderRadius: 6,
                border: isCurrencySelected 
                  ? '1px solid rgba(40, 167, 69, 0.4)' 
                  : '1px solid rgba(0, 123, 255, 0.4)',
                backgroundColor: 'rgba(30, 40, 50, 0.95)',
                color: isCurrencySelected ? 'rgba(40, 167, 69, 0.95)' : '#fff',
                fontSize: 'clamp(9px, 1.8vw, 12px)',
                fontFamily: GLOBAL_FONT_FAMILY,
                cursor: 'pointer',
                outline: 'none',
                boxShadow: isCurrencySelected
                  ? '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(40, 167, 69, 0.2)'
                  : '0 4px 12px rgba(0, 0, 0, 0.3), 0 0 8px rgba(0, 123, 255, 0.2)',
                transition: 'all 0.3s ease',
                lineHeight: '24px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between',
                padding: '0 4px',
                zIndex: 10,
                boxSizing: 'border-box'
              }}
              onClick={(e) => {
                e.stopPropagation();
                if (!showCurrencyDropdown && currencyDropdownButtonRef.current) {
                  const rect = currencyDropdownButtonRef.current.getBoundingClientRect();
                  setCurrencyDropdownPosition({
                    top: rect.bottom + 4,
                    left: rect.left
                  });
                }
                setShowCurrencyDropdown(!showCurrencyDropdown);
                // İlk focus'da currency'yi de set et
                if (typeof value !== 'object' || !value?.currency) {
                  onChange({ amount: numberValue, currency: currencyValue });
                }
              }}
            >
              <span style={{ flex: 1, textAlign: 'center' }}>
                {currencyValue}
              </span>
              <span style={{ 
                fontSize: '8px',
                color: showCurrencyDropdown ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.7)',
                transition: 'transform 0.3s ease',
                transform: showCurrencyDropdown ? 'rotate(180deg)' : 'rotate(0deg)',
                display: 'inline-block'
              }}>
                ▼
              </span>
            </div>
            
            {/* Para Birimi Dropdown Options */}
            {showCurrencyDropdown && createPortal(
              <div
                data-currency-dropdown="true"
                style={{
                  position: 'fixed',
                  top: currencyDropdownPosition.top,
                  left: currencyDropdownPosition.left,
                  width: calculateDynamicDropdownWidth(
                    ['TL', 'USD', 'EUR', 'GBP', 'Gram Altın', 'Gram Gümüş', 'BTC', 'ETH'], 
                    90, 
                    40
                  ),
                  backgroundColor: 'rgba(20, 25, 30, 0.98)',
                  borderRadius: '12px',
                  padding: '6px',
                  boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                  border: '1px solid rgba(0, 123, 255, 0.5)',
                  zIndex: 99999,
                  backdropFilter: 'blur(12px)',
                  maxHeight: '300px',
                  overflowY: 'auto'
                }}
              >
                {['TL', 'USD', 'EUR', 'GBP', 'Gram Altın', 'Gram Gümüş', 'BTC', 'ETH'].map((currency, index) => {
                  const isActive = currencyValue === currency;
                  
                  return (
                    <div
                      key={index}
                      style={{
                        padding: '5px 8px',
                        cursor: 'pointer',
                        transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                        borderRadius: '8px',
                        marginBottom: '2px',
                        border: isActive ? '1px solid rgba(0, 123, 255, 0.6)' : '1px solid transparent',
                        backgroundColor: isActive ? 'rgba(0, 123, 255, 0.25)' : 'transparent',
                        borderLeft: isActive ? '3px solid rgba(0,123,255,1)' : '3px solid transparent',
                        paddingLeft: isActive ? '6px' : '8px',
                        boxShadow: isActive ? '0 0 12px rgba(0,123,255,0.4), inset 0 0 8px rgba(0,123,255,0.1)' : 'none',
                        fontFamily: GLOBAL_FONT_FAMILY,
                        fontSize: 'clamp(9px, 1.8vw, 12px)',
                        color: isActive ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.9)',
                        fontWeight: isActive ? '700' : '400',
                        textAlign: 'center',
                        whiteSpace: 'nowrap'
                      }}
                      onMouseEnter={(e) => {
                        if (!isActive) {
                          e.currentTarget.style.backgroundColor = 'rgba(0, 123, 255, 0.15)';
                          e.currentTarget.style.border = '1px solid rgba(0, 123, 255, 0.3)';
                          e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,123,255,0.2)';
                        }
                        e.currentTarget.style.transform = 'translateX(2px)';
                      }}
                      onMouseLeave={(e) => {
                        if (!isActive) {
                          e.currentTarget.style.backgroundColor = 'transparent';
                          e.currentTarget.style.border = '1px solid transparent';
                          e.currentTarget.style.boxShadow = 'none';
                        }
                        e.currentTarget.style.transform = 'translateX(0)';
                      }}
                      onClick={(e) => {
                        e.stopPropagation();
                        const newCurrency = currency;
                        const newIsCrypto = ['BTC', 'ETH'].includes(newCurrency);
                        const newDecimals = newIsCrypto ? 8 : 2;
                        
                        // Mevcut değeri yeni decimal kuralına göre formatla
                        let newAmount = numberValue;
                        if (newAmount) {
                          const parts = newAmount.toString().split('.');
                          if (parts.length === 2 && parts[1].length > newDecimals) {
                            newAmount = parts[0] + '.' + parts[1].substring(0, newDecimals);
                          }
                        }
                        
                        // State'i güncelle
                        const newValue = { amount: newAmount || '', currency: newCurrency };
                        onChange(newValue);
                        setShowCurrencyDropdown(false);
                      }}
                    >
                      {currency}
                    </div>
                  );
                })}
              </div>,
              document.body
            )}
            
            {/* Miktar Input - ORTADA */}
            <TextInput
              style={[
                styles.formInput,
                hasError && styles.errorBorder,
                {
                  // Miktar girilmiş mi kontrol et (checkbox durumuna bakma)
                  borderColor: (numberValue && numberValue.toString().trim() !== '')
                    ? 'rgba(40, 167, 69, 0.3)'  // Miktar var → Yeşil
                    : 'rgba(220, 53, 69, 0.3)', // Miktar yok → Kırmızı
                  boxShadow: (numberValue && numberValue.toString().trim() !== '')
                    ? `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)`
                    : `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)`,
                  flex: 1,
                  paddingLeft: 105,
                  paddingRight: hasCheckbox ? checkboxWidth + 10 : 10,
                  paddingTop: 'clamp(14px, 2.5vw, 18px)',
                  color: numberValue && numberValue.toString().trim() !== '' 
                    ? 'rgba(40, 167, 69, 0.95)' 
                    : 'rgba(255, 255, 255, 0.9)'
                }
              ]}
              value={numberValue?.toString() || ''}
              placeholder={`Örn: ${placeholderExample}`}
              placeholderTextColor="rgba(255, 255, 255, 0.4)"
              onChangeText={(val) => {
                const formattedVal = formatNumber(val);
                onChange({ amount: formattedVal, currency: currencyValue });
              }}
              onFocus={() => {
                setIsFocused(true);
                if (typeof value !== 'object' || !value?.currency) {
                  onChange({ amount: numberValue, currency: currencyValue });
                }
              }}
              onBlur={() => setIsFocused(false)}
              onKeyPress={(e) => {
                if (e.nativeEvent.key === 'Enter') {
                  e.target.blur();
                }
              }}
              keyboardType="decimal-pad"
            />
            
            {/* Miktar Belirsiz Checkbox - SAĞDA */}
            {field.hasUncertainCheckbox && (
              <View style={{ 
                position: 'absolute', 
                right: 8, 
                top: '50%',
                transform: 'translateY(-50%)',
                flexDirection: 'row', 
                alignItems: 'center',
                gap: 6,
                zIndex: 5
              }}>
                <TouchableOpacity
                  onPress={() => {
                    if (setFormData) {
                      const currentValue = formData?.[field.uncertainCheckboxId] || false;
                      setFormData(prev => ({ 
                        ...prev, 
                        [field.uncertainCheckboxId]: !currentValue
                      }));
                    }
                  }}
                  style={{
                    flexDirection: 'row',
                    alignItems: 'center',
                    gap: 6
                  }}
                >
                  <View
                    style={{
                      width: 16,
                      height: 16,
                      borderRadius: 4,
                      backgroundColor: formData?.[field.uncertainCheckboxId] 
                        ? '#28a745' 
                        : 'transparent',
                      borderWidth: 1,
                      borderColor: formData?.[field.uncertainCheckboxId] 
                        ? '#28a745' 
                        : 'rgba(255, 255, 255, 0.5)',
                      justifyContent: 'center',
                      alignItems: 'center',
                      transition: 'all 0.3s ease',
                      display: 'flex'
                    }}
                  >
                    {formData?.[field.uncertainCheckboxId] && (
                      <Text style={{ color: '#fff', fontSize: 11, lineHeight: 16, fontWeight: 'bold' }}>✓</Text>
                    )}
                  </View>
                  <Text style={{ 
                    color: 'rgba(255, 255, 255, 0.6)', 
                    fontSize: 'clamp(8px, 1.5vw, 10px)',
                    fontFamily: '"Kalam", "Comic Sans MS", cursive, sans-serif',
                    whiteSpace: 'nowrap'
                  }}>
                    {field.uncertainCheckboxLabel}
                  </Text>
                </TouchableOpacity>
              </View>
            )}
          </View>
        );

      default:
        // Number tipi için HTML input kullan (web için daha iyi)
        if (type === 'number') {
          return (
            <input
              type="text"
              inputMode="decimal"
              style={{
                ...styles.formInput,
                borderColor: isRequired ? 'rgba(220, 53, 69, 0.3)' : 'rgba(40, 167, 69, 0.3)',
                boxShadow: isRequired 
                  ? 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)'
                  : 'inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)',
                color: hasValue ? 'rgba(40, 167, 69, 0.95)' : 'rgba(255, 255, 255, 0.9)',
                fontFamily: GLOBAL_FONT_FAMILY,
                outline: 'none'
              }}
              value={value?.toString() || ''}
              onChange={(e) => {
                const val = e.target.value;
                // Virgülü noktaya çevir ve sadece sayı + nokta kabul et
                const normalized = val.replace(/,/g, '.').replace(/[^0-9.]/g, '');
                // Birden fazla nokta varsa sadece ilkini tut
                const parts = normalized.split('.');
                const finalValue = parts.length > 1 
                  ? parts[0] + '.' + parts.slice(1).join('')
                  : normalized;
                onChange(finalValue);
              }}
              onFocus={() => setIsFocused(true)}
              onBlur={() => setIsFocused(false)}
              onKeyPress={(e) => {
                if (e.key === 'Enter') {
                  e.target.blur();
                }
              }}
            />
          );
        }
        
        return (
          <TextInput
            style={[
              styles.formInput,
              hasError && styles.errorBorder,
              {
                borderColor: isRequired ? 'rgba(220, 53, 69, 0.3)' : 'rgba(40, 167, 69, 0.3)',
                boxShadow: isRequired 
                  ? `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(220,53,69,0.2), 0 0 12px rgba(220,53,69,0.15)`
                  : `inset 0 2px 4px rgba(0,0,0,0.1), 0 2px 8px rgba(40,167,69,0.2), 0 0 12px rgba(40,167,69,0.15)`,
                color: hasValue ? 'rgba(40, 167, 69, 0.95)' : 'rgba(255, 255, 255, 0.9)'
              }
            ]}
            value={value?.toString() || ''}
            onChangeText={onChange}
            onFocus={() => setIsFocused(true)}
            onBlur={() => setIsFocused(false)}
            onKeyPress={(e) => {
              if (e.nativeEvent.key === 'Enter') {
                e.target.blur();
              }
            }}
            keyboardType='default'
          />
        );
    }
  };

  return (
    <View style={{ marginBottom: 10 }}>
      {type !== 'checkbox' && type !== 'checkbox-with-installment' && type !== 'checkbox-with-select' && type !== 'checkbox-with-date' && type !== 'link-or-price' && type !== 'number-with-currency' ? (
        <View style={styles.formFloatingContainer}>
          <Text style={isFloating ? styles.formLabelFloating : styles.formLabel}>
            {label}
          </Text>
          {renderInput()}
        </View>
      ) : (
        renderInput()
      )}
    </View>
  );
};

export default FormField;
