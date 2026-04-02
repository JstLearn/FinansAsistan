import React, { createContext, useState, useContext, useEffect } from 'react';

const UserContext = createContext();

export const UserProvider = ({ children }) => {
    const [user, setUser] = useState(() => {
        const savedUser = localStorage.getItem('user');
        return savedUser ? JSON.parse(savedUser) : null;
    });

    const [activeAccount, setActiveAccount] = useState(() => {
        try {
            const saved = localStorage.getItem('activeAccount');
            return saved ? JSON.parse(saved) : null;
        } catch { return null; }
    });

    useEffect(() => {
        if (user) {
            localStorage.setItem('user', JSON.stringify(user));
        } else {
            localStorage.removeItem('user');
        }
    }, [user]);

    useEffect(() => {
        if (activeAccount) {
            localStorage.setItem('activeAccount', JSON.stringify(activeAccount));
        } else {
            localStorage.removeItem('activeAccount');
        }
    }, [activeAccount]);

    const logout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('user');
        localStorage.removeItem('activeAccount');
        setUser(null);
        setActiveAccount(null);
    };

    const switchAccount = (yetki) => {
        setActiveAccount({
            username: yetki.yetki_veren_kullanici,
            yetki: yetki
        });
    };

    const returnToOwnAccount = () => {
        setActiveAccount(null);
    };

    useEffect(() => {
        const handleSessionExpired = () => logout();
        window.addEventListener('auth:session-expired', handleSessionExpired);
        return () => window.removeEventListener('auth:session-expired', handleSessionExpired);
    }, []);

    useEffect(() => {
        const handlePermissionRevoked = () => returnToOwnAccount();
        window.addEventListener('account:permission-revoked', handlePermissionRevoked);
        return () => window.removeEventListener('account:permission-revoked', handlePermissionRevoked);
    }, []);

    return (
        <UserContext.Provider value={{ user, setUser, logout, activeAccount, switchAccount, returnToOwnAccount }}>
            {children}
        </UserContext.Provider>
    );
};

export const useUser = () => {
    const context = useContext(UserContext);
    if (!context) {
        throw new Error('useUser hook\'u UserProvider içinde kullanılmalıdır');
    }
    return context;
};
