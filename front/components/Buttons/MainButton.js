// front/components/Buttons/MainButton.js
import React, { useState } from 'react';
import { TouchableOpacity, Text } from 'react-native';
import styles from '../../styles/styles';

const MainButton = ({ title, onPress, style, textStyle }) => {
  const [isHovered, setIsHovered] = useState(false);
  const [isPressed, setIsPressed] = useState(false);

  const getButtonStyle = () => {
    if (isPressed) {
      return {
        transform: [{ translateY: -4 }, { scale: 0.98 }],
        boxShadow: '0 8px 20px rgba(0,123,255,0.4), inset 0 4px 12px rgba(0,37,87,0.6)',
        backgroundColor: '#003d82',
        border: 'clamp(2px, 0.3vw, 3px) solid #002557',
        borderRadius: 'clamp(12px, 2.5vw, 25px)',
        overflow: 'hidden',
      };
    }
    if (isHovered) {
      return {
        transform: [{ translateY: -8 }, { scale: 1.05 }],
        boxShadow: `0 30px 60px rgba(0,123,255,0.4), 
                    0 15px 30px rgba(0,123,255,0.3), 
                    0 0 50px rgba(0,123,255,0.2),
                    inset 0 2px 8px rgba(0,86,179,0.25)`,
        backgroundColor: '#0056b3',
        border: 'clamp(2px, 0.3vw, 3px) solid #0056b3',
        borderRadius: 'clamp(12px, 2.5vw, 25px)',
        overflow: 'hidden',
      };
    }
    return {};
  };

  return (
    <TouchableOpacity 
      style={[styles.mainButton, style, getButtonStyle()]}
      onPress={onPress}
      onPressIn={() => setIsPressed(true)}
      onPressOut={() => setIsPressed(false)}
      onMouseEnter={() => setIsHovered(true)}
      onMouseLeave={() => setIsHovered(false)}
      activeOpacity={0.8}
    >
      <Text style={[styles.mainButtonText, textStyle]}>{title}</Text>
    </TouchableOpacity>
  );
};

export default MainButton;
