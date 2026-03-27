import React, { useEffect, useState } from 'react';
import { Image, TouchableOpacity, StyleSheet } from 'react-native';

const Logo = ({ onReset }) => {
    const [isVisible, setIsVisible] = useState(true);
    const [lastScrollY, setLastScrollY] = useState(0);
    const [isHovered, setIsHovered] = useState(false);

    useEffect(() => {
        const handleScroll = () => {
            const currentScrollY = window.scrollY;
            
            // Aşağı scroll yapılınca gizle (50px'den sonra)
            if (currentScrollY > 50) {
                setIsVisible(false);
            } else {
                setIsVisible(true);
            }
            
            setLastScrollY(currentScrollY);
        };

        window.addEventListener('scroll', handleScroll, { passive: true });
        return () => window.removeEventListener('scroll', handleScroll);
    }, [lastScrollY]);

    const handlePress = () => {
        if (onReset) {
            onReset();
            window.scrollTo(0, 0);
        }
    };

    return (
        <TouchableOpacity
            dataSet={{ logoContainer: true }}
            style={[
                styles.container,
                {
                    transform: [{ translateY: isVisible ? 0 : -150 }],
                    opacity: isVisible ? 1 : 0,
                    backgroundColor: isHovered ? 'rgba(0, 123, 255, 0.2)' : 'rgba(0, 123, 255, 0.1)',
                    elevation: isHovered ? 4 : 0,
                    pointerEvents: isVisible ? 'auto' : 'none'
                }
            ]}
            onPress={handlePress}
            onHoverIn={() => setIsHovered(true)}
            onHoverOut={() => setIsHovered(false)}
            activeOpacity={0.8}
        >
            <Image
                source={require('../assets/logo.png')}
                style={styles.image}
                resizeMode="contain"
            />
        </TouchableOpacity>
    );
};

const styles = StyleSheet.create({
    container: {
        backgroundColor: 'rgba(0, 123, 255, 0.2)',
        padding: 'clamp(3px, 0.6vw, 6px)',
        borderRadius: 'clamp(12px, 2.5vw, 25px)',
        position: 'fixed',
        top: 'clamp(4px, 1vw, 10px)',
        left: 'clamp(4px, 1vw, 10px)',
        borderWidth: 'clamp(1px, 0.2vw, 2px)',
        borderStyle: 'solid',
        borderColor: 'rgba(0, 123, 255, 0.3)',
        zIndex: 1000,
        width: 'clamp(28px, 5vw, 50px)',
        height: 'clamp(28px, 5vw, 50px)',
        justifyContent: 'center',
        alignItems: 'center',
        overflow: 'hidden',
        transition: 'all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275)',
        boxShadow: '0 clamp(3px, 0.6vw, 6px) clamp(10px, 2vw, 20px) rgba(0,123,255,0.3), 0 clamp(1px, 0.2vw, 2px) clamp(4px, 0.8vw, 8px) rgba(0,0,0,0.2), inset 0 clamp(0.5px, 0.1vw, 1px) clamp(1px, 0.2vw, 2px) rgba(255,255,255,0.15)',
        backdropFilter: 'blur(clamp(6px, 1.2vw, 12px))',
        cursor: 'pointer',
        '&:hover': {
            transform: 'translateY(-4px) scale(1.1) rotate(5deg)',
            boxShadow: '0 12px 35px rgba(0,123,255,0.5), 0 4px 15px rgba(0,0,0,0.3), 0 0 25px rgba(0,123,255,0.4)',
            backgroundColor: 'rgba(0, 123, 255, 0.3)',
        },
        '&:active': {
            transform: 'translateY(-2px) scale(1.05)',
            boxShadow: '0 4px 15px rgba(0,123,255,0.3), inset 0 2px 4px rgba(0,0,0,0.2)',
        }
    },
    image: {
        width: '220%',
        height: '220%'
    }
});

export default Logo; 
