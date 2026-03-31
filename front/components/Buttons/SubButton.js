// front/components/Buttons/SubButton.js
import React, { useState, useRef } from 'react';
import { TouchableOpacity, Text } from 'react-native';
import styles from '../../styles/styles';

const SubButton = ({ onPress, title, style }) => {
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
    clearPressTimeout();
    pressTimeoutRef.current = setTimeout(() => {
      setIsPressed(false);
    }, 300);
  };

  const handlePressOut = () => {
    clearPressTimeout();
    setIsPressed(false);
  };

  const getButtonStyle = () => {
    if (isPressed) {
      return {
        transform: [{ translateY: -2 }, { scale: 0.98 }],
        boxShadow: '0 5px 15px rgba(0,0,0,0.4), inset 0 3px 10px rgba(33,37,41,0.6)',
        backgroundColor: '#343a40',
        border: 'clamp(1px, 0.3vw, 3px) solid #212529',
        borderRadius: 'clamp(10px, 2.5vw, 25px)',
        overflow: 'hidden',
      };
    }
    if (isHovered) {
      return {
        transform: [{ translateY: -5 }, { scale: 1.03 }],
        boxShadow: `0 18px 40px rgba(108,117,125,0.4),
                    0 8px 20px rgba(0,0,0,0.3),
                    0 0 30px rgba(108,117,125,0.15),
                    inset 0 2px 6px rgba(73,80,87,0.3)`,
        backgroundColor: '#495057',
        border: 'clamp(1px, 0.3vw, 3px) solid #495057',
        borderRadius: 'clamp(10px, 2.5vw, 25px)',
        overflow: 'hidden',
      };
    }
    return {};
  };

  return (
    <TouchableOpacity
      style={[styles.subButton, style, getButtonStyle()]}
      onPress={onPress}
      onPressIn={handlePressIn}
      onPressOut={handlePressOut}
      onPressCancel={handlePressOut}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      activeOpacity={0.8}
    >
      <Text style={styles.subButtonText}>{title}</Text>
    </TouchableOpacity>
  );
};

export default SubButton;
