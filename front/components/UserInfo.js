import React, { useState, useEffect } from 'react';
import { View, Text, TouchableOpacity, StyleSheet } from 'react-native';
import { useUser } from '../context/UserContext';
import { GLOBAL_FONT_FAMILY } from '../styles/styles';

const UserInfo = ({ onLogout, onOpenYetkiModal }) => {
    const { user, logout } = useUser();
    const [isVisible, setIsVisible] = useState(true);
    const [lastScrollY, setLastScrollY] = useState(0);
    const [isLogoutHovered, setIsLogoutHovered] = useState(false);
    const [isLogoutPressed, setIsLogoutPressed] = useState(false);
    const [fluidEnabled, setFluidEnabled] = useState(() => {
        if (typeof window !== 'undefined') {
            return localStorage.getItem('fluidEnabled') !== 'false';
        }
        return true;
    });

    const toggleFluidSimulation = () => {
        const newValue = !fluidEnabled;
        setFluidEnabled(newValue);
        localStorage.setItem('fluidEnabled', String(newValue));

        const canvas = document.getElementById('fluid-canvas');
        if (canvas) {
            canvas.style.opacity = newValue ? '1' : '0';
        }
    };

    useEffect(() => {
        const canvas = document.getElementById('fluid-canvas');
        if (canvas) {
            canvas.style.opacity = fluidEnabled ? '1' : '0';
        }
    }, []);

    useEffect(() => {
        const handleScroll = () => {
            const currentScrollY = window.scrollY;

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

    if (!user) return null;

    const handleLogout = () => {
        logout();
        if (onLogout) onLogout();
    };

    const handleUsernameClick = () => {
        if (onOpenYetkiModal) {
            onOpenYetkiModal();
        }
    };

    const getLogoutButtonStyle = () => {
        if (isLogoutPressed) {
            return {
                transform: [{ translateY: 0 }, { scale: 1 }],
                boxShadow: '0 3px 10px rgba(0,0,0,0.3), inset 0 3px 8px rgba(167,29,42,0.6)',
                backgroundColor: '#a71d2a',
                border: 'clamp(1.5px, 0.3vw, 3px) solid #a71d2a',
                borderRadius: 'clamp(8px, 1.8vw, 18px)',
                overflow: 'hidden',
            };
        }
        if (isLogoutHovered) {
            return {
                transform: [{ translateY: -3 }, { scale: 1.08 }],
                backgroundColor: '#dc3545',
                boxShadow: `0 10px 28px rgba(255,59,48,0.4),
                            0 4px 14px rgba(0,0,0,0.3),
                            0 0 20px rgba(255,59,48,0.2),
                            inset 0 2px 6px rgba(220,53,69,0.3)`,
                border: 'clamp(1.5px, 0.3vw, 3px) solid #dc3545',
                borderRadius: 'clamp(8px, 1.8vw, 18px)',
                overflow: 'hidden',
            };
        }
        return {};
    };

    return (
        <View style={[
            styles.container,
            {
                opacity: isVisible ? 1 : 0,
                transform: [{ translateY: isVisible ? 0 : -150 }]
            }
        ]}>
            <TouchableOpacity onPress={handleUsernameClick} activeOpacity={0.7}>
                <Text style={styles.email} numberOfLines={1}>{user.username}</Text>
            </TouchableOpacity>
            <TouchableOpacity
                onPress={toggleFluidSimulation}
                style={styles.fluidToggle}
                activeOpacity={0.7}
            >
                <View style={[
                    styles.fluidToggleTrack,
                    {
                        backgroundColor: fluidEnabled ? 'rgba(34, 197, 94, 0.5)' : 'rgba(239, 68, 68, 0.5)',
                        borderColor: fluidEnabled ? 'rgba(34, 197, 94, 0.9)' : 'rgba(239, 68, 68, 0.9)'
                    }
                ]}>
                    <View style={[
                        styles.fluidToggleThumb,
                        {
                            transform: [{ translateX: fluidEnabled ? 14 : 0 }],
                            backgroundColor: fluidEnabled ? '#15803d' : '#dc2626',
                            borderColor: fluidEnabled ? '#15803d' : '#dc2626'
                        }
                    ]} />
                </View>
            </TouchableOpacity>
            <TouchableOpacity
                style={[styles.logoutButton, getLogoutButtonStyle()]}
                onPress={handleLogout}
                onPressIn={() => setIsLogoutPressed(true)}
                onPressOut={() => setIsLogoutPressed(false)}
                onMouseEnter={() => setIsLogoutHovered(true)}
                onMouseLeave={() => setIsLogoutHovered(false)}
                activeOpacity={0.8}
            >
                <Text style={styles.logoutText}>Çıkış</Text>
            </TouchableOpacity>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        backgroundColor: 'rgba(0, 123, 255, 0.15)',
        padding: '6px 10px',
        borderRadius: '16px',
        borderWidth: '1px',
        borderStyle: 'solid',
        borderColor: 'rgba(0, 123, 255, 0.3)',
        flexDirection: 'row',
        alignItems: 'center',
        gap: '8px',
        flexShrink: 0,
        transition: 'all 0.4s cubic-bezier(0.175, 0.885, 0.32, 1.275)',
        boxShadow: '0 2px 8px rgba(0,123,255,0.3), 0 1px 3px rgba(0,0,0,0.2), inset 0 0.5px 1px rgba(255,255,255,0.15)',
        backdropFilter: 'blur(6px)',
        width: 'auto',
        maxWidth: '400px',
    },
    email: {
        fontFamily: GLOBAL_FONT_FAMILY,
        color: '#fff',
        fontSize: '12px',
        fontWeight: '500',
        whiteSpace: 'nowrap',
        overflow: 'hidden',
        textOverflow: 'ellipsis',
        width: 'auto',
        maxWidth: '120px',
        flexShrink: 1,
    },
    fluidToggle: {
        cursor: 'pointer',
        flexShrink: 0,
    },
    fluidToggleTrack: {
        width: '32px',
        height: '18px',
        borderRadius: '9px',
        padding: '2px',
        justifyContent: 'center',
        transition: 'all 0.2s ease',
        borderWidth: '1.5px',
        borderStyle: 'solid',
    },
    fluidToggleThumb: {
        width: '14px',
        height: '14px',
        borderRadius: '7px',
        transition: 'all 0.2s ease',
        borderWidth: '2px',
        borderStyle: 'solid',
        backgroundColor: '#ccc',
    },
    logoutButton: {
        backgroundColor: '#ff3b30',
        paddingVertical: '4px',
        paddingHorizontal: '10px',
        borderRadius: '10px',
        borderWidth: 1,
        borderStyle: 'solid',
        borderColor: 'rgba(255,107,95,0.3)',
        transition: 'all 0.3s ease',
        boxShadow: `0 2px 8px rgba(255,59,48,0.3),
                    0 1px 3px rgba(0,0,0,0.25),
                    inset 0 -1px 3px rgba(200,35,51,0.5),
                    inset 0 1px 3px rgba(255,107,95,0.35)`,
        cursor: 'pointer',
    },
    logoutText: {
        fontFamily: GLOBAL_FONT_FAMILY,
        color: '#fff',
        fontSize: '12px',
        fontWeight: '500',
        whiteSpace: 'nowrap'
    }
});

export default UserInfo;
