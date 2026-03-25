// front/components/Header/Header.js
import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity } from 'react-native';
import styles from '../../styles/styles';

const Header = ({ onReset }) => {
  const [isHovered, setIsHovered] = useState(false);
  const HEADER_VERSION = 'v2.3';

  // #region agent log
  useEffect(() => {
    const logData = {
      location: 'Header.js:componentDidMount',
      message: 'Header component rendered',
      data: { version: HEADER_VERSION, timestamp: Date.now() },
      timestamp: Date.now(),
      sessionId: 'debug-session',
      runId: 'run1',
      hypothesisId: 'A'
    };
    fetch('http://127.0.0.1:7242/ingest/dcb88ded-e5da-4f34-9b51-07ad925c2c3e', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(logData)
    }).catch(() => { });
    console.error('[Header] Component rendered', { version: HEADER_VERSION, timestamp: new Date().toISOString() });
  }, []);
  // #endregion

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
        Varlığınızı ve Yokluğunuzu Modern Bir Şekilde Yönetin. ({HEADER_VERSION})
      </Text>
    </View>
  );
};

export default Header;
