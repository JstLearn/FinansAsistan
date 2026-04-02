import React, { useState, useEffect } from 'react';
import { Modal, View, Text, TextInput, TouchableOpacity, StyleSheet } from 'react-native';
import { useUser } from '../context/UserContext';
import { GLOBAL_FONT_FAMILY } from '../styles/styles';

// Use relative URL in production (nginx proxy), localhost in development
const API_BASE_URL = window.location.hostname === 'localhost' ? 'http://localhost:5000' : '';

const LoginModal = ({ visible, onClose, onSuccess }) => {
  const { setUser } = useUser();
  const [email, setEmail] = useState('');
  const [isValidEmail, setIsValidEmail] = useState(false);
  const [password, setPassword] = useState('');
  const [passwordChecks, setPasswordChecks] = useState({
    length: false,
    upperCase: false,
    lowerCase: false,
    number: false,
    special: false
  });
  const [verificationCode, setVerificationCode] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [showVerification, setShowVerification] = useState(false);
  const [showResetPassword, setShowResetPassword] = useState(false);
  const [newPassword, setNewPassword] = useState('');
  const [isValidCode, setIsValidCode] = useState(false);
  const [isCodeVerified, setIsCodeVerified] = useState(false);
  const [countdown, setCountdown] = useState(0);
  const [isLocked, setIsLocked] = useState(false);
  const [isButtonHovered, setIsButtonHovered] = useState(false);
  const [isButtonPressed, setIsButtonPressed] = useState(false);

  useEffect(() => {
    if (visible) {
      setEmail('');
      setPassword('');
      setVerificationCode('');
      setError('');
      setSuccessMessage('');
      setShowVerification(false);
      setShowResetPassword(false);
      setIsCodeVerified(false);
      setIsValidCode(false);
      setIsLocked(false);
      setCountdown(0);
    }
  }, [visible]);

  useEffect(() => {
    let timer;
    if (countdown > 0) {
      timer = setInterval(() => {
        setCountdown(prev => prev - 1);
      }, 1000);
    } else if (countdown === 0) {
      setIsLocked(false);
    }
    return () => clearInterval(timer);
  }, [countdown]);

  const resetForm = () => {
    setEmail('');
    setPassword('');
    setVerificationCode('');
    setError('');
    setSuccessMessage('');
    setShowVerification(false);
  };

  const verifyCode = async (code, isPasswordReset = false) => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/kullanicilar/verify`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          email: email,
          code: code
        })
      });

      const data = await response.json();
      
      // Rate limit kontrolü
      if (response.status === 429) {
        setError(data.message);
        setIsValidCode(false);
        setIsLocked(true);
        setCountdown(60);
        setVerificationCode('');
        return false;
      }

      const isValid = data.success;
      setIsValidCode(isValid);
      
      if (isValid) {
        setIsCodeVerified(true);
        if (!isPasswordReset && data.data?.token) {
          localStorage.setItem('token', data.data.token);
          setUser({
            username: email,
            token: data.data.token
          });
          onSuccess();
          onClose();
        }
      } else {
        setError(data.message || 'Geçersiz doğrulama kodu');
      }
      return isValid;
    } catch (error) {
      setIsValidCode(false);
      setError('Doğrulama sırasında bir hata oluştu');
      return false;
    }
  };

  const renderVerificationInput = (isPasswordReset = false) => (
    <View style={styles.inputContainer}>
      <TextInput
        style={[
          styles.input,
          verificationCode && (isValidCode ? styles.validInput : styles.invalidInput),
          isLocked && styles.lockedInput
        ]}
        placeholder={isLocked ? `${countdown} saniye bekleyin...` : "Doğrulama Kodu"}
        value={verificationCode}
        onChangeText={async (text) => {
          if (!isLocked && !isCodeVerified) {
            setError('');
            setVerificationCode(text);
            if (text.length === 6) {
              await verifyCode(text, isPasswordReset);
            } else {
              setIsValidCode(false);
            }
          }
        }}
        keyboardType="number-pad"
        maxLength={6}
        autoComplete="off"
        textContentType="none"
        editable={!isLocked && !isCodeVerified}
      />
      {isLocked && (
        <Text style={styles.countdownText}>
          {countdown}
        </Text>
      )}
    </View>
  );

  const checkPassword = (password) => {
    const checks = {
      length: password.length >= 8,
      upperCase: /[A-Z]/.test(password),
      lowerCase: /[a-z]/.test(password),
      number: /\d/.test(password),
      special: /[!@#$%^&*(),.?":{}|<>-]/.test(password)
    };
    setPasswordChecks(checks);
    return Object.values(checks).every(check => check);
  };

  const getButtonStyle = () => {
    if (isButtonPressed) {
      return {
        transform: [{ translateY: -1 }, { scale: 0.98 }],
        boxShadow: '0 5px 15px rgba(0,0,0,0.4), inset 0 3px 10px rgba(0,37,87,0.6)',
        backgroundColor: '#002557',
        border: 'clamp(2px, 0.3vw, 3px) solid #002557',
        borderRadius: 'clamp(10px, 2.5vw, 25px)',
        overflow: 'hidden',
      };
    }
    if (isButtonHovered) {
      return {
        transform: [{ translateY: -4 }, { scale: 1.05 }],
        boxShadow: `0 16px 38px rgba(0,123,255,0.4),
                    0 8px 18px rgba(0,0,0,0.3),
                    0 0 25px rgba(0,123,255,0.2),
                    inset 0 2px 8px rgba(0,86,179,0.25)`,
        backgroundColor: '#0056b3',
        border: 'clamp(2px, 0.3vw, 3px) solid #0056b3',
        borderRadius: 'clamp(10px, 2.5vw, 25px)',
        overflow: 'hidden',
      };
    }
    return {};
  };

  const validateEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
  };

  const handleSubmit = async () => {
    try {
      setLoading(true);
      setError('');
      setSuccessMessage('');

      if (!email || !password) {
        setError('Lütfen e-posta ve şifre alanlarını doldurun');
        return;
      }

      if (!Object.values(passwordChecks).every(check => check)) {
        setError('Lütfen tüm şifre gereksinimlerini karşılayın');
        return;
      }

      // Önce giriş dene
      const loginResponse = await fetch(`${API_BASE_URL}/api/kullanicilar/validate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          kullanici: email,
          sifre: password
        })
      });
      
      const loginData = await loginResponse.json();

      if (loginData.success) {
        // Giriş başarılı
        if (loginData.data && loginData.data.token) {
          localStorage.setItem('token', loginData.data.token);
          setUser({
            username: email,
            token: loginData.data.token
          });
          onSuccess();
          onClose();
        } else {
          setError('Giriş yapılamadı: Sunucudan geçerli bir yanıt alınamadı');
        }
      } else {
        // Giriş başarısız, otomatik kayıt yap
        const registerResponse = await fetch(`${API_BASE_URL}/api/kullanicilar`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            kullanici: email,
            sifre: password
          })
        });
        
        const registerData = await registerResponse.json();

        if (registerData.success) {
          if (registerData.message.includes('Yeni doğrulama kodu')) {
            setSuccessMessage('Hesabınız zaten mevcut ama doğrulanmamış. Yeni doğrulama kodu e-posta adresinize gönderildi.');
          } else {
            setSuccessMessage('Doğrulama kodu e-posta adresinize gönderildi');
          }
          setShowVerification(true);
        } else {
          setError(registerData.message || 'Kayıt işlemi başarısız oldu.');
        }
      }
    } catch (error) {
      setError('Sunucu bağlantısı başarısız oldu. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.');
    } finally {
      setLoading(false);
    }
  };

  const renderPasswordRequirements = () => {
    if ((password && !showVerification) || (showResetPassword && newPassword)) {
      return [
        { key: 'length', text: 'En az 8 karakter' },
        { key: 'upperCase', text: 'En az bir büyük harf' },
        { key: 'lowerCase', text: 'En az bir küçük harf' },
        { key: 'number', text: 'En az bir rakam' },
        { key: 'special', text: 'En az bir özel karakter (!@#$%^&*(),.?":{}|<>-)' }
      ].map(req => (
        <Text
          key={req.key}
          style={[
            styles.requirementText,
            passwordChecks[req.key] ? styles.validRequirement : styles.invalidRequirement
          ]}
        >
          • {req.text}
        </Text>
      ));
    }
    return null;
  };

  const handleForgotPassword = async () => {
    try {
      setLoading(true);
      setError('');
      setIsCodeVerified(false);
      setIsValidCode(false);
      setVerificationCode('');
      setIsLocked(false);
      setCountdown(0);

      if (!email) {
        setError('Lütfen e-posta adresinizi girin');
        return;
      }

      if (!validateEmail(email)) {
        setError('Lütfen geçerli bir e-posta adresi girin');
        return;
      }

      const response = await fetch(`${API_BASE_URL}/api/kullanicilar/forgot-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          kullanici: email
        })
      });

      const data = await response.json();

      if (data.success) {
        setSuccessMessage(data.message);
        setShowResetPassword(true);
      } else {
        setError(data.message);
      }
    } catch (error) {
      setError('Parola sıfırlama işlemi sırasında bir hata oluştu');
    } finally {
      setLoading(false);
    }
  };

  const handleResetPassword = async () => {
    try {
      setLoading(true);
      setError('');

      if (!verificationCode || !newPassword) {
        setError('Lütfen tüm alanları doldurun');
        return;
      }

      if (!Object.values(passwordChecks).every(check => check)) {
        setError('Lütfen tüm şifre gereksinimlerini karşılayın');
        return;
      }

      const response = await fetch(`${API_BASE_URL}/api/kullanicilar/reset-password`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          kullanici: email,
          code: verificationCode,
          yeniSifre: newPassword
        })
      });

      const data = await response.json();

      // Rate limit kontrolü
      if (response.status === 429) {
        setError(data.message);
        setIsValidCode(false);
        setIsLocked(true);
        setCountdown(60); // 60 saniyelik sayaç başlat
        setVerificationCode(''); // Input'u temizle
        return;
      }

      if (data.success) {
        setSuccessMessage('Parolanız başarıyla güncellendi');
        
        // Otomatik giriş yap
        const loginResponse = await fetch(`${API_BASE_URL}/api/kullanicilar/validate`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify({
            kullanici: email,
            sifre: newPassword
          })
        });

        const loginData = await loginResponse.json();

        if (loginData.success) {
          localStorage.setItem('token', loginData.data.token);
          setUser({
            username: email,
            token: loginData.data.token
          });
          onSuccess();
          onClose();
        }
      } else {
        setError(data.message);
      }
    } catch (error) {
      setError('Parola güncellenirken bir hata oluştu');
    } finally {
      setLoading(false);
    }
  };

  const handleBackToLogin = () => {
    setShowResetPassword(false);
    setError('');
    setSuccessMessage('');
    setIsCodeVerified(false);
    setIsValidCode(false);
    setVerificationCode('');
    setIsLocked(false);
    setCountdown(0);
  };

  return (
    <Modal
      visible={visible}
      transparent={true}
      animationType="fade"
    >
      <View style={styles.modalContainer}>
        <View style={styles.modalContent}>
          <TouchableOpacity style={styles.closeButton} onPress={onClose}>
            <Text style={styles.closeButtonText}>×</Text>
          </TouchableOpacity>
          
          {showResetPassword && (
            <TouchableOpacity style={styles.backButton} onPress={handleBackToLogin}>
              <Text style={styles.backButtonText}>←</Text>
            </TouchableOpacity>
          )}
          
          <Text style={styles.title}>
            {showResetPassword ? 'Parola Sıfırlama' : 'Kullanıcı Girişi'}
          </Text>
          
          {error ? <Text style={styles.errorText}>{error}</Text> : null}
          {successMessage ? <Text style={styles.successText}>{successMessage}</Text> : null}
          
          {showResetPassword ? (
            <>
              {renderVerificationInput(true)}
              <TextInput
                style={[
                  styles.input,
                  newPassword && (Object.values(passwordChecks).every(check => check) ? styles.validInput : styles.invalidInput)
                ]}
                placeholder="Yeni Şifre"
                value={newPassword}
                onChangeText={(text) => {
                  setNewPassword(text);
                  checkPassword(text);
                }}
                secureTextEntry
                autoComplete="new-password"
                textContentType="newPassword"
                passwordRules="minlength: 8; required: upper; required: lower; required: digit; required: [-]"
              />
              {newPassword && renderPasswordRequirements()}
              <TouchableOpacity 
                style={[styles.button, loading && styles.buttonDisabled, getButtonStyle()]} 
                onPress={handleResetPassword}
                disabled={loading || isLocked}
                onPressIn={() => setIsButtonPressed(true)}
                onPressOut={() => setIsButtonPressed(false)}
                onMouseEnter={() => setIsButtonHovered(true)}
                onMouseLeave={() => setIsButtonHovered(false)}
                activeOpacity={0.8}
              >
                <Text style={styles.buttonText}>
                  {loading ? 'İşleniyor...' : 'Şifreyi Güncelle'}
                </Text>
              </TouchableOpacity>
            </>
          ) : showVerification ? (
            <>
              {renderVerificationInput(false)}
              {!isCodeVerified && !isLocked && (
                <TouchableOpacity 
                  style={[styles.button, loading && styles.buttonDisabled, getButtonStyle()]} 
                  onPress={() => verifyCode(verificationCode)}
                  disabled={loading || !verificationCode}
                  onPressIn={() => setIsButtonPressed(true)}
                  onPressOut={() => setIsButtonPressed(false)}
                  onMouseEnter={() => setIsButtonHovered(true)}
                  onMouseLeave={() => setIsButtonHovered(false)}
                  activeOpacity={0.8}
                >
                  <Text style={styles.buttonText}>
                    {loading ? 'İşleniyor...' : 'Doğrula'}
                  </Text>
                </TouchableOpacity>
              )}
            </>
          ) : (
            <View style={styles.formContainer}>
              <TextInput
                style={[
                  styles.input,
                  email && (isValidEmail ? styles.validInput : styles.invalidInput)
                ]}
                placeholder="E-posta Adresi"
                value={email}
                onChangeText={(text) => {
                  setEmail(text);
                  setIsValidEmail(validateEmail(text));
                  setError('');
                  setSuccessMessage('');
                }}
                keyboardType="email-address"
                autoCapitalize="none"
              />

              <TextInput
                style={[
                  styles.input,
                  password && (Object.values(passwordChecks).every(check => check) ? styles.validInput : styles.invalidInput)
                ]}
                placeholder="Şifre"
                value={password}
                onChangeText={(text) => {
                  setPassword(text);
                  checkPassword(text);
                }}
                secureTextEntry
                autoComplete="new-password"
                textContentType="newPassword"
                passwordRules="minlength: 8; required: upper; required: lower; required: digit; required: [-]"
              />

              {renderPasswordRequirements()}

              <TouchableOpacity
                style={styles.forgotPasswordButton}
                onPress={handleForgotPassword}
              >
                <Text style={styles.forgotPasswordText}>
                  Parolamı Unuttum
                </Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.button, loading && styles.buttonDisabled, getButtonStyle()]}
                onPress={handleSubmit}
                disabled={loading}
                onPressIn={() => setIsButtonPressed(true)}
                onPressOut={() => setIsButtonPressed(false)}
                onMouseEnter={() => setIsButtonHovered(true)}
                onMouseLeave={() => setIsButtonHovered(false)}
                activeOpacity={0.8}
              >
                <Text style={styles.buttonText}>
                  {loading ? 'İşleniyor...' : 'Giriş | Kayıt'}
                </Text>
              </TouchableOpacity>
            </View>
          )}
        </View>
      </View>
    </Modal>
  );
};

const styles = StyleSheet.create({
  modalContainer: {
    flex: 1,
    backgroundColor: 'rgba(0, 0, 0, 0.7)',
    justifyContent: 'center',
    alignItems: 'center',
  },
  modalContent: {
    backgroundColor: '#1a1f25',
    padding: 24,
    borderRadius: 16,
    width: '90%',
    maxWidth: 380,
    borderWidth: 1,
    borderColor: 'rgba(255, 255, 255, 0.1)',
    position: 'relative',
    overflow: 'visible',
    alignItems: 'stretch',
  },
  closeButton: {
    position: 'absolute',
    right: 16,
    top: 16,
    minWidth: 44, // Dokunmatik ekran için minimum dokunma alanı (Apple'ın önerisi)
    minHeight: 44, // Dokunmatik ekran için minimum dokunma alanı
    padding: 10, // Tıklanabilir alanı genişlet
    justifyContent: 'center',
    alignItems: 'center',
    display: 'flex',
    zIndex: 1000, // Çok yüksek z-index - tüm içeriğin üstünde olsun
    backgroundColor: 'rgba(26, 31, 37, 0.9)', // Arka plan rengi ile görünürlük
    borderRadius: 22, // Yarı genişlik/yükseklik kadar border-radius (22 = 44/2)
    // Dokunmatik cihazlar için daha iyi tıklanabilirlik
    cursor: 'pointer',
  },
  closeButtonText: {
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    opacity: 0.7,
    lineHeight: 24, // Text'in dikey olarak tam merkezlenmesi için
    textAlign: 'center',
  },
  title: {
    fontFamily: GLOBAL_FONT_FAMILY,
    fontSize: 20,
    fontWeight: 'bold',
    marginBottom: 24,
    textAlign: 'center',
    color: '#fff',
    paddingRight: 60, // Close button alanı için boşluk (44px button + 16px right margin)
    paddingLeft: 60, // Back button için de simetrik boşluk
    position: 'relative',
    zIndex: 1, // Close button'un üstünde kalmasını sağla
  },
  input: {
    fontFamily: GLOBAL_FONT_FAMILY,
    backgroundColor: 'rgba(255, 255, 255, 0.12)',
    borderWidth: 2,
    borderStyle: 'solid',
    borderColor: 'rgba(255, 255, 255, 0.25)',
    padding: 14,
    marginBottom: 16,
    borderRadius: 12,
    color: '#fff',
    fontSize: 16,
    width: '100%',
    boxSizing: 'border-box',
    boxShadow: 'inset 0 2px 6px rgba(0,0,0,0.3), 0 2px 8px rgba(0,123,255,0.1)',
    transition: 'all 0.3s ease',
  },
  button: {
    backgroundColor: '#007bff',
    padding: 16,
    borderRadius: 15,
    alignItems: 'center',
    marginBottom: 12,
    borderWidth: 3,
    borderStyle: 'solid',
    borderColor: 'rgba(77,163,255,0.3)',
    boxShadow: `0 10px 24px rgba(0,123,255,0.35), 
                0 4px 12px rgba(0,0,0,0.25), 
                inset 0 -3px 8px rgba(0,56,179,0.5), 
                inset 0 3px 8px rgba(77,163,255,0.3),
                inset -2px 0 6px rgba(0,56,179,0.25),
                inset 2px 0 6px rgba(77,163,255,0.25)`,
    transition: 'all 0.3s ease',
  },
  buttonDisabled: {
    backgroundColor: 'rgba(0, 123, 255, 0.5)',
  },
  buttonText: {
    fontFamily: GLOBAL_FONT_FAMILY,
    color: '#fff',
    fontWeight: '600',
    fontSize: 16,
  },
  errorText: {
    fontFamily: GLOBAL_FONT_FAMILY,
    color: '#ff4d4f',
    marginBottom: 16,
    textAlign: 'center',
    fontSize: 14,
  },
  successText: {
    fontFamily: GLOBAL_FONT_FAMILY,
    color: '#52c41a',
    marginBottom: 16,
    textAlign: 'center',
    fontSize: 14,
  },
  toggleButton: {
    padding: 12,
  },
  toggleButtonText: {
    fontFamily: GLOBAL_FONT_FAMILY,
    color: '#007bff',
    textAlign: 'center',
    fontSize: 14,
  },
  validInput: {
    borderColor: '#52c41a',
    borderWidth: 1,
    color: '#52c41a'
  },
  invalidInput: {
    borderColor: '#ff4d4f',
    borderWidth: 1,
    color: '#ff4d4f'
  },
  requirementText: {
    fontFamily: GLOBAL_FONT_FAMILY,
    fontSize: 12,
    marginBottom: 4,
    marginLeft: 4,
  },
  validRequirement: {
    color: '#52c41a',
  },
  invalidRequirement: {
    color: '#ff4d4f',
  },
  forgotPasswordButton: {
    alignSelf: 'flex-end',
    marginBottom: 16,
  },
  forgotPasswordText: {
    fontFamily: GLOBAL_FONT_FAMILY,
    color: '#007bff',
    fontSize: 14,
  },
  backButton: {
    position: 'absolute',
    left: 16,
    top: 16,
    zIndex: 1,
  },
  backButtonText: {
    fontFamily: GLOBAL_FONT_FAMILY,
    fontSize: 24,
    fontWeight: 'bold',
    color: '#fff',
    opacity: 0.7,
  },
  inputContainer: {
    position: 'relative',
    width: '100%',
  },
  formContainer: {
    width: '100%',
  },
  countdownText: {
    fontFamily: GLOBAL_FONT_FAMILY,
    position: 'absolute',
    right: 12,
    top: '50%',
    transform: [{ translateY: -10 }],
    color: '#ff4d4f',
    fontWeight: 'bold',
  },
  lockedInput: {
    backgroundColor: 'rgba(255, 77, 79, 0.1)',
    borderColor: '#ff4d4f',
    color: '#ff4d4f',
  },
});

export default LoginModal; 