// front/components/Header/Header.js
import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import styles from '../../styles/styles';

const Header = ({ onReset }) => {
  const [isHovered, setIsHovered] = useState(false);

  const handleTitlePress = () => {
    if (onReset) {
      onReset();
    }
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  return (
    <View style={{
      padding: 'clamp(10px, 2vw, 20px)',
      paddingTop: 'clamp(60px, 8vw, 80px)',
      alignItems: 'center',
      position: 'relative',
      zIndex: 1,
      width: '100%',
      maxWidth: 1400,
      marginLeft: 'auto',
      marginRight: 'auto'
    }}>
      <TouchableOpacity
        onPress={handleTitlePress}
        onMouseEnter={() => setIsHovered(true)}
        onMouseLeave={() => setIsHovered(false)}
        style={{
          cursor: 'pointer',
          transition: 'all 0.3s ease',
          transform: isHovered ? [{ scale: 1.05 }] : [{ scale: 1 }],
        }}
        activeOpacity={0.8}
      >
        <Text style={styles.heroTitle}>FinansAsistan</Text>
      </TouchableOpacity>
      <Text style={styles.heroSubtitle}>
        Varlığınızı ve Yokluğunuzu Modern Bir Şekilde Yönetin.
      </Text>
    </View>
  );
};

export default Header;
