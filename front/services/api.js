// front/services/api.js
// API Base URL - Environment variable'dan al, yoksa relative path kullan
// Production'da: nginx proxy üzerinden /api'ye yönlendirilir
// Development'da: localhost:5000/api kullanılır
const getBaseUrl = () => {
  // Build time'da inject edilen env var (webpack DefinePlugin ile)
  if (typeof process !== 'undefined' && process.env && process.env.REACT_APP_API_URL) {
    return process.env.REACT_APP_API_URL;
  }
  // Runtime'da window üzerinden (index.html'de tanımlanabilir)
  if (typeof window !== 'undefined' && window.REACT_APP_API_URL) {
    return window.REACT_APP_API_URL;
  }
  // Fallback: Same origin relative path (production nginx proxy için)
  // veya development'ta localhost
  if (typeof window !== 'undefined' && window.location.hostname !== 'localhost') {
    return '/api';  // Production: nginx proxy kullan
  }
  return 'http://localhost:5000/api';  // Development fallback
};

const BASE_URL = getBaseUrl();

// Development modunda console logları göster
const isDevelopment = process.env.NODE_ENV === 'development';

const debugLog = (...args) => {
  if (isDevelopment) {
    console.log(...args);
  }
};

const debugError = (...args) => {
  if (isDevelopment) {
    console.error(...args);
  }
};

// Token işlemleri
const getToken = () => {
  try {
    return localStorage.getItem('token');
  } catch (error) {
    debugError('Token alınamadı:', error);
    return null;
  }
};

const setToken = (token) => {
  try {
    localStorage.setItem('token', token);
  } catch (error) {
    debugError('Token kaydedilemedi:', error);
  }
};

const removeToken = () => {
  try {
    localStorage.removeItem('token');
  } catch (error) {
    debugError('Token silinemedi:', error);
  }
};

// Yeni token kontrolü ve güncelleme
const checkAndUpdateToken = (response) => {
  const newToken = response.headers.get('New-Token');
  if (newToken) {
    setToken(newToken);
    debugLog('Token yenilendi');
  }
};

// API istekleri için ortak header'ları oluştur
const getHeaders = () => {
  const headers = { 
    'Content-Type': 'application/json',
    'Accept': 'application/json'
  };

  const token = getToken();
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }

  return headers;
};

// API isteği yap ve token kontrolü
const makeRequest = async (url, options) => {
  try {
    const response = await fetch(url, options);
    
    // Yeni token varsa güncelle
    checkAndUpdateToken(response);
    
    if (!response.ok) {
      if (response.status === 0) {
        throw new Error('Sunucu bağlantısı başarısız oldu. Lütfen internet bağlantınızı ve sunucunun çalıştığını kontrol edin.');
      }
      
      if (response.status === 401) {
        // Token hatası - kullanıcıyı logout yap
        removeToken();
        window.location.href = '/login';
        throw new Error('Oturum süresi doldu. Lütfen tekrar giriş yapın.');
      }
      
      const errorData = await response.json();
      throw new Error(errorData.error || `HTTP error! status: ${response.status}`);
    }
    
    return response;
  } catch (error) {
    debugError('API Error:', error);
    throw error;
  }
};

export const postData = async (endpoint, data) => {
  try {
    debugLog('POST isteği:', `${BASE_URL}/${endpoint}`, data);
    
    const response = await makeRequest(`${BASE_URL}/${endpoint}`, {
      method: 'POST',
      headers: getHeaders(),
      body: JSON.stringify(data)
    });
    
    const responseData = await response.json();
    debugLog('POST yanıtı:', responseData);

    if (endpoint === 'kullanicilar/validate' && responseData.success && responseData.data.token) {
      setToken(responseData.data.token);
    }

    return responseData;
  } catch (error) {
    debugError('API Error:', error);
    throw error;
  }
};

export const fetchData = async (endpoint) => {
  try {
    const url = `${BASE_URL}/${endpoint}`;
    debugLog('GET isteği:', url);
    
    const response = await makeRequest(url, {
      method: 'GET',
      headers: getHeaders()
    });
    
    const data = await response.json();
    debugLog('GET yanıtı:', data);
    return data;
  } catch (error) {
    debugError('API Error:', error);
    throw error;
  }
};

export const updateData = async (endpoint, id, data) => {
  try {
    const url = `${BASE_URL}/${endpoint}/${id}`;
    debugLog('PUT isteği:', url, data);
    
    const response = await makeRequest(url, {
      method: 'PUT',
      headers: getHeaders(),
      body: JSON.stringify(data)
    });
    
    const responseData = await response.json();
    debugLog('PUT yanıtı:', responseData);
    return responseData;
  } catch (error) {
    debugError('API Error:', error);
    throw error;
  }
};

export const deleteData = async (endpoint, id) => {
  try {
    const url = `${BASE_URL}/${endpoint}/${id}`;
    debugLog('DELETE isteği:', url);
    
    const response = await makeRequest(url, {
      method: 'DELETE',
      headers: getHeaders()
    });
    
    const responseData = await response.json();
    debugLog('DELETE yanıtı:', responseData);
    return responseData;
  } catch (error) {
    debugError('API Error:', error);
    throw error;
  }
};