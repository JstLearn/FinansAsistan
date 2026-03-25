// front/components/Tables/DataTable.js
import React, { useState, useEffect, useRef } from 'react';
import { View, Text, ScrollView, TextInput, TouchableOpacity } from 'react-native';
import { createPortal } from 'react-dom';
import styles, { GLOBAL_FONT_FAMILY } from '../../styles/styles';
import { updateData, deleteData } from '../../services/api';
import { useUser } from '../../context/UserContext';

const DataTable = ({ data = [], title, endpoint = '', onUpdate = null }) => {
  const { user } = useUser();
  const [filters, setFilters] = useState({});
  const [filteredData, setFilteredData] = useState([]);
  const [error, setError] = useState(null);
  const [currentPage, setCurrentPage] = useState(1);
  const [rowsPerPage, setRowsPerPage] = useState(10);
  const rowsPerPageOptions = [5, 10, 20, 50, 100, 'Hepsi'];
  const [visibleColumns, setVisibleColumns] = useState({});
  const [showColumnSelector, setShowColumnSelector] = useState(false);
  const [columnOrder, setColumnOrder] = useState([]);
  const [draggedColumn, setDraggedColumn] = useState(null);
  const [dropdownPosition, setDropdownPosition] = useState({ top: 0, left: 0 });
  const columnSelectorRef = useRef(null);
  const [dropdownRoot, setDropdownRoot] = useState(null);
  const [activeFilterDropdown, setActiveFilterDropdown] = useState(null);
  const [hoveredRow, setHoveredRow] = useState(null);
  const [pressedRow, setPressedRow] = useState(null);
  const [hoveredButton, setHoveredButton] = useState(null);
  const [pressedButton, setPressedButton] = useState(null);
  const [hoveredColumnSelector, setHoveredColumnSelector] = useState(false);
  const [pressedColumnSelector, setPressedColumnSelector] = useState(false);
  const [hoveredRowsPerPage, setHoveredRowsPerPage] = useState(null);
  const [pressedRowsPerPage, setPressedRowsPerPage] = useState(null);
  const [hoveredFilterOperator, setHoveredFilterOperator] = useState(null);
  const [pressedFilterOperator, setPressedFilterOperator] = useState(null);
  const filterOperatorRefs = useRef({});
  const [activeTooltip, setActiveTooltip] = useState(null);
  const [sortColumn, setSortColumn] = useState(null);
  const [sortDirection, setSortDirection] = useState('asc'); // 'asc' | 'desc'
  const [columnWidths, setColumnWidths] = useState({});
  const [editingRowId, setEditingRowId] = useState(null);
  const [editingData, setEditingData] = useState({});
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
  const [deleteRowId, setDeleteRowId] = useState(null);
  const [showFieldConflictModal, setShowFieldConflictModal] = useState(false);
  const [fieldConflictData, setFieldConflictData] = useState(null);
  
  // Edit mode dropdown states
  const [showEditDropdown, setShowEditDropdown] = useState(null); // {rowId, columnId}
  const [editDropdownPosition, setEditDropdownPosition] = useState({ top: 0, left: 0 });
  const editDropdownButtonRef = useRef({});

  // Dropdown seçenekleri tanımlamaları
  const dropdownOptions = {
    // Varlıklar için kategori
    kategori: endpoint === 'varlik' ? [
      { value: 'KRİPTO PARA', label: 'KRİPTO PARA' },
      { value: 'HİSSE SENEDİ', label: 'HİSSE SENEDİ' },
      { value: 'TL', label: 'TL' },
      { value: 'USD', label: 'USD' },
      { value: 'EUR', label: 'EUR' },
      { value: 'GBP', label: 'GBP' },
      { value: 'Gram Altın', label: 'Gram Altın' },
      { value: 'Gram Gümüş', label: 'Gram Gümüş' },
      { value: 'BTC', label: 'BTC' },
      { value: 'ETH', label: 'ETH' },
      { value: 'BONO-TAHVİL', label: 'BONO-TAHVİL' },
      { value: 'EMLAK', label: 'EMLAK' },
      { value: 'VASITA', label: 'VASITA' },
      { value: 'DİĞER', label: 'DİĞER' }
    ] : endpoint === 'istek' ? [
      { value: 'HARCAMA PLANI', label: 'HARCAMA PLANI' },
      { value: 'EMLAK', label: 'EMLAK' },
      { value: 'VASITA', label: 'VASITA' }
    ] : [],
    
    // Para birimi (hem harcama_borc/gelirler hem de varliklar için)
    para_birimi: [
      { value: 'TL', label: 'TL' },
      { value: 'USD', label: 'USD' },
      { value: 'EUR', label: 'EUR' },
      { value: 'GBP', label: 'GBP' },
      { value: 'Gram Altın', label: 'Gram Altın' },
      { value: 'Gram Gümüş', label: 'Gram Gümüş' },
      { value: 'BTC', label: 'BTC' },
      { value: 'ETH', label: 'ETH' }
    ],
    
    // Alış para birimi (varliklar için)
    alis_para_birimi: [
      { value: 'TL', label: 'TL' },
      { value: 'USD', label: 'USD' },
      { value: 'EUR', label: 'EUR' },
      { value: 'GBP', label: 'GBP' },
      { value: 'Gram Altın', label: 'Gram Altın' },
      { value: 'Gram Gümüş', label: 'Gram Gümüş' },
      { value: 'BTC', label: 'BTC' },
      { value: 'ETH', label: 'ETH' }
    ],
    
    // Varlık (tüm kategoriler için - PARA, KRİPTO, HİSSE, BONO)
    varlik: [
      // PARA
      { value: 'TL', label: 'TL' },
      { value: 'USD', label: 'USD' },
      { value: 'EUR', label: 'EUR' },
      { value: 'GBP', label: 'GBP' },
      { value: 'Gram Altın', label: 'Gram Altın' },
      { value: 'Gram Gümüş', label: 'Gram Gümüş' },
      // KRİPTO PARA
      { value: 'BTC', label: 'BTC' },
      { value: 'ETH', label: 'ETH' },
      { value: 'BNB', label: 'BNB' },
      { value: 'SOL', label: 'SOL' },
      { value: 'XRP', label: 'XRP' },
      // HİSSE SENEDİ
      { value: 'AAPL', label: 'AAPL' },
      { value: 'GOOGL', label: 'GOOGL' },
      { value: 'MSFT', label: 'MSFT' },
      { value: 'TSLA', label: 'TSLA' },
      { value: 'AMZN', label: 'AMZN' },
      // BONO-TAHVİL
      { value: 'ABD 10Y', label: 'ABD 10Y' },
      { value: 'EUR 10Y', label: 'EUR 10Y' },
      { value: 'TÜRKİYE 10Y', label: 'TÜRKİYE 10Y' },
      { value: 'JGB 10Y', label: 'JGB 10Y' },
      { value: 'UK 10Y', label: 'UK 10Y' }
    ],
    
    // Öncelik
    oncelik: [
      { value: 'İstek', label: 'İstek' },
      { value: 'İhtiyaç', label: 'İhtiyaç' }
    ],
    
    // Boolean alanlar
    odendi_mi: [
      { value: '1', label: 'Evet' },
      { value: '0', label: 'Hayır' }
    ],
    alindi_mi: [
      { value: '1', label: 'Evet' },
      { value: '0', label: 'Hayır' }
    ],
    talimat_varmi: [
      { value: '1', label: 'Evet' },
      { value: '0', label: 'Hayır' }
    ],
    faiz_uygulaniyormu: [
      { value: '1', label: 'Evet' },
      { value: '0', label: 'Hayır' }
    ],
    miktar_belirsiz: [
      { value: '1', label: 'Evet' },
      { value: '0', label: 'Hayır' }
    ]
  };

  // Filtre operatörleri
  const filterOperators = {
    text: [
      { id: 'contains', label: 'İçerir' },
      { id: 'notContains', label: 'İçermez' },
      { id: 'equals', label: 'Eşittir' },
      { id: 'notEquals', label: 'Eşit Değildir' },
      { id: 'startsWith', label: 'İle Başlar' },
      { id: 'endsWith', label: 'İle Biter' },
      { id: 'empty', label: 'Boş' },
      { id: 'notEmpty', label: 'Boş Değil' }
    ],
    number: [
      { id: 'equals', label: 'Eşittir' },
      { id: 'notEquals', label: 'Eşit Değildir' },
      { id: 'greaterThan', label: 'Büyüktür' },
      { id: 'lessThan', label: 'Küçüktür' },
      { id: 'greaterThanOrEqual', label: 'Büyük Eşittir' },
      { id: 'lessThanOrEqual', label: 'Küçük Eşittir' },
      { id: 'between', label: 'Arasında' },
      { id: 'empty', label: 'Boş' },
      { id: 'notEmpty', label: 'Boş Değil' }
    ],
    date: [
      { id: 'equals', label: 'Eşittir' },
      { id: 'notEquals', label: 'Eşit Değildir' },
      { id: 'before', label: 'Önce' },
      { id: 'after', label: 'Sonra' },
      { id: 'between', label: 'Arasında' },
      { id: 'empty', label: 'Boş' },
      { id: 'notEmpty', label: 'Boş Değil' }
    ],
    boolean: [
      { id: 'equals', label: 'Eşittir' },
      { id: 'notEquals', label: 'Eşit Değildir' },
      { id: 'empty', label: 'Boş' },
      { id: 'notEmpty', label: 'Boş Değil' }
    ]
  };

  // Filtre değişikliklerini işle
  const handleFilterChange = (header, value, operator = null) => {
    setFilters(prev => ({
      ...prev,
      [header]: {
        value,
        operator: operator || prev[header]?.operator || getDefaultOperator(getColumnType(header))
      }
    }));
  };

  // Filtre operatörünü değiştir
  const handleFilterOperatorChange = (header, operator) => {
    setFilters(prev => {
      const previousValue = prev[header]?.value || '';
      
      // "Boş" veya "Boş Değil" operatörleri için otomatik değer ata
      let newValue;
      if (operator === 'empty' || operator === 'notEmpty') {
        newValue = 'auto';
      } else {
        // Eğer önceki değer "auto" ise (Boş/Boş Değil'den geliyorsa), temizle
        newValue = previousValue === 'auto' ? '' : previousValue;
      }
      
      return {
        ...prev,
        [header]: {
          value: newValue,
          operator
        }
      };
    });
  };

  // Varsayılan operatörü al
  const getDefaultOperator = (columnType) => {
    switch (columnType) {
      case 'text': return 'contains';
      case 'number': return 'equals';
      case 'date': return 'equals';
      case 'boolean': return 'equals';
      default: return 'contains';
    }
  };

  // Filtreleme işlevi
  const applyFilters = () => {
    let result = [...data];
    
    Object.keys(filters).forEach(header => {
      const filter = filters[header];
      const operator = filter?.operator || getDefaultOperator(getColumnType(header));
      
      // "Boş" veya "Boş Değil" operatörleri için value kontrolü yapma
      if (!filter || (!filter.value && operator !== 'empty' && operator !== 'notEmpty')) return;

      const columnType = getColumnType(header);
      
      result = result.filter(item => {
        const cellValue = item[header];
        const filterValue = filter.value;
        const operator = filter.operator || getDefaultOperator(columnType);
        
        // "Boş" ve "Boş Değil" operatörleri için özel kontrol
        if (operator === 'empty') {
          return cellValue === null || cellValue === undefined || cellValue === '' || String(cellValue).trim().length === 0;
        }
        if (operator === 'notEmpty') {
          return cellValue !== null && cellValue !== undefined && cellValue !== '' && String(cellValue).trim().length > 0;
        }

        switch (columnType) {
          case 'number':
            const numValue = Number(cellValue);
            const numFilterValue = Number(filterValue);
            
            if (operator === 'between') {
              const [min, max] = filterValue.split('-').map(Number);
              if (isNaN(min) || isNaN(max)) return true;
              return numValue >= min && numValue <= max;
            }
            
            if (isNaN(numValue) || isNaN(numFilterValue)) return true;
            
            switch (operator) {
              case 'equals': return numValue === numFilterValue;
              case 'notEquals': return numValue !== numFilterValue;
              case 'greaterThan': return numValue > numFilterValue;
              case 'lessThan': return numValue < numFilterValue;
              case 'greaterThanOrEqual': return numValue >= numFilterValue;
              case 'lessThanOrEqual': return numValue <= numFilterValue;
              default: return true;
            }
          
          case 'boolean':
            const boolValue = String(cellValue).toLowerCase();
            const boolFilterValue = String(filterValue).toLowerCase();
            
            switch (operator) {
              case 'equals': return boolValue === boolFilterValue;
              case 'notEquals': return boolValue !== boolFilterValue;
              default: return true;
            }

          case 'date':
            try {
              const dateValue = new Date(cellValue);
              if (isNaN(dateValue.getTime())) return false;

              if (operator === 'between') {
                const [startStr, endStr] = filterValue.split(',');
                const startDate = new Date(startStr);
                const endDate = new Date(endStr);
                
                if (isNaN(startDate.getTime()) || isNaN(endDate.getTime())) return true;
                
                // Tarih aralığı karşılaştırması için saat bilgisini sıfırla
                dateValue.setHours(0, 0, 0, 0);
                startDate.setHours(0, 0, 0, 0);
                endDate.setHours(23, 59, 59, 999);
                
                return dateValue >= startDate && dateValue <= endDate;
              }

              const filterDate = new Date(filterValue);
              if (isNaN(filterDate.getTime())) return true;

              // Tarih karşılaştırması için saat bilgisini sıfırla
              dateValue.setHours(0, 0, 0, 0);
              filterDate.setHours(0, 0, 0, 0);

              switch (operator) {
                case 'equals': return dateValue.getTime() === filterDate.getTime();
                case 'notEquals': return dateValue.getTime() !== filterDate.getTime();
                case 'before': return dateValue < filterDate;
                case 'after': return dateValue > filterDate;
                default: return true;
              }
            } catch (error) {
              console.error('Tarih filtreleme hatası:', error);
              return true;
            }
          
          default: // text
            const strValue = String(cellValue).toLowerCase();
            const strFilterValue = String(filterValue).toLowerCase();
            
            switch (operator) {
              case 'contains': return strValue.includes(strFilterValue);
              case 'notContains': return !strValue.includes(strFilterValue);
              case 'equals': return strValue === strFilterValue;
              case 'notEquals': return strValue !== strFilterValue;
              case 'startsWith': return strValue.startsWith(strFilterValue);
              case 'endsWith': return strValue.endsWith(strFilterValue);
              default: return true;
            }
        }
      });
    });

    // Sıralama uygula
    if (sortColumn) {
      result.sort((a, b) => {
        const aValue = a[sortColumn];
        const bValue = b[sortColumn];
        const columnType = getColumnType(sortColumn);
        
        // Null/undefined kontrolü
        if (aValue === null || aValue === undefined) return 1;
        if (bValue === null || bValue === undefined) return -1;
        
        let comparison = 0;
        
        switch (columnType) {
          case 'number':
            comparison = Number(aValue) - Number(bValue);
            break;
          case 'date':
            comparison = new Date(aValue).getTime() - new Date(bValue).getTime();
            break;
          case 'boolean':
            const aBool = String(aValue).toLowerCase() === 'true';
            const bBool = String(bValue).toLowerCase() === 'true';
            comparison = aBool === bBool ? 0 : (aBool ? 1 : -1);
            break;
          default: // text
            comparison = String(aValue).toLowerCase().localeCompare(String(bValue).toLowerCase(), 'tr');
            break;
        }
        
        return sortDirection === 'asc' ? comparison : -comparison;
      });
    }

    setFilteredData(result);
  };

  // Filtre bileşenini oluştur
  const renderFilter = (header) => {
    const columnType = getColumnType(header);
    const filter = filters[header] || {};
    const filterValue = filter.value || '';
    const operator = filter.operator || getDefaultOperator(columnType);
    const operators = filterOperators[columnType] || [];
    
    // Dropdown genişliğini en uzun label'a göre hesapla
    const calculateFilterDropdownWidth = () => {
      if (operators.length === 0) return 150;
      
      let maxWidth = 0;
      operators.forEach(op => {
        let charWidth = 0;
        for (let i = 0; i < op.label.length; i++) {
          const char = op.label[i];
          if (/[A-ZÇĞİÖŞÜ]/.test(char)) {
            charWidth += 12;
          } else if (/[a-zçğıöşü]/.test(char)) {
            charWidth += 9;
          } else if (/[0-9]/.test(char)) {
            charWidth += 10;
          } else if (char === ' ') {
            charWidth += 6;
          } else {
            charWidth += 8;
          }
        }
        
        if (charWidth > maxWidth) {
          maxWidth = charWidth;
        }
      });
      
      // Padding + border + left indicator
      return Math.max(maxWidth + 40, 150);
    };

    // Filter operator butonu için hover/pressed efektleri
    const filterOperatorDynamicStyle = pressedFilterOperator === header ? {
      transform: [{ translateY: 0 }, { scale: 0.98 }],
      filter: 'brightness(1.25)',
      boxShadow: '0 2px 8px rgba(0,123,255,0.4), inset 0 1px 3px rgba(0,0,0,0.2)',
      transition: 'all 0.1s ease',
    } : hoveredFilterOperator === header ? {
      transform: [{ translateY: -2 }],
      filter: 'brightness(1.15)',
      boxShadow: '0 4px 12px rgba(0,123,255,0.3), 0 2px 6px rgba(0,0,0,0.2)',
      transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
    } : {
      transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
    };

    return (
      <View style={styles.filterContainer}>
        <View style={styles.filterOperatorContainer}>
          <div
            ref={(el) => filterOperatorRefs.current[header] = el}
            style={{ width: '100%' }}
          >
          <TouchableOpacity
              style={[styles.filterOperatorButton, filterOperatorDynamicStyle]}
            onPress={() => {
              if (activeFilterDropdown === header) {
                setActiveFilterDropdown(null);
              } else {
                  // Butonun pozisyonunu hesapla
                  const buttonElement = filterOperatorRefs.current[header];
                  if (buttonElement) {
                    const rect = buttonElement.getBoundingClientRect();
                    const columnType = getColumnType(header);
                    const operators = filterOperators[columnType] || [];
                    
                    // Dropdown yüksekliğini tahmin et (her item ~35px + padding)
                    const estimatedDropdownHeight = (operators.length * 35) + 20;
                    const viewportHeight = window.innerHeight;
                    const spaceBelow = viewportHeight - rect.bottom;
                    const spaceAbove = rect.top;
                    
                    // Eğer aşağıda yeterli yer yoksa ve yukarıda daha fazla yer varsa, yukarı aç
                    let top = rect.bottom + 4;
                    if (spaceBelow < estimatedDropdownHeight && spaceAbove > spaceBelow) {
                      top = rect.top - estimatedDropdownHeight - 4;
                    }
                    
                    setDropdownPosition({
                      top: top,
                      left: rect.left,
                    });
                  }
                setActiveFilterDropdown(header);
                // Diğer açık dropdownları kapat
                if (showColumnSelector) setShowColumnSelector(false);
              }
            }}
              onPressIn={() => setPressedFilterOperator(header)}
              onPressOut={() => setPressedFilterOperator(null)}
              onMouseEnter={() => setHoveredFilterOperator(header)}
              onMouseLeave={() => setHoveredFilterOperator(null)}
          >
            <Text style={styles.filterOperatorText}>
              {operators.find(op => op.id === operator)?.label || 'Filtrele'}
            </Text>
          </TouchableOpacity>
          </div>
          {activeFilterDropdown === header && createPortal(
            <div 
              style={{
                position: 'fixed',
                top: dropdownPosition.top,
                left: dropdownPosition.left,
                width: calculateFilterDropdownWidth(),
                backgroundColor: 'rgba(20, 25, 30, 0.98)',
                borderRadius: '12px',
                padding: '6px',
                boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                border: '1px solid rgba(0, 123, 255, 0.5)',
                zIndex: 99999,
                backdropFilter: 'blur(12px)',
                pointerEvents: 'auto',
              }}
              onClick={(e) => e.stopPropagation()}
            >
              {operators.map(op => {
                const isActive = operator === op.id;
                return (
                  <div
                  key={op.id}
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
                      fontWeight: isActive ? '700' : '400',
                      pointerEvents: 'auto',
                      userSelect: 'none',
                    }}
                    onMouseDown={(e) => {
                      e.preventDefault();
                      e.stopPropagation();
                    handleFilterOperatorChange(header, op.id);
                      setTimeout(() => {
                    setActiveFilterDropdown(null);
                      }, 50);
                    }}
                    onMouseEnter={(e) => {
                      if (!isActive) {
                        e.currentTarget.style.backgroundColor = 'rgba(0, 123, 255, 0.15)';
                        e.currentTarget.style.border = '1px solid rgba(0, 123, 255, 0.3)';
                        e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,123,255,0.2)';
                      }
                      e.currentTarget.style.transform = 'translateX(4px)';
                    }}
                    onMouseLeave={(e) => {
                      if (!isActive) {
                        e.currentTarget.style.backgroundColor = 'transparent';
                        e.currentTarget.style.border = '1px solid transparent';
                        e.currentTarget.style.boxShadow = 'none';
                      }
                      e.currentTarget.style.transform = 'translateX(0)';
                    }}
                  >
                    {op.label}
                  </div>
                );
              })}
            </div>,
            document.body
          )}
        </View>

        {/* "Boş" veya "Boş Değil" operatörleri için input alanı gösterme */}
        {(operator === 'empty' || operator === 'notEmpty') ? null : (
        columnType === 'boolean' ? (
          <TouchableOpacity
            style={styles.filterSelect}
            onPress={() => {
              const values = ['', 'true', 'false'];
              const currentIndex = values.indexOf(filterValue);
              const nextValue = values[(currentIndex + 1) % values.length];
              handleFilterChange(header, nextValue);
            }}
          >
            <Text style={styles.filterSelectText}>
              {filterValue === 'true' ? 'Evet' : 
               filterValue === 'false' ? 'Hayır' : 'Hepsi'}
            </Text>
          </TouchableOpacity>
        ) : columnType === 'date' ? (
          operator === 'between' ? (
            <View style={{ flexDirection: 'row', gap: 4 }}>
              <input
                type="date"
                className="table-date-input"
                data-date-index="0"
                style={{
                  ...styles.filterInput,
                  flex: 1,
                  colorScheme: 'dark',
                  textAlign: 'center',
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  height: '32px',
                  minHeight: '32px',
                }}
                value={filterValue.split(',')[0] || ''}
                onChange={(e) => {
                  const [_, endDate] = filterValue.split(',');
                  handleFilterChange(header, `${e.target.value},${endDate || ''}`);
                }}
              />
              <input
                type="date"
                className="table-date-input"
                data-date-index="1"
                style={{
                  ...styles.filterInput,
                  flex: 1,
                  colorScheme: 'dark',
                  textAlign: 'center',
                  display: 'flex',
                  justifyContent: 'center',
                  alignItems: 'center',
                  height: '32px',
                  minHeight: '32px',
                }}
                value={filterValue.split(',')[1] || ''}
                onChange={(e) => {
                  const [startDate] = filterValue.split(',');
                  handleFilterChange(header, `${startDate || ''},${e.target.value}`);
                }}
              />
            </View>
          ) : (
            <input
              type="date"
              className="table-date-input"
              style={{
                ...styles.filterInput,
                width: '100%',
                colorScheme: 'dark',
                textAlign: 'center',
                display: 'flex',
                justifyContent: 'center',
                alignItems: 'center',
                height: '32px',
                minHeight: '32px',
              }}
              value={filterValue}
              onChange={(e) => handleFilterChange(header, e.target.value)}
            />
          )
        ) : columnType === 'number' && operator === 'between' ? (
          <TextInput
            style={[styles.filterInput, { textAlign: 'center' }]}
            placeholder="min-max"
            value={filterValue}
            onChangeText={(value) => {
              // Sadece sayı ve tire karakterine izin ver
              const cleanValue = value.replace(/[^0-9-]/g, '');
              handleFilterChange(header, cleanValue);
            }}
          />
        ) : (
          <TextInput
            style={[styles.filterInput, { textAlign: 'center' }]}
            placeholder={operator === 'between' ? "min-max" : "Ara..."}
            value={filterValue}
            onChangeText={(value) => handleFilterChange(header, value)}
          />
        ))}
      </View>
    );
  };

  useEffect(() => {
    if (data.length > 0) {
      const columns = Object.keys(data[0]);
      
      // LocalStorage'dan kullanıcıya özel layout'u oku
      const storageKey = `columnLayout_${endpoint}_${user?.email || 'guest'}`;
      const savedLayout = localStorage.getItem(storageKey);
      
      if (savedLayout) {
        try {
          const { columnOrder: savedOrder, visibleColumns: savedVisibility } = JSON.parse(savedLayout);
          
          // Kaydedilmiş sütun sırası geçerliyse kullan
          if (savedOrder && Array.isArray(savedOrder) && savedOrder.length > 0) {
            // Yeni sütunlar eklenmişse, onları da ekle
            const newColumns = columns.filter(col => !savedOrder.includes(col));
            setColumnOrder([...savedOrder, ...newColumns]);
          } else {
            setColumnOrder(columns);
          }
          
          // Kaydedilmiş görünürlük ayarlarını kullan
          if (savedVisibility && typeof savedVisibility === 'object') {
            // Yeni sütunlar için varsayılan görünürlük ekle
            const mergedVisibility = { ...savedVisibility };
            columns.forEach(col => {
              if (!(col in mergedVisibility)) {
                mergedVisibility[col] = !(col === 'id' || col === 'kullanici' || col === 'tarih');
              }
            });
            setVisibleColumns(mergedVisibility);
          } else {
            // Kaydedilmiş ayar yoksa varsayılanları kullan
            setInitialVisibility(columns);
          }
        } catch (error) {
          console.error('Layout yükleme hatası:', error);
          // Hata durumunda varsayılanları kullan
          setColumnOrder(columns);
          setInitialVisibility(columns);
        }
      } else {
        // İlk kez bu tablo açılıyor, varsayılanları kullan
        setColumnOrder(columns);
        setInitialVisibility(columns);
      }
    }
  }, [data, endpoint, user]);
  
  // Varsayılan görünürlük ayarlarını uygula
  const setInitialVisibility = (columns) => {
    const initialVisibility = columns.reduce((acc, column) => {
      // id, kullanici ve tarih sütunlarını gizle
      if (column === 'id' || column === 'kullanici' || column === 'tarih') {
        acc[column] = false;
      } else {
        acc[column] = true;
      }
      return acc;
    }, {});
    
    // ekleyen_kullanici sütununda sadece 1 benzersiz değer varsa gizle
    if (columns.includes('ekleyen_kullanici')) {
      const uniqueUsers = new Set(data.map(row => row.ekleyen_kullanici));
      if (uniqueUsers.size <= 1) {
        initialVisibility['ekleyen_kullanici'] = false;
      }
    }
    
    setVisibleColumns(initialVisibility);
  };
  
  // Sütun düzeni değiştiğinde localStorage'a kaydet
  useEffect(() => {
    if (columnOrder.length > 0 && Object.keys(visibleColumns).length > 0 && user && endpoint) {
      const storageKey = `columnLayout_${endpoint}_${user?.email || 'guest'}`;
      const layout = {
        columnOrder,
        visibleColumns
      };
      localStorage.setItem(storageKey, JSON.stringify(layout));
    }
  }, [columnOrder, visibleColumns, endpoint, user]);

  const handleDragStart = (event, columnId) => {
    event.stopPropagation();
    event.dataTransfer.effectAllowed = 'move';
    setDraggedColumn(columnId);
  };

  const handleDragOver = (e, columnId) => {
    e.preventDefault();
    e.stopPropagation();
    e.dataTransfer.dropEffect = 'move';
    
    if (draggedColumn && draggedColumn !== columnId) {
      const newOrder = [...columnOrder];
      const draggedIndex = newOrder.indexOf(draggedColumn);
      const dropIndex = newOrder.indexOf(columnId);
      
      // Sütun sırasını güncelle
      newOrder.splice(draggedIndex, 1);
      newOrder.splice(dropIndex, 0, draggedColumn);
      setColumnOrder(newOrder);
    }
  };

  const handleDragEnd = (event) => {
    event.preventDefault();
    event.stopPropagation();
    setDraggedColumn(null);
  };

  useEffect(() => {
    try {
      const validData = Array.isArray(data) ? data : [];
      if (validData.length > 0 && typeof validData[0] !== 'object') {
        throw new Error('Geçersiz veri formatı');
      }
      setFilteredData(validData);
      setError(null);
    } catch (err) {
      console.error('DataTable Error:', err);
      setError('Veriler yüklenirken bir hata oluştu');
      setFilteredData([]);
    }
  }, [data]);

  // Pagination hesaplamaları
  const totalPages = Math.ceil(filteredData.length / rowsPerPage);
  const startIndex = (currentPage - 1) * rowsPerPage;
  const endIndex = startIndex + rowsPerPage;
  const currentData = filteredData.slice(startIndex, endIndex);

  const handlePageChange = (page) => {
    setCurrentPage(page);
  };

  const handleRowsPerPageChange = (value) => {
    const newValue = value === 'Hepsi' ? filteredData.length : value;
    setRowsPerPage(newValue);
    setCurrentPage(1);
  };

  // Pagination kontrollerini render et
  const renderPagination = () => (
    <View style={styles.paginationContainer}>
      <View style={styles.paginationControls}>
        <TouchableOpacity
          style={[styles.paginationButton, currentPage === 1 && styles.paginationButtonDisabled]}
          onPress={() => handlePageChange(1)}
          disabled={currentPage === 1}
        >
          <Text style={styles.paginationButtonText}>{'<<'}</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.paginationButton, currentPage === 1 && styles.paginationButtonDisabled]}
          onPress={() => handlePageChange(currentPage - 1)}
          disabled={currentPage === 1}
        >
          <Text style={styles.paginationButtonText}>{'<'}</Text>
        </TouchableOpacity>
        
        <Text style={styles.paginationText}>
          {currentPage} / {totalPages}
        </Text>
        
        <TouchableOpacity
          style={[styles.paginationButton, currentPage === totalPages && styles.paginationButtonDisabled]}
          onPress={() => handlePageChange(currentPage + 1)}
          disabled={currentPage === totalPages}
        >
          <Text style={styles.paginationButtonText}>{'>'}</Text>
        </TouchableOpacity>
        <TouchableOpacity
          style={[styles.paginationButton, currentPage === totalPages && styles.paginationButtonDisabled]}
          onPress={() => handlePageChange(totalPages)}
          disabled={currentPage === totalPages}
        >
          <Text style={styles.paginationButtonText}>{'>>'}</Text>
        </TouchableOpacity>
      </View>
    </View>
  );

  if (error) {
    return (
      <Text style={[styles.noDataText, { color: 'red' }]}>{error}</Text>
    );
  }

  if (!Array.isArray(data) || data.length === 0) {
    return (
      <Text style={styles.noDataText}>Hiç veri yok.</Text>
    );
  }

  // Veri tipini belirle
  const getColumnType = (header) => {
    // Başlık adına göre tip belirle (daha güvenilir)
    const headerLower = header.toLowerCase();
    
    // Tarih sütunları
    if (headerLower.includes('tarih') || headerLower.includes('date')) return 'date';
    
    // Sayısal sütunlar (header adına göre)
    if (headerLower === 'id' || 
        headerLower === 'miktar' || 
        headerLower === 'amount' ||
        headerLower === 'taksit' ||
        headerLower === 'metrekare' ||
        headerLower === 'alis_adedi' ||
        headerLower.includes('_adedi') ||
        headerLower.includes('fiyat') ||
        headerLower.includes('kar_zarar') ||
        headerLower.includes('_yuzde')) {
      return 'number';
    }
    
    const value = data[0][header];
    if (typeof value === 'number') return 'number';
    if (typeof value === 'boolean') return 'boolean';
    
    // String ise ve tamamen sayı içeriyorsa number olarak işle
    if (typeof value === 'string' && value.trim() !== '') {
      // ISO 8601 formatı: "2025-10-29T..." veya "29.10.2025 ..."
      if (value.includes('T') && value.includes(':') || 
          /^\d{2}\.\d{2}\.\d{4}/.test(value) ||
          /^\d{4}-\d{2}-\d{2}/.test(value)) {
        return 'date';
      }
      
      // Sayısal string mi kontrol et (ondalıklı sayı dahil)
      if (/^-?\d+(\.\d+)?$/.test(value.trim())) {
        return 'number';
      }
    }
    
    if (value instanceof Date) return 'date';
    
    return 'text';
  };

  // Sütun genişliklerini hesapla
  const calculateColumnWidths = () => {
    const widths = {};
    
    columnOrder.forEach(header => {
      const filter = filters[header];
      const operator = filter?.operator || getDefaultOperator(getColumnType(header));
      
      // "Arasında" filtresi seçiliyse 280px
      if (operator === 'between') {
        widths[header] = 280;
        return;
      }
      
      const columnType = getColumnType(header);
      
      // Tarih sütunları için özel hesaplama
      if (columnType === 'date') {
        // Tarih formatı: "29.10.2025 17:07:40" (19 karakter)
        // Karakter başına 7px (tarih için daha kompakt)
        widths[header] = 185; // Sabit 180px - tarih formatına tam uygun
        return;
      }
      
      // Karakter tipine göre genişlik hesaplayan fonksiyon
      const calculateTextWidth = (text) => {
        if (!text) return 0;
        const str = String(text);
        let width = 0;
        
        for (let i = 0; i < str.length; i++) {
          const char = str[i];
          
          // Büyük harfler (A-Z, Türkçe büyük harfler)
          if (/[A-ZÇĞİÖŞÜ]/.test(char)) {
            width += 12; // Büyük harfler daha geniş
          }
          // Küçük harfler (a-z, Türkçe küçük harfler)
          else if (/[a-zçğıöşü]/.test(char)) {
            width += 9; // Küçük harfler daha dar
          }
          // Sayılar
          else if (/[0-9]/.test(char)) {
            width += 10; // Sayılar orta genişlik
          }
          // Boşluk
          else if (char === ' ') {
            width += 6; // Boşluk dar
          }
          // Özel karakterler (@, ., -, _, vb.)
          else {
            width += 8; // Özel karakterler orta-dar
          }
        }
        
        return width;
      };
      
      // Başlık genişliğini hesapla
      // Eğer bu sütun sıralanıyorsa ok işareti için +24px ekle (ok karakteri genişliği)
      const headerWidth = calculateTextWidth(header) + (sortColumn === header ? 24 : 0);
      
      // Satırlardaki en geniş değeri bul
      let maxContentWidth = headerWidth;
      
      data.forEach(row => {
        const value = row[header];
        if (value !== null && value !== undefined) {
          // TAM METNİ kullan (formatlanmamış, kısaltılmamış)
          const valueStr = String(value);
          const valueWidth = calculateTextWidth(valueStr);
          if (valueWidth > maxContentWidth) {
            maxContentWidth = valueWidth;
          }
        }
      });
      
      // Padding'ler ekle (left + right + borders)
      const estimatedWidth = Math.ceil(maxContentWidth) + 30;
      
      // Min: 126px, Max: 280px
      widths[header] = Math.min(Math.max(estimatedWidth, 126), 280);
    });
    
    setColumnWidths(widths);
  };

  const formatDate = (dateString) => {
    if (!dateString) return '';
    const date = new Date(dateString);
    return date.toLocaleDateString('tr-TR', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit'
    });
  };

  // Link kontrolü yapan fonksiyon
  const isLink = (value) => {
    if (!value || typeof value !== 'string') return false;
    const str = value.trim();
    return str.startsWith('http://') || str.startsWith('https://') || str.startsWith('www.');
  };

  const renderCell = (value, columnId, rowId, isEditing = false) => {
    const formatValue = (val) => {
      if (val === null || val === undefined) return '';
      return String(val);
    };

    const displayValue = typeof value === 'string' && value.includes('T') && value.includes('Z') 
      ? formatDate(value)
      : formatValue(value);

    // Link kontrolü
    const linkValue = isLink(value) ? value : null;
    const normalizedLink = linkValue && !linkValue.startsWith('http') 
      ? `https://${linkValue}` 
      : linkValue;

    // Düzenleme modunda input göster
    if (isEditing) {
      // İstek tablosunda link, miktar, para_birimi ve aciklama düzenlenebilir
      if (endpoint === 'istek' && 
          columnId !== 'link' && 
          columnId !== 'miktar' && 
          columnId !== 'para_birimi' && 
          columnId !== 'aciklama') {
        // Düzenlenemez alanlar için sadece text göster
    return (
      <div style={{ position: 'relative', width: '100%' }}>
        <div 
          style={{ 
                ...styles.tableCellText,
                textAlign: 'left',
                display: 'block',
            width: '100%',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
                opacity: 0.6,
                color: 'rgba(255, 255, 255, 0.5)'
              }}
            >
              {displayValue}
            </div>
          </div>
        );
      }
      
      // Hatırlatma tablosunda sadece hatirlatilacak_olay ve olay_zamani düzenlenebilir
      if (endpoint === 'hatirlatma' && columnId !== 'hatirlatilacak_olay' && columnId !== 'olay_zamani') {
        // Düzenlenemez alanlar için sadece text göster
        return (
          <div style={{ position: 'relative', width: '100%' }}>
            <div 
            style={{
              ...styles.tableCellText,
              textAlign: 'left',
                display: 'block',
                width: '100%',
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                opacity: 0.6,
                color: 'rgba(255, 255, 255, 0.5)'
              }}
            >
              {displayValue}
            </div>
          </div>
        );
      }
      
      const columnType = getColumnType(columnId);
      
      // Dropdown alan mı kontrol et
      const isDropdownField = dropdownOptions[columnId] && dropdownOptions[columnId].length > 0;
      
      // Boolean alan mı kontrol et (0/1 veya true/false)
      const isBooleanField = columnId.includes('_mi') || 
                            columnId === 'talimat_varmi' || 
                            columnId === 'faiz_uygulaniyormu' ||
                            columnId === 'miktar_belirsiz';
      
      // Dropdown alan ise select göster
      if (isDropdownField || isBooleanField) {
        const options = dropdownOptions[columnId] || [
          { value: '1', label: 'Evet' },
          { value: '0', label: 'Hayır' }
        ];
        
        // Boolean değerleri string'e çevir
        let selectValue = editingData[columnId];
        if (typeof selectValue === 'boolean') {
          selectValue = selectValue ? '1' : '0';
        } else if (selectValue === true || selectValue === 1) {
          selectValue = '1';
        } else if (selectValue === false || selectValue === 0) {
          selectValue = '0';
        }
        
        // Custom dropdown için key ve aktif kontrol
        const dropdownKey = `${rowId}-${columnId}`;
        const isDropdownOpen = showEditDropdown?.rowId === rowId && showEditDropdown?.columnId === columnId;
        const selectedOption = options.find(opt => opt.value == selectValue);
        const selectedLabel = selectedOption ? selectedOption.label : '';
        
        return (
          <div style={{ position: 'relative', width: '100%' }}>
            {/* Custom Dropdown Button */}
            <div
              ref={el => editDropdownButtonRef.current[dropdownKey] = el}
              style={{
                width: '100%',
                padding: '4px',
                borderRadius: '4px',
                border: '1px solid rgba(255, 255, 255, 0.2)',
                backgroundColor: 'rgba(30, 40, 50, 0.95)',
                color: '#fff',
                fontFamily: GLOBAL_FONT_FAMILY,
                fontSize: 'clamp(10px, 1.8vw, 13px)',
                outline: 'none',
                cursor: 'pointer',
            display: 'flex',
            alignItems: 'center',
                justifyContent: 'space-between',
                boxSizing: 'border-box',
                transition: 'all 0.3s ease'
              }}
              onClick={(e) => {
                e.stopPropagation();
                if (!isDropdownOpen && editDropdownButtonRef.current[dropdownKey]) {
                  const rect = editDropdownButtonRef.current[dropdownKey].getBoundingClientRect();
                  setEditDropdownPosition({
                    top: rect.bottom + 4,
                    left: rect.left
                  });
                }
                setShowEditDropdown(isDropdownOpen ? null : { rowId: rowId, columnId });
              }}
            >
              <span style={{ 
                flex: 1,
                overflow: 'hidden',
                textOverflow: 'ellipsis',
                whiteSpace: 'nowrap',
                fontStyle: selectedLabel ? 'normal' : 'italic',
                color: selectedLabel ? '#fff' : 'rgba(255, 255, 255, 0.5)'
              }}>
                {selectedLabel || ''}
              </span>
              <span style={{ 
                fontSize: '8px',
                color: isDropdownOpen ? 'rgba(0, 123, 255, 1)' : 'rgba(255, 255, 255, 0.7)',
                transition: 'transform 0.3s ease',
                transform: isDropdownOpen ? 'rotate(180deg)' : 'rotate(0deg)',
                display: 'inline-block',
                marginLeft: '4px'
              }}>
                ▼
              </span>
            </div>
            
            {/* Custom Dropdown Options */}
            {isDropdownOpen && createPortal(
              <div
                data-edit-dropdown="true"
            style={{
                  position: 'fixed',
                  top: editDropdownPosition.top,
                  left: editDropdownPosition.left,
                  width: 'auto',
                  minWidth: 150,
                  maxWidth: 350,
                  backgroundColor: 'rgba(20, 25, 30, 0.98)',
                  borderRadius: '12px',
                  padding: '6px',
                  boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
                  border: '1px solid rgba(0, 123, 255, 0.5)',
                  zIndex: 99999,
                  backdropFilter: 'blur(12px)'
                }}
              >
                {options.map((opt, idx) => {
                  const isActive = selectValue == opt.value;
                  
                  return (
                    <div
                      key={idx}
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
                        fontSize: 'clamp(10px, 1.8vw, 13px)',
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
                        const newValue = opt.value;
                        // Boolean alanlar için 0/1'i boolean'a çevir
                        if (isBooleanField && !isDropdownField) {
                          setEditingData({ ...editingData, [columnId]: newValue === '1' ? 1 : 0 });
                        } else {
                          // İstek tablosunda para_birimi için özel kontrol
                          if (endpoint === 'istek' && columnId === 'para_birimi') {
                            handleIstekFieldChange(columnId, newValue);
                          } else {
                            setEditingData({ ...editingData, [columnId]: newValue });
                          }
                        }
                        setShowEditDropdown(null);
                      }}
                    >
                      {opt.label}
                    </div>
                  );
                })}
              </div>,
              document.body
            )}
          </div>
        );
      }
      
      // Tarih alanları için input tipi belirleme
      if (columnType === 'date') {
        // Değerin datetime mi yoksa sadece date mi olduğunu kontrol et
        const originalValue = editingData[columnId];
        const hasTime = originalValue && typeof originalValue === 'string' && 
                       (originalValue.includes('T') || /\d{2}:\d{2}/.test(originalValue));
        
        // Saat bilgisi varsa datetime-local, yoksa date kullan
        const inputType = hasTime ? 'datetime-local' : 'date';
        
        return (
          <input
            type={inputType}
            value={editingData[columnId] || ''}
            onChange={(e) => {
              const newValue = e.target.value;
              if (endpoint === 'istek' && (columnId === 'link' || columnId === 'miktar' || columnId === 'para_birimi')) {
                handleIstekFieldChange(columnId, newValue);
              } else {
                setEditingData({ ...editingData, [columnId]: newValue });
              }
            }}
            style={{
              width: '100%',
              padding: '4px',
              borderRadius: '4px',
              border: '1px solid rgba(255, 255, 255, 0.2)',
              backgroundColor: 'rgba(30, 40, 50, 0.95)',
              color: '#fff',
              fontFamily: GLOBAL_FONT_FAMILY,
              fontSize: 'clamp(10px, 1.8vw, 13px)',
              outline: 'none'
            }}
            onClick={(e) => e.stopPropagation()}
          />
        );
      } else if (columnType === 'number') {
        // Taksit alanı için özel kontrol
        const isTaksitField = columnId === 'taksit';
        
        return (
          <input
            type="number"
            value={editingData[columnId] || ''}
            onChange={(e) => {
              let val = e.target.value;
              
              // Taksit alanında 1'den küçük değerleri engelle
              if (isTaksitField && val && parseInt(val) < 1) {
                val = '1';
              }
              
              if (endpoint === 'istek' && columnId === 'miktar') {
                handleIstekFieldChange(columnId, val);
              } else {
                setEditingData({ ...editingData, [columnId]: val });
              }
            }}
            onBlur={(e) => {
              // Taksit alanında blur olduğunda boş veya 1'den küçükse 1 yap
              if (isTaksitField) {
                const val = e.target.value;
                if (!val || parseInt(val) < 1) {
                  setEditingData({ ...editingData, [columnId]: '1' });
                }
              }
            }}
            style={{
              width: '100%',
              padding: '4px',
              borderRadius: '4px',
              border: '1px solid rgba(255, 255, 255, 0.2)',
              backgroundColor: 'rgba(30, 40, 50, 0.95)',
              color: '#fff',
              fontFamily: GLOBAL_FONT_FAMILY,
              fontSize: 'clamp(10px, 1.8vw, 13px)',
              outline: 'none'
            }}
            onClick={(e) => e.stopPropagation()}
            min={isTaksitField ? "1" : undefined}
            max={isTaksitField ? "999" : undefined}
          />
        );
      } else {
        return (
          <input
            type="text"
            value={editingData[columnId] || ''}
            onChange={(e) => {
              const newValue = e.target.value;
              if (endpoint === 'istek' && columnId === 'link') {
                handleIstekFieldChange(columnId, newValue);
              } else {
                setEditingData({ ...editingData, [columnId]: newValue });
              }
            }}
            style={{
              width: '100%',
              padding: '4px',
              borderRadius: '4px',
              border: '1px solid rgba(255, 255, 255, 0.2)',
              backgroundColor: 'rgba(30, 40, 50, 0.95)',
              color: '#fff',
              fontFamily: GLOBAL_FONT_FAMILY,
              fontSize: 'clamp(10px, 1.8vw, 13px)',
              outline: 'none'
            }}
            onClick={(e) => e.stopPropagation()}
          />
        );
      }
    }

    // Link ise <a> tag'i ile göster
    if (linkValue && normalizedLink) {
      return (
        <a
          href={normalizedLink}
          target="_blank"
          rel="noopener noreferrer"
          onClick={(e) => e.stopPropagation()}
          style={{
            color: 'rgba(0, 123, 255, 0.9)',
            textDecoration: 'underline',
            cursor: 'pointer',
              ...styles.tableCellText,
              textAlign: 'left',
            display: 'block',
            width: '100%',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap'
          }}
        >
          {displayValue}
        </a>
      );
    }

    return (
      <div style={{ position: 'relative', width: '100%' }}>
          <div 
            style={{ 
              width: '100%',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'flex-start'
            }}
          >
          <span 
            data-tooltip={String(value)}
            onClick={(e) => {
              e.stopPropagation();
              
              // Link ise tooltip gösterme
              if (linkValue) return;
              
              // Görüntülenen metin orijinalden farklıysa tooltip göster (ellipsis varsa)
              const fullText = String(value);
              
              // scrollWidth > clientWidth ise tooltip göster
              const element = e.currentTarget;
              const isOverflowing = element.scrollWidth > element.clientWidth + 1;
              
              if (!isOverflowing) return;
              
              // Mevcut tooltip varsa kapat
              const existingTooltip = document.querySelector('.tooltip');
              if (existingTooltip) {
                existingTooltip.remove();
                setActiveTooltip(null);
                return;
              }
              
              // Yeni tooltip oluştur
              const tooltip = document.createElement('div');
              tooltip.className = 'tooltip';
              tooltip.textContent = fullText;
              tooltip.style.fontFamily = GLOBAL_FONT_FAMILY;
              tooltip.style.position = 'fixed';
              const rect = e.currentTarget.getBoundingClientRect();
              tooltip.style.left = `${rect.left}px`;
              tooltip.style.top = `${rect.top - 40}px`;
              tooltip.style.backgroundColor = '#1a1f25';
              tooltip.style.color = '#fff';
              tooltip.style.paddingTop = '8px';
              tooltip.style.paddingBottom = '8px';
              tooltip.style.paddingLeft = '8px';
              tooltip.style.paddingRight = '8px';
              tooltip.style.borderRadius = '4px';
              tooltip.style.zIndex = '10000';
              tooltip.style.whiteSpace = 'normal';
              tooltip.style.maxWidth = '300px';
              tooltip.style.wordBreak = 'break-word';
              tooltip.style.borderStyle = 'solid';
              tooltip.style.borderWidth = '1px';
              tooltip.style.borderColor = 'rgba(255, 255, 255, 0.1)';
              tooltip.style.boxShadow = '0 4px 6px rgba(0, 0, 0, 0.1)';
              document.body.appendChild(tooltip);
              setActiveTooltip(tooltip);
            }}
            style={{
              ...styles.tableCellText,
              textAlign: 'left',
              display: 'block',
              width: '100%',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
              cursor: linkValue ? 'pointer' : 'pointer'
            }}
          >
            {displayValue}
          </span>
        </div>
      </div>
    );
  };

  // Düzenleme başlat
  const handleEdit = (row) => {
    setEditingRowId(row.id);
    
    // Tarihleri uygun input formatına çevir
    const formattedData = { ...row };
    Object.keys(formattedData).forEach(key => {
      const value = formattedData[key];
      if (value && typeof value === 'string') {
        // ISO 8601 formatındaki tarihleri kontrol et (YYYY-MM-DDTHH:mm:ss.sssZ)
        if (value.includes('T') && value.includes('Z')) {
          // datetime-local için: YYYY-MM-DDTHH:mm formatı
          const date = new Date(value);
          const year = date.getFullYear();
          const month = String(date.getMonth() + 1).padStart(2, '0');
          const day = String(date.getDate()).padStart(2, '0');
          const hours = String(date.getHours()).padStart(2, '0');
          const minutes = String(date.getMinutes()).padStart(2, '0');
          formattedData[key] = `${year}-${month}-${day}T${hours}:${minutes}`;
        }
        // SQL datetime formatını kontrol et (YYYY-MM-DD HH:mm:ss)
        else if (/^\d{4}-\d{2}-\d{2}\s\d{2}:\d{2}:\d{2}/.test(value)) {
          // datetime-local için: YYYY-MM-DDTHH:mm formatı
          const [datePart, timePart] = value.split(' ');
          const [hours, minutes] = timePart.split(':');
          formattedData[key] = `${datePart}T${hours}:${minutes}`;
        }
      }
    });
    
    setEditingData(formattedData);
  };

  // İstek tablosu için özel field değişiklik handler'ı (link-fiyat çakışma kontrolü)
  const handleIstekFieldChange = (columnId, newValue) => {
    const currentData = { ...editingData };
    
    // Link alanına değer giriliyorsa ve miktar/para_birimi dolu ise
    if (columnId === 'link' && newValue && newValue.trim() !== '') {
      const hasMiktar = currentData.miktar && currentData.miktar.toString().trim() !== '';
      const hasParaBirimi = currentData.para_birimi && currentData.para_birimi.trim() !== '';
      
      if (hasMiktar || hasParaBirimi) {
        setFieldConflictData({
          columnId,
          newValue,
          message: 'Girdiğiniz miktar ve para birimi silinecek, onaylıyor musunuz?',
          onConfirm: () => {
            setEditingData({
              ...currentData,
              link: newValue,
              miktar: null,
              para_birimi: null
            });
            setShowFieldConflictModal(false);
            setFieldConflictData(null);
          },
          onCancel: () => {
            setShowFieldConflictModal(false);
            setFieldConflictData(null);
          }
        });
        setShowFieldConflictModal(true);
        return;
      }
    }
    
    // Miktar alanına değer giriliyorsa ve link dolu ise
    if (columnId === 'miktar' && newValue && newValue.toString().trim() !== '') {
      if (currentData.link && currentData.link.trim() !== '') {
        setFieldConflictData({
          columnId,
          newValue,
          message: 'Girdiğiniz link silinecek, onaylıyor musunuz?',
          onConfirm: () => {
            setEditingData({
              ...currentData,
              miktar: newValue,
              link: null
            });
            setShowFieldConflictModal(false);
            setFieldConflictData(null);
          },
          onCancel: () => {
            setShowFieldConflictModal(false);
            setFieldConflictData(null);
          }
        });
        setShowFieldConflictModal(true);
        return;
      }
    }
    
    // Para birimi alanına değer giriliyorsa ve link dolu ise
    if (columnId === 'para_birimi' && newValue && newValue.toString().trim() !== '') {
      if (currentData.link && currentData.link.trim() !== '') {
        setFieldConflictData({
          columnId,
          newValue,
          message: 'Girdiğiniz link silinecek, onaylıyor musunuz?',
          onConfirm: () => {
            setEditingData({
              ...currentData,
              para_birimi: newValue,
              link: null
            });
            setShowFieldConflictModal(false);
            setFieldConflictData(null);
          },
          onCancel: () => {
            setShowFieldConflictModal(false);
            setFieldConflictData(null);
          }
        });
        setShowFieldConflictModal(true);
        return;
      }
    }
    
    // Çakışma yoksa normal güncelle
    setEditingData({ ...currentData, [columnId]: newValue });
  };

  // Düzenleme iptal
  const handleCancelEdit = () => {
    setEditingRowId(null);
    setEditingData({});
  };

  // Düzenleme kaydet
  const handleSaveEdit = async () => {
    if (!endpoint) {
      alert('Endpoint bilgisi eksik, güncelleme yapılamıyor!');
      return;
    }
    
    try {
      const response = await updateData(endpoint, editingRowId, editingData);
      
      if (response.success) {
        setEditingRowId(null);
        setEditingData({});
        if (onUpdate) {
          onUpdate(); // Parent component'e veri yenileme sinyali gönder
        }
      } else {
        alert('Güncelleme başarısız: ' + (response.error || 'Bilinmeyen hata'));
      }
    } catch (error) {
      console.error('Güncelleme hatası:', error);
      alert('Güncelleme sırasında bir hata oluştu: ' + error.message);
    }
  };

  // Silme işlemini başlat (onay modalını göster)
  const handleDeleteClick = (rowId) => {
    setDeleteRowId(rowId);
    setShowDeleteConfirm(true);
  };

  // Silme işlemini iptal et
  const handleCancelDelete = () => {
    setShowDeleteConfirm(false);
    setDeleteRowId(null);
  };

  // Silme işlemini onayla ve gerçekleştir
  const handleConfirmDelete = async () => {
    if (!endpoint) {
      alert('Endpoint bilgisi eksik, silme yapılamıyor!');
      return;
    }
    
    if (!deleteRowId) {
      return;
    }
    
    try {
      const response = await deleteData(endpoint, deleteRowId);
      
      if (response.success) {
        setShowDeleteConfirm(false);
        setDeleteRowId(null);
        if (onUpdate) {
          onUpdate(); // Parent component'e veri yenileme sinyali gönder
        }
      } else {
        alert('Silme başarısız: ' + (response.error || 'Bilinmeyen hata'));
      }
    } catch (error) {
      console.error('Silme hatası:', error);
      alert('Silme sırasında bir hata oluştu: ' + error.message);
    }
  };

  useEffect(() => {
    applyFilters();
  }, [filters, sortColumn, sortDirection]);

  // Sütun genişliklerini hesapla (data, filters, columnOrder, sortColumn değişince)
  useEffect(() => {
    if (columnOrder.length > 0 && data.length > 0) {
      calculateColumnWidths();
    }
  }, [data, filters, columnOrder, sortColumn]);

  // Tooltip dışına tıklanınca kapat
  useEffect(() => {
    const handleClickOutside = (e) => {
      const tooltip = document.querySelector('.tooltip');
      if (tooltip && !tooltip.contains(e.target)) {
        tooltip.remove();
        setActiveTooltip(null);
      }
    };

    if (activeTooltip) {
      document.addEventListener('mousedown', handleClickOutside);
      return () => {
        document.removeEventListener('mousedown', handleClickOutside);
      };
    }
  }, [activeTooltip]);

  // Dropdown pozisyonunu hesapla
  const calculateDropdownPosition = (buttonElement) => {
    if (!buttonElement) return;
    
    const rect = buttonElement.getBoundingClientRect();
    const spaceBelow = window.innerHeight - rect.bottom;
    const spaceAbove = rect.top;
    const dropdownHeight = 400; // Maksimum dropdown yüksekliği
    
    let top = rect.bottom;
    if (spaceBelow < dropdownHeight && spaceAbove > spaceBelow) {
      // Eğer aşağıda yeterli alan yoksa ve yukarıda daha fazla alan varsa yukarı aç
      top = rect.top - dropdownHeight;
    }

    setDropdownPosition({
      top: top,
      left: rect.left,
    });
  };

  // Sütun görünürlüğünü değiştir
  const toggleColumn = (columnId, event) => {
    event.stopPropagation();
    setVisibleColumns(prev => {
      const newState = { ...prev };
      newState[columnId] = !newState[columnId];
      
      // En az bir sütun görünür olmalı
      const visibleCount = Object.values(newState).filter(Boolean).length;
      if (visibleCount === 0) {
        return prev;
      }
      
      return newState;
    });
  };

  // Dropdown dışına tıklandığında kapat
  useEffect(() => {
    const handleClickOutside = (event) => {
      // Portal ile render edilen dropdown dışına tıklanmış mı?
      const isDropdownClick = event.target.closest('[data-column-selector-dropdown]') ||
                             event.target.closest('[data-column-selector-item]');
      const isButtonClick = event.target.closest('[data-column-selector-button]') ||
                           (columnSelectorRef.current && columnSelectorRef.current.contains(event.target));
      
      if (showColumnSelector && !isDropdownClick && !isButtonClick) {
        setShowColumnSelector(false);
      }
    };

    const handleScroll = () => {
      // Scroll olduğunda dropdown pozisyonunu güncelle
      if (showColumnSelector && columnSelectorRef.current) {
        const rect = columnSelectorRef.current.getBoundingClientRect();
        
        // Görünür sütun sayısına göre dropdown yüksekliğini tahmin et
        const visibleColumnCount = columnOrder.filter(columnId => {
          if (columnId === 'id' || columnId === 'kullanici' || columnId === 'tarih') return false;
          if (columnId === 'ekleyen_kullanici' && data.length > 0) {
            const uniqueUsers = new Set(data.map(row => row.ekleyen_kullanici));
            if (uniqueUsers.size <= 1) return false;
          }
          return true;
        }).length;
        
        const estimatedDropdownHeight = (visibleColumnCount * 35) + 20;
        const viewportHeight = window.innerHeight;
        const spaceBelow = viewportHeight - rect.bottom;
        const spaceAbove = rect.top;
        
        // Eğer aşağıda yeterli yer yoksa ve yukarıda daha fazla yer varsa, yukarı aç
        let top = rect.bottom + 4;
        if (spaceBelow < estimatedDropdownHeight && spaceAbove > spaceBelow) {
          top = rect.top - estimatedDropdownHeight - 4;
        }
        
        setDropdownPosition({
          top: top,
          left: rect.left,
        });
      }
    };

    if (showColumnSelector) {
      setTimeout(() => {
      document.addEventListener('mousedown', handleClickOutside);
      }, 100);
      
      // Tüm scroll olaylarını dinle (window ve tüm parent elementler)
      document.addEventListener('scroll', handleScroll, true); // true = capture phase
      window.addEventListener('scroll', handleScroll, true);
    }

    return () => {
      document.removeEventListener('mousedown', handleClickOutside);
      document.removeEventListener('scroll', handleScroll, true);
      window.removeEventListener('scroll', handleScroll, true);
    };
  }, [showColumnSelector]);

  // Filter dropdown dışına tıklanınca kapat
  useEffect(() => {
    const handleFilterDropdownClickOutside = (event) => {
      // Portal ile render edilen dropdown dışına tıklanmış mı?
      // Dropdown item'lara tıklama hariç!
      const isDropdownClick = event.target.closest('[style*="filterDropdownContainer"]') ||
                             event.target.closest('[style*="filterDropdownItem"]');
      const isButtonClick = event.target.closest('[style*="filterOperatorButton"]');
      
      if (activeFilterDropdown && !isDropdownClick && !isButtonClick) {
        setActiveFilterDropdown(null);
      }
    };

    const handleScroll = () => {
      // Scroll olduğunda dropdown pozisyonunu güncelle
      if (activeFilterDropdown && filterOperatorRefs.current[activeFilterDropdown]) {
        const button = filterOperatorRefs.current[activeFilterDropdown];
        const rect = button.getBoundingClientRect();
        const columnType = getColumnType(activeFilterDropdown);
        const operators = filterOperators[columnType] || [];
        
        // Dropdown yüksekliğini tahmin et
        const estimatedDropdownHeight = (operators.length * 35) + 20;
        const viewportHeight = window.innerHeight;
        const spaceBelow = viewportHeight - rect.bottom;
        const spaceAbove = rect.top;
        
        // Eğer aşağıda yeterli yer yoksa ve yukarıda daha fazla yer varsa, yukarı aç
        let top = rect.bottom + 4;
        if (spaceBelow < estimatedDropdownHeight && spaceAbove > spaceBelow) {
          top = rect.top - estimatedDropdownHeight - 4;
        }
        
        setDropdownPosition({
          top: top,
          left: rect.left,
        });
      }
    };

    if (activeFilterDropdown) {
      // Kısa gecikme ile ekle (dropdown render edilsin diye)
      setTimeout(() => {
        document.addEventListener('mousedown', handleFilterDropdownClickOutside);
      }, 100);
      
      // Tüm scroll olaylarını dinle (window ve tüm parent elementler)
      document.addEventListener('scroll', handleScroll, true); // true = capture phase
      window.addEventListener('scroll', handleScroll, true);
    }

    return () => {
      document.removeEventListener('mousedown', handleFilterDropdownClickOutside);
      document.removeEventListener('scroll', handleScroll, true);
      window.removeEventListener('scroll', handleScroll, true);
    };
  }, [activeFilterDropdown]);
  
  // Edit dropdown için click outside ve scroll handling
  useEffect(() => {
    if (!showEditDropdown) return;
    
    const handleEditDropdownClickOutside = (event) => {
      const isDropdownClick = event.target.closest('[data-edit-dropdown="true"]');
      const dropdownKey = `${showEditDropdown.rowId}-${showEditDropdown.columnId}`;
      const isButtonClick = editDropdownButtonRef.current[dropdownKey]?.contains(event.target);
      
      if (!isDropdownClick && !isButtonClick) {
        setShowEditDropdown(null);
      }
    };

    const handleEditDropdownScroll = () => {
      if (showEditDropdown) {
        const dropdownKey = `${showEditDropdown.rowId}-${showEditDropdown.columnId}`;
        const button = editDropdownButtonRef.current[dropdownKey];
        if (button) {
          const rect = button.getBoundingClientRect();
          setEditDropdownPosition({
            top: rect.bottom + 4,
            left: rect.left
          });
        }
      }
    };

    setTimeout(() => {
      document.addEventListener('mousedown', handleEditDropdownClickOutside);
    }, 100);
    
    document.addEventListener('scroll', handleEditDropdownScroll, true);
    window.addEventListener('scroll', handleEditDropdownScroll, true);

    return () => {
      document.removeEventListener('mousedown', handleEditDropdownClickOutside);
      document.removeEventListener('scroll', handleEditDropdownScroll, true);
      window.removeEventListener('scroll', handleEditDropdownScroll, true);
    };
  }, [showEditDropdown]);

  // Sütun seçici butonunu render et
  const renderColumnSelector = () => {
    return (
      <>
      <div 
        ref={columnSelectorRef}
        style={{
          width: '100%',
          height: '100%',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center'
        }}
      >
        <div 
            data-column-selector-button
            style={{
              width: '56px',
              height: '32px',
              borderRadius: '8px',
              backgroundColor: 'rgba(0, 123, 255, 0.15)',
              border: '1px solid rgba(0, 123, 255, 0.4)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
              boxShadow: pressedColumnSelector ? '0 1px 4px rgba(0,123,255,0.4), inset 0 1px 3px rgba(0,0,0,0.2)' : 
                         hoveredColumnSelector ? '0 2px 8px rgba(0,123,255,0.3), 0 1px 4px rgba(0,0,0,0.2)' : 
                         '0 1px 4px rgba(0,0,0,0.2)',
              transform: pressedColumnSelector ? 'scale(0.98)' : 
                         hoveredColumnSelector ? 'translateY(-1px)' : 'none',
              filter: hoveredColumnSelector ? 'brightness(1.15)' : 'brightness(1)',
            }}
          onClick={(e) => {
            e.stopPropagation();
            e.preventDefault();
              if (!showColumnSelector && columnSelectorRef.current) {
                const rect = columnSelectorRef.current.getBoundingClientRect();
                
                // Görünür sütun sayısına göre dropdown yüksekliğini tahmin et
                const visibleColumnCount = columnOrder.filter(columnId => {
                  if (columnId === 'id' || columnId === 'kullanici' || columnId === 'tarih') return false;
                  if (columnId === 'ekleyen_kullanici' && data.length > 0) {
                    const uniqueUsers = new Set(data.map(row => row.ekleyen_kullanici));
                    if (uniqueUsers.size <= 1) return false;
                  }
                  return true;
                }).length;
                
                const estimatedDropdownHeight = (visibleColumnCount * 35) + 20;
                const viewportHeight = window.innerHeight;
                const spaceBelow = viewportHeight - rect.bottom;
                const spaceAbove = rect.top;
                
                // Eğer aşağıda yeterli yer yoksa ve yukarıda daha fazla yer varsa, yukarı aç
                let top = rect.bottom + 4;
                if (spaceBelow < estimatedDropdownHeight && spaceAbove > spaceBelow) {
                  top = rect.top - estimatedDropdownHeight - 4;
                }
                
                setDropdownPosition({
                  top: top,
                  left: rect.left,
                });
              }
            setShowColumnSelector(!showColumnSelector);
            setActiveFilterDropdown(null);
          }}
            onMouseEnter={() => setHoveredColumnSelector(true)}
            onMouseLeave={() => setHoveredColumnSelector(false)}
            onMouseDown={(e) => {
              e.stopPropagation();
              setPressedColumnSelector(true);
            }}
            onMouseUp={() => setPressedColumnSelector(false)}
        >
          <span style={{
            fontSize: '18px',
            color: 'rgba(255, 255, 255, 0.9)',
            fontFamily: GLOBAL_FONT_FAMILY,
            userSelect: 'none',
            lineHeight: 1
          }}>
            ☰
          </span>
        </div>
        </div>
        {showColumnSelector && createPortal(
          <div 
            data-column-selector-dropdown
            style={{
              position: 'fixed',
              top: dropdownPosition.top,
              left: dropdownPosition.left,
              backgroundColor: 'rgba(20, 25, 30, 0.98)',
              borderRadius: '12px',
              padding: '6px',
              boxShadow: '0 8px 24px rgba(0,0,0,0.5), 0 4px 12px rgba(0,123,255,0.3), 0 0 20px rgba(0,123,255,0.2)',
              border: '1px solid rgba(0, 123, 255, 0.5)',
              zIndex: 99999,
              backdropFilter: 'blur(12px)',
              minWidth: '150px',
              pointerEvents: 'auto',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {columnOrder.filter(columnId => {
              // Her zaman gizlenen sütunlar: 'id', 'kullanici', 'tarih'
              if (columnId === 'id' || columnId === 'kullanici' || columnId === 'tarih') return false;
              
              // 'ekleyen_kullanici' sütununda sadece 1 benzersiz kullanıcı varsa gizle
              if (columnId === 'ekleyen_kullanici' && data.length > 0) {
                const uniqueUsers = new Set(data.map(row => row.ekleyen_kullanici));
                if (uniqueUsers.size <= 1) return false;
              }
              
              return true;
            }).map(columnId => {
              const isVisible = visibleColumns[columnId] !== false;
              
              return (
              <div
                key={columnId}
                data-column-selector-item
                  style={{
                    padding: '6px 10px',
                    cursor: draggedColumn === columnId ? 'grabbing' : 'grab',
                    transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
                    borderRadius: '8px',
                    marginBottom: '2px',
                    border: '1px solid transparent',
                    backgroundColor: 'transparent',
                    fontFamily: GLOBAL_FONT_FAMILY,
                    fontSize: 'clamp(11px, 2vw, 14px)',
                    color: 'rgba(255, 255, 255, 0.9)',
                    fontWeight: '400',
                    pointerEvents: 'auto',
                    userSelect: 'none',
                    display: 'flex',
                    alignItems: 'center',
                    gap: '8px',
                    opacity: draggedColumn === columnId ? 0.5 : 1
                  }}
                  onMouseEnter={(e) => {
                    e.currentTarget.style.backgroundColor = 'rgba(0, 123, 255, 0.15)';
                    e.currentTarget.style.border = '1px solid rgba(0, 123, 255, 0.3)';
                    e.currentTarget.style.boxShadow = '0 2px 8px rgba(0,123,255,0.2)';
                    e.currentTarget.style.transform = 'translateX(2px)';
                  }}
                  onMouseLeave={(e) => {
                    e.currentTarget.style.backgroundColor = 'transparent';
                    e.currentTarget.style.border = '1px solid transparent';
                    e.currentTarget.style.boxShadow = 'none';
                    e.currentTarget.style.transform = 'translateX(0)';
                  }}
                draggable
                onDragStart={(e) => handleDragStart(e, columnId)}
                onDragOver={(e) => handleDragOver(e, columnId)}
                onDragEnd={handleDragEnd}
              >
                <div 
                  draggable={false}
                  style={{
                    width: '16px',
                    height: '16px',
                    borderRadius: '4px',
                    backgroundColor: isVisible ? 'rgba(0, 123, 255, 0.8)' : 'transparent',
                    border: isVisible ? '1px solid rgba(0, 123, 255, 1)' : '1px solid rgba(255, 255, 255, 0.3)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    transition: 'all 0.3s ease',
                    cursor: 'pointer',
                    flexShrink: 0
                  }}
                  onClick={(e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    
                    // Sütun görünürlüğünü değiştir
                    setVisibleColumns(prev => {
                      const newState = { ...prev };
                      newState[columnId] = !prev[columnId];
                      
                      // En az bir sütun görünür olmalı
                      const visibleCount = Object.values(newState).filter(Boolean).length;
                      if (visibleCount === 0) {
                        return prev;
                      }
                      
                      return newState;
                    });
                  }}
                  onDragStart={(e) => {
                    // Checkbox'tan sürükleme başlatmayı engelle
                    e.preventDefault();
                    e.stopPropagation();
                  }}
                >
                    {isVisible && (
                      <span style={{ 
                        color: '#fff', 
                        fontSize: '12px', 
                        lineHeight: '16px',
                        fontWeight: 'bold'
                      }}>✓</span>
                    )}
                </div>
                  <span style={{
                    fontSize: '14px',
                    color: 'rgba(255, 255, 255, 0.4)',
                    marginRight: '4px',
                    pointerEvents: 'none',
                    lineHeight: '16px'
                  }}>⋮⋮</span>
                  <span style={{
                    flex: 1,
                    pointerEvents: 'none',
                  }}>
                  {columnId}
                </span>
              </div>
              );
            })}
          </div>,
          document.body
        )}
      </>
    );
  };

  // Görünür sütunları hesapla
  const visibleHeaders = columnOrder.filter(column => visibleColumns[column] !== false);

  // Toplam tablo genişliğini hesapla
  const totalTableWidth = 80 + visibleHeaders.reduce((sum, header) => {
    return sum + (columnWidths[header] || 280);
  }, 0);

  // Tablo başlığını render et
  const renderTableHeader = () => (
    <div style={{ ...styles.tableHeader, width: `${totalTableWidth}px` }}>
      {/* İşlemler Sütunu Başlığı */}
      <div 
        style={{
          ...styles.headerCell,
          width: '80px',
          minWidth: '80px',
          maxWidth: '80px',
          padding: '8px',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center'
        }}
      >
        {renderColumnSelector()}
      </div>
      
      {visibleHeaders.map((header, index) => {
        const columnWidth = columnWidths[header] || 280;
        return (
        <div 
          key={header} 
          style={{
            ...styles.headerCell,
            width: `${columnWidth}px`,
            minWidth: `${columnWidth}px`,
            maxWidth: `${columnWidth}px`,
            ...(index === visibleHeaders.length - 1 && { borderRightWidth: 0 }),
            ...(draggedColumn === header && { opacity: 0.5 }),
          }}
          draggable={true}
          onDragStart={(e) => handleDragStart(e, header)}
          onDragOver={(e) => handleDragOver(e, header)}
          onDragEnd={handleDragEnd}
          onDrop={(e) => handleDragEnd(e)}
        >
          <div 
            style={{ 
            display: 'flex', 
            alignItems: 'center', 
            justifyContent: 'center',
              cursor: 'pointer',
            width: '100%',
            height: '100%',
              userSelect: 'none',
              gap: '8px',
              position: 'relative'
            }}
            onClick={(e) => {
              e.stopPropagation();
              if (sortColumn === header) {
                // Aynı sütuna tekrar tıklanınca yönü değiştir
                setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
              } else {
                // Yeni sütun seçilince artan olarak başla
                setSortColumn(header);
                setSortDirection('asc');
              }
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.filter = 'brightness(1.1)';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.filter = 'brightness(1)';
            }}
          >
            <Text style={styles.tableHeaderCell}>{header}</Text>
            {sortColumn === header && (
              <span style={{
                fontSize: '12px',
                color: 'rgba(0, 123, 255, 0.8)',
                fontWeight: 'bold',
                display: 'inline-block',
                transition: 'transform 0.2s ease'
              }}>
                {sortDirection === 'asc' ? '↑' : '↓'}
              </span>
            )}
          </div>
          {renderFilter(header)}
        </div>
        );
      })}
    </div>
  );

  return (
    <div style={{
      backgroundColor: '#1A1F2580',
      borderRadius: '16px',
      width: `${totalTableWidth + 24}px`,
      maxWidth: '100%',
      margin: '0 auto',
      marginBottom: '16px',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      paddingLeft: '12px',
      paddingRight: '12px',
      paddingTop: '16px',
      paddingBottom: '16px',
      boxSizing: 'border-box',
      position: 'relative',
      zIndex: 1,
      overflow: 'hidden'
    }}>
      <div style={{ 
        width: `${totalTableWidth}px`,
        maxWidth: '100%',
        boxSizing: 'border-box',
        overflow: 'hidden'
      }}>
        <div style={{ 
          ...styles.tableControls, 
          justifyContent: 'flex-end',
          width: '100%',
          boxSizing: 'border-box',
          paddingLeft: '4px',
          paddingRight: '4px'
        }}>
          <div style={{ 
            ...styles.tableControlsRight,
            maxWidth: '100%',
            flexWrap: 'nowrap'
          }}>
          <View style={styles.rowsPerPageContainer}>
            <View style={styles.rowsPerPageSelect}>
              {rowsPerPageOptions.filter((option) => {
                const totalData = filteredData.length;
                if (option === 5) return true; // 5 her zaman görünür
                if (option === 10) return totalData > 5;
                if (option === 20) return totalData > 10;
                if (option === 50) return totalData > 20;
                if (option === 100) return totalData > 50;
                if (option === 'Hepsi') return totalData > 100;
                return true;
              }).map((option) => {
                const isActive = option === 'Hepsi' ? rowsPerPage === filteredData.length : rowsPerPage === option;
                const optionKey = String(option);
                
                return (
                <TouchableOpacity
                  key={option}
                  style={[
                    styles.rowsPerPageOption,
                      isActive && styles.rowsPerPageOptionActive,
                      hoveredRowsPerPage === optionKey && !isActive && {
                        transform: [{ translateY: -2 }],
                        filter: 'brightness(1.15)',
                        boxShadow: '0 4px 12px rgba(0,123,255,0.3), 0 2px 6px rgba(0,0,0,0.2)',
                      },
                      pressedRowsPerPage === optionKey && !isActive && {
                        transform: [{ translateY: 0 }, { scale: 0.98 }],
                        filter: 'brightness(1.25)',
                        boxShadow: '0 2px 8px rgba(0,123,255,0.4), inset 0 1px 3px rgba(0,0,0,0.2)',
                      }
                  ]}
                  onPress={() => handleRowsPerPageChange(option)}
                    onPressIn={() => setPressedRowsPerPage(optionKey)}
                    onPressOut={() => setPressedRowsPerPage(null)}
                    onMouseEnter={() => setHoveredRowsPerPage(optionKey)}
                    onMouseLeave={() => setHoveredRowsPerPage(null)}
                >
                  <Text style={[
                    styles.rowsPerPageOptionText,
                      isActive && styles.rowsPerPageOptionTextActive
                  ]}>
                    {option}
                  </Text>
                </TouchableOpacity>
                );
              })}
            </View>
          </View>
          <View style={styles.paginationControls}>
            <TouchableOpacity
              style={[
                styles.paginationButton, 
                currentPage === 1 && styles.paginationButtonDisabled,
                hoveredButton === 'first' && currentPage !== 1 && {
                  transform: [{ translateY: -2 }],
                  filter: 'brightness(1.15)',
                  boxShadow: '0 4px 12px rgba(0,123,255,0.3), 0 2px 6px rgba(0,0,0,0.2)',
                },
                pressedButton === 'first' && currentPage !== 1 && {
                  transform: [{ translateY: 0 }, { scale: 0.98 }],
                  filter: 'brightness(1.25)',
                  boxShadow: '0 2px 8px rgba(0,123,255,0.4), inset 0 1px 3px rgba(0,0,0,0.2)',
                  borderColor: '#007bff',
                }
              ]}
              onPress={() => handlePageChange(1)}
              onPressIn={() => setPressedButton('first')}
              onPressOut={() => setPressedButton(null)}
              onMouseEnter={() => setHoveredButton('first')}
              onMouseLeave={() => setHoveredButton(null)}
              disabled={currentPage === 1}
            >
              <Text style={styles.paginationButtonText}>{'<<'}</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.paginationButton, 
                currentPage === 1 && styles.paginationButtonDisabled,
                hoveredButton === 'prev' && currentPage !== 1 && {
                  transform: [{ translateY: -2 }],
                  filter: 'brightness(1.15)',
                  boxShadow: '0 4px 12px rgba(0,123,255,0.3), 0 2px 6px rgba(0,0,0,0.2)',
                },
                pressedButton === 'prev' && currentPage !== 1 && {
                  transform: [{ translateY: 0 }, { scale: 0.98 }],
                  filter: 'brightness(1.25)',
                  boxShadow: '0 2px 8px rgba(0,123,255,0.4), inset 0 1px 3px rgba(0,0,0,0.2)',
                  borderColor: '#007bff',
                }
              ]}
              onPress={() => handlePageChange(currentPage - 1)}
              onPressIn={() => setPressedButton('prev')}
              onPressOut={() => setPressedButton(null)}
              onMouseEnter={() => setHoveredButton('prev')}
              onMouseLeave={() => setHoveredButton(null)}
              disabled={currentPage === 1}
            >
              <Text style={styles.paginationButtonText}>{'<'}</Text>
            </TouchableOpacity>
            
            <Text style={styles.paginationText}>
              {currentPage} / {totalPages}
            </Text>
            
            <TouchableOpacity
              style={[
                styles.paginationButton, 
                currentPage === totalPages && styles.paginationButtonDisabled,
                hoveredButton === 'next' && currentPage !== totalPages && {
                  transform: [{ translateY: -2 }],
                  filter: 'brightness(1.15)',
                  boxShadow: '0 4px 12px rgba(0,123,255,0.3), 0 2px 6px rgba(0,0,0,0.2)',
                },
                pressedButton === 'next' && currentPage !== totalPages && {
                  transform: [{ translateY: 0 }, { scale: 0.98 }],
                  filter: 'brightness(1.25)',
                  boxShadow: '0 2px 8px rgba(0,123,255,0.4), inset 0 1px 3px rgba(0,0,0,0.2)',
                  borderColor: '#007bff',
                }
              ]}
              onPress={() => handlePageChange(currentPage + 1)}
              onPressIn={() => setPressedButton('next')}
              onPressOut={() => setPressedButton(null)}
              onMouseEnter={() => setHoveredButton('next')}
              onMouseLeave={() => setHoveredButton(null)}
              disabled={currentPage === totalPages}
            >
              <Text style={styles.paginationButtonText}>{'>'}</Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.paginationButton, 
                currentPage === totalPages && styles.paginationButtonDisabled,
                hoveredButton === 'last' && currentPage !== totalPages && {
                  transform: [{ translateY: -2 }],
                  filter: 'brightness(1.15)',
                  boxShadow: '0 4px 12px rgba(0,123,255,0.3), 0 2px 6px rgba(0,0,0,0.2)',
                },
                pressedButton === 'last' && currentPage !== totalPages && {
                  transform: [{ translateY: 0 }, { scale: 0.98 }],
                  filter: 'brightness(1.25)',
                  boxShadow: '0 2px 8px rgba(0,123,255,0.4), inset 0 1px 3px rgba(0,0,0,0.2)',
                  borderColor: '#007bff',
                }
              ]}
              onPress={() => handlePageChange(totalPages)}
              onPressIn={() => setPressedButton('last')}
              onPressOut={() => setPressedButton(null)}
              onMouseEnter={() => setHoveredButton('last')}
              onMouseLeave={() => setHoveredButton(null)}
              disabled={currentPage === totalPages}
            >
              <Text style={styles.paginationButtonText}>{'>>'}</Text>
            </TouchableOpacity>
          </View>
        </div>
        </div>
        <div style={{
          ...styles.tableWrapper,
          width: `${totalTableWidth}px`,
          maxWidth: '100%',
          boxSizing: 'border-box'
        }}>
        {renderTableHeader()}
        {/* Başlık ile veri satırları arasındaki ayırıcı çizgi */}
        <div style={{
          width: `${totalTableWidth}px`,
          height: '1px',
          backgroundColor: 'rgba(255, 255, 255, 0.2)',
          margin: '0',
          boxShadow: '0 1px 2px rgba(0, 0, 0, 0.1)'
        }} />
        <div style={{ ...styles.tableBody, width: `${totalTableWidth}px` }}>
          {currentData.map((row, rowIndex) => {
            const isHovered = hoveredRow === rowIndex;
            const isPressed = pressedRow === rowIndex;
            
            // Hover ve pressed durumları için dinamik stil
            const rowDynamicStyle = isPressed ? {
              transform: 'scale(0.99)',
              filter: 'brightness(1.25)',
              boxShadow: '0 2px 8px rgba(0,123,255,0.4), inset 0 1px 3px rgba(0,0,0,0.2)',
              transition: 'all 0.1s ease',
            } : isHovered ? {
              transform: 'translateY(-1px)',
              filter: 'brightness(1.15)',
              boxShadow: '0 4px 12px rgba(0,123,255,0.3), 0 2px 6px rgba(0,0,0,0.2)',
              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
            } : {
              transition: 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
            };
            
            const isEditing = editingRowId === row.id;
            
            return (
              <div 
                key={rowIndex} 
                style={{
              ...styles.tableRow,
              ...(rowIndex % 2 === 0 ? styles.tableRowEven : styles.tableRowOdd),
                  width: `${totalTableWidth}px`,
                  ...(rowIndex === currentData.length - 1 && { borderBottomWidth: 0 }),
                  ...rowDynamicStyle
                }}
                onMouseEnter={() => setHoveredRow(rowIndex)}
                onMouseLeave={() => setHoveredRow(null)}
                onMouseDown={() => setPressedRow(rowIndex)}
                onMouseUp={() => setPressedRow(null)}
              >
                {/* İşlemler Sütunu: Düzenleme ve Silme */}
                <div 
                  style={{
                    ...styles.tableCell,
                    width: '80px',
                    minWidth: '80px',
                    maxWidth: '80px',
                    padding: '2px',
                    display: 'flex',
                    flexDirection: 'row',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: '4px'
                  }}
                >
                  {isEditing ? (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '2px', width: '100%' }}>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleSaveEdit();
                        }}
                        style={{
                          width: '100%',
                          padding: '3px 4px',
                          borderRadius: '4px',
                          border: '1px solid rgba(40, 167, 69, 0.4)',
                          backgroundColor: 'rgba(40, 167, 69, 0.2)',
                          color: 'rgba(40, 167, 69, 0.9)',
                          fontFamily: GLOBAL_FONT_FAMILY,
                          fontSize: '10px',
                          cursor: 'pointer',
                          outline: 'none'
                        }}
                      >
                        ✓ Kaydet
                      </button>
                      <button
                        onClick={(e) => {
                          e.stopPropagation();
                          handleCancelEdit();
                        }}
                        style={{
                          width: '100%',
                          padding: '3px 4px',
                          borderRadius: '4px',
                          border: '1px solid rgba(220, 53, 69, 0.4)',
                          backgroundColor: 'rgba(220, 53, 69, 0.2)',
                          color: 'rgba(220, 53, 69, 0.9)',
                          fontFamily: GLOBAL_FONT_FAMILY,
                          fontSize: '10px',
                          cursor: 'pointer',
                          outline: 'none'
                        }}
                      >
                        ✕ İptal
                      </button>
                    </div>
                  ) : (
                    <>
                      <span 
                        onClick={(e) => {
                          e.stopPropagation();
                          handleEdit(row);
                        }}
                        style={{ 
                          fontSize: '18px',
                          color: 'rgba(0, 123, 255, 0.9)',
                          userSelect: 'none',
                          cursor: 'pointer'
                        }}
                      >
                        ✏️
                      </span>
                      <span 
                        onClick={(e) => {
                          e.stopPropagation();
                          handleDeleteClick(row.id);
                        }}
                        style={{ 
                          fontSize: '18px',
                          color: 'rgba(220, 53, 69, 0.9)',
                          userSelect: 'none',
                          cursor: 'pointer'
                        }}
                      >
                        🗑️
                      </span>
                    </>
                  )}
                </div>
                
                {visibleHeaders.map((header, colIndex) => {
                  const columnWidth = columnWidths[header] || 280;
                  return (
                <div 
                  key={header} 
                  style={{
                    ...styles.tableCell,
                      width: `${columnWidth}px`,
                      minWidth: `${columnWidth}px`,
                      maxWidth: `${columnWidth}px`,
                    ...(colIndex === visibleHeaders.length - 1 && { borderRightWidth: 0 })
                  }}
                >
                    {renderCell(row[header], header, row.id, isEditing)}
                </div>
                  );
                })}
            </div>
            );
          })}
        </div>
      </div>
      </div>
      
      {/* Alan Çakışması Onay Modalı */}
      {showFieldConflictModal && fieldConflictData && (
        <div 
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 10001
          }}
          onClick={fieldConflictData.onCancel}
        >
          <div 
            style={{
              backgroundColor: 'rgba(30, 40, 50, 0.98)',
              border: '1px solid rgba(255, 193, 7, 0.5)',
              borderRadius: '16px',
              padding: '24px',
              maxWidth: '400px',
              boxShadow: '0 8px 32px rgba(255, 193, 7, 0.3), 0 0 0 1px rgba(255, 193, 7, 0.1)',
              fontFamily: GLOBAL_FONT_FAMILY
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ textAlign: 'center', marginBottom: '20px' }}>
              <span style={{ fontSize: '48px' }}>⚠️</span>
            </div>
            <h3 style={{ 
              color: 'rgba(255, 193, 7, 0.95)', 
              fontSize: 'clamp(16px, 3vw, 20px)',
              marginBottom: '12px',
              textAlign: 'center',
              fontWeight: 'bold'
            }}>
              Dikkat!
            </h3>
            <p style={{ 
              color: 'rgba(255, 255, 255, 0.8)', 
              fontSize: 'clamp(13px, 2.5vw, 15px)',
              marginBottom: '24px',
              textAlign: 'center'
            }}>
              {fieldConflictData.message}
            </p>
            <div style={{ 
              display: 'flex', 
              gap: '12px',
              justifyContent: 'center'
            }}>
              <button
                onClick={fieldConflictData.onConfirm}
                style={{
                  padding: '10px 24px',
                  borderRadius: '8px',
                  border: '1px solid rgba(255, 193, 7, 0.5)',
                  backgroundColor: 'rgba(255, 193, 7, 0.2)',
                  color: 'rgba(255, 193, 7, 0.95)',
                  fontFamily: GLOBAL_FONT_FAMILY,
                  fontSize: 'clamp(13px, 2.5vw, 15px)',
                  cursor: 'pointer',
                  outline: 'none',
                  fontWeight: 'bold',
                  transition: 'all 0.3s ease'
                }}
                onMouseEnter={(e) => {
                  e.target.style.backgroundColor = 'rgba(255, 193, 7, 0.3)';
                  e.target.style.transform = 'translateY(-2px)';
                  e.target.style.boxShadow = '0 4px 12px rgba(255, 193, 7, 0.4)';
                }}
                onMouseLeave={(e) => {
                  e.target.style.backgroundColor = 'rgba(255, 193, 7, 0.2)';
                  e.target.style.transform = 'translateY(0)';
                  e.target.style.boxShadow = 'none';
                }}
              >
                Evet, Onayla
              </button>
              <button
                onClick={fieldConflictData.onCancel}
                style={{
                  padding: '10px 24px',
                  borderRadius: '8px',
                  border: '1px solid rgba(255, 255, 255, 0.3)',
                  backgroundColor: 'rgba(255, 255, 255, 0.1)',
                  color: 'rgba(255, 255, 255, 0.9)',
                  fontFamily: GLOBAL_FONT_FAMILY,
                  fontSize: 'clamp(13px, 2.5vw, 15px)',
                  cursor: 'pointer',
                  outline: 'none',
                  transition: 'all 0.3s ease'
                }}
                onMouseEnter={(e) => {
                  e.target.style.backgroundColor = 'rgba(255, 255, 255, 0.2)';
                  e.target.style.transform = 'translateY(-2px)';
                  e.target.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.3)';
                }}
                onMouseLeave={(e) => {
                  e.target.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                  e.target.style.transform = 'translateY(0)';
                  e.target.style.boxShadow = 'none';
                }}
              >
                İptal
              </button>
            </div>
          </div>
        </div>
      )}
      
      {/* Silme Onay Modalı */}
      {showDeleteConfirm && (
        <div 
          style={{
            position: 'fixed',
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            backgroundColor: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 10000
          }}
          onClick={handleCancelDelete}
        >
          <div 
            style={{
              backgroundColor: 'rgba(30, 40, 50, 0.98)',
              border: '1px solid rgba(220, 53, 69, 0.5)',
              borderRadius: '16px',
              padding: '24px',
              maxWidth: '400px',
              boxShadow: '0 8px 32px rgba(220, 53, 69, 0.3), 0 0 0 1px rgba(220, 53, 69, 0.1)',
              fontFamily: GLOBAL_FONT_FAMILY
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ textAlign: 'center', marginBottom: '20px' }}>
              <span style={{ fontSize: '48px' }}>⚠️</span>
            </div>
            <h3 style={{ 
              color: 'rgba(220, 53, 69, 0.95)', 
              fontSize: 'clamp(16px, 3vw, 20px)',
              marginBottom: '12px',
              textAlign: 'center',
              fontWeight: 'bold'
            }}>
              Silmek İstediğinize Emin Misiniz?
            </h3>
            <p style={{ 
              color: 'rgba(255, 255, 255, 0.8)', 
              fontSize: 'clamp(13px, 2.5vw, 15px)',
              marginBottom: '24px',
              textAlign: 'center'
            }}>
              Bu işlem geri alınamaz. Kayıt kalıcı olarak silinecektir.
            </p>
            <div style={{ 
              display: 'flex', 
              gap: '12px',
              justifyContent: 'center'
            }}>
              <button
                onClick={handleConfirmDelete}
                style={{
                  padding: '10px 24px',
                  borderRadius: '8px',
                  border: '1px solid rgba(220, 53, 69, 0.5)',
                  backgroundColor: 'rgba(220, 53, 69, 0.2)',
                  color: 'rgba(220, 53, 69, 0.95)',
                  fontFamily: GLOBAL_FONT_FAMILY,
                  fontSize: 'clamp(13px, 2.5vw, 15px)',
                  cursor: 'pointer',
                  outline: 'none',
                  fontWeight: 'bold',
                  transition: 'all 0.3s ease'
                }}
                onMouseEnter={(e) => {
                  e.target.style.backgroundColor = 'rgba(220, 53, 69, 0.3)';
                  e.target.style.transform = 'translateY(-2px)';
                  e.target.style.boxShadow = '0 4px 12px rgba(220, 53, 69, 0.4)';
                }}
                onMouseLeave={(e) => {
                  e.target.style.backgroundColor = 'rgba(220, 53, 69, 0.2)';
                  e.target.style.transform = 'translateY(0)';
                  e.target.style.boxShadow = 'none';
                }}
              >
                Evet, Sil
              </button>
              <button
                onClick={handleCancelDelete}
                style={{
                  padding: '10px 24px',
                  borderRadius: '8px',
                  border: '1px solid rgba(255, 255, 255, 0.3)',
                  backgroundColor: 'rgba(255, 255, 255, 0.1)',
                  color: 'rgba(255, 255, 255, 0.9)',
                  fontFamily: GLOBAL_FONT_FAMILY,
                  fontSize: 'clamp(13px, 2.5vw, 15px)',
                  cursor: 'pointer',
                  outline: 'none',
                  transition: 'all 0.3s ease'
                }}
                onMouseEnter={(e) => {
                  e.target.style.backgroundColor = 'rgba(255, 255, 255, 0.2)';
                  e.target.style.transform = 'translateY(-2px)';
                  e.target.style.boxShadow = '0 4px 12px rgba(0, 0, 0, 0.3)';
                }}
                onMouseLeave={(e) => {
                  e.target.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                  e.target.style.transform = 'translateY(0)';
                  e.target.style.boxShadow = 'none';
                }}
              >
                İptal
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default DataTable;
