// front/components/Modal/AlertModal.js
import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity, Animated } from 'react-native';
import { GLOBAL_FONT_FAMILY } from '../../styles/styles';

const AlertModal = ({ visible, title, message, onClose, success }) => {
  const [progress] = useState(new Animated.Value(0));
  const [isButtonHovered, setIsButtonHovered] = useState(false);
  const [isButtonPressed, setIsButtonPressed] = useState(false);
  
  useEffect(() => {
    if (visible && success) {
      // Progress barı 2 saniyede doldur
      Animated.timing(progress, {
        toValue: 100,
        duration: 2000,
        useNativeDriver: false
      }).start();

      // 2 saniye sonra modalı kapat
      const timer = setTimeout(() => {
        onClose();
      }, 2000);

      return () => clearTimeout(timer);
    }
  }, [visible, success]);

  const getButtonStyle = () => {
    if (isButtonPressed) {
      return {
        transform: [{ translateY: -1 }, { scale: 0.98 }],
        boxShadow: '0 5px 15px rgba(0,0,0,0.4), inset 0 3px 10px rgba(0,37,87,0.6)',
        background: 'linear-gradient(145deg, #003d82 0%, #002557 50%, #001a3d 100%)',
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
        background: 'linear-gradient(145deg, #007bff 0%, #0056b3 50%, #003d82 100%)',
        border: 'clamp(2px, 0.3vw, 3px) solid #0056b3',
        borderRadius: 'clamp(10px, 2.5vw, 25px)',
        overflow: 'hidden',
      };
    }
    return {};
  };

  if (!visible) return null;

  return (
    <View style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0, 0, 0, 0.7)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 10002,
    }}>
      <View style={{
        backgroundColor: '#1a1f25',
        borderRadius: 12,
        padding: 24,
        minWidth: 320,
        maxWidth: '90%',
        borderWidth: 1,
        borderColor: success ? '#28a745' : '#dc3545',
        boxShadow: success 
          ? '0 8px 24px rgba(0, 0, 0, 0.2), 0 0 30px rgba(40, 167, 69, 0.3), 0 0 60px rgba(40, 167, 69, 0.15)'
          : '0 8px 24px rgba(0, 0, 0, 0.2), 0 0 30px rgba(220, 53, 69, 0.4), 0 0 60px rgba(220, 53, 69, 0.2)',
        position: 'relative',
        overflow: 'hidden'
      }}>
        {success && (
          <Animated.View style={{
            position: 'absolute',
            bottom: 0,
            left: 0,
            height: 3,
            backgroundColor: '#28a745',
            width: progress.interpolate({
              inputRange: [0, 100],
              outputRange: ['0%', '100%']
            }),
            boxShadow: '0 0 12px rgba(40, 167, 69, 0.6), 0 0 24px rgba(40, 167, 69, 0.4)'
          }} />
        )}
        <View style={{
          width: 56,
          height: 56,
          borderRadius: 28,
          backgroundColor: success ? '#28a745' : '#dc3545',
          display: 'flex',
          justifyContent: 'center',
          alignItems: 'center',
          marginBottom: 20,
          marginLeft: 'auto',
          marginRight: 'auto',
          boxShadow: success 
            ? '0 0 20px rgba(40, 167, 69, 0.5), 0 0 40px rgba(40, 167, 69, 0.3), 0 4px 12px rgba(0, 0, 0, 0.2)' 
            : '0 0 20px rgba(220, 53, 69, 0.6), 0 0 40px rgba(220, 53, 69, 0.4), 0 4px 12px rgba(0, 0, 0, 0.2)'
        }}>
          {success ? (
            <Text style={{ fontFamily: GLOBAL_FONT_FAMILY, fontSize: 28, color: '#fff' }}>✓</Text>
          ) : (
            <Text style={{ fontFamily: GLOBAL_FONT_FAMILY, fontSize: 28, color: '#fff' }}>!</Text>
          )}
        </View>
        <Text style={{
          fontFamily: GLOBAL_FONT_FAMILY,
          color: '#fff',
          fontSize: 22,
          fontWeight: 'bold',
          marginBottom: 12,
          textAlign: 'center',
        }}>
          {success ? 'Başarılı' : title}
        </Text>
        <Text style={{
          fontFamily: GLOBAL_FONT_FAMILY,
          color: 'rgba(255, 255, 255, 0.7)',
          fontSize: 16,
          marginBottom: success ? 8 : 24,
          textAlign: 'center',
          lineHeight: 22,
        }}>
          {message}
        </Text>
        {!success && (
          <TouchableOpacity
            onPress={onClose}
            onPressIn={() => setIsButtonPressed(true)}
            onPressOut={() => setIsButtonPressed(false)}
            onMouseEnter={() => setIsButtonHovered(true)}
            onMouseLeave={() => setIsButtonHovered(false)}
            activeOpacity={0.8}
            style={[{
              background: 'linear-gradient(145deg, #4da3ff 0%, #007bff 45%, #0056b3 75%, #003d82 100%)',
              padding: 16,
              borderRadius: 15,
              alignItems: 'center',
              transition: 'all 0.3s ease',
              boxShadow: `0 10px 24px rgba(0,123,255,0.35), 
                          0 4px 12px rgba(0,0,0,0.25), 
                          inset 0 2px 6px rgba(0,56,179,0.3)`,
              border: '3px solid #007bff',
              overflow: 'hidden',
            }, getButtonStyle()]}
          >
            <Text style={{
              fontFamily: GLOBAL_FONT_FAMILY,
              color: '#fff',
              fontSize: 16,
              fontWeight: 'bold',
            }}>
              Tamam
            </Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
};

export default AlertModal;
