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
        padding: '6px',
        borderRadius: '20px',
        borderWidth: '1px',
        borderStyle: 'solid',
        borderColor: 'rgba(0, 123, 255, 0.3)',
        width: '44px',
        height: '44px',
        justifyContent: 'center',
        alignItems: 'center',
        overflow: 'hidden',
        transition: 'all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275)',
        boxShadow: '0 3px 10px rgba(0,123,255,0.3), 0 1px 4px rgba(0,0,0,0.2), inset 0 0.5px 1px rgba(255,255,255,0.15)',
        backdropFilter: 'blur(8px)',
        cursor: 'pointer'
    },
    image: {
        width: '200%',
        height: '200%'
    }
});

export default Logo; 
