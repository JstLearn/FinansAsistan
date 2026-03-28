import React, { useState, useEffect } from 'react';
import { postData, fetchData, updateData, deleteData } from '../services/api';
import AlertModal from './Modal/AlertModal';
import { GLOBAL_FONT_FAMILY } from '../styles/styles';

const YetkiModal = ({ visible, onClose }) => {
    const [yetkiliEmail, setYetkiliEmail] = useState('');
    const [selectedYetkiler, setSelectedYetkiler] = useState({
        varlik_ekleme: false,
        gelir_ekleme: false,
        harcama_borc_ekleme: false,
        istek_ekleme: false,
        hatirlatma_ekleme: false
    });
    const [yetkiList, setYetkiList] = useState([]);
    const [grantedToMeList, setGrantedToMeList] = useState([]);
    const [editingYetkiId, setEditingYetkiId] = useState(null);
    const [alertVisible, setAlertVisible] = useState(false);
    const [alertTitle, setAlertTitle] = useState('');
    const [alertMessage, setAlertMessage] = useState('');
    const [alertCallback, setAlertCallback] = useState(null);
    const [isSuccess, setIsSuccess] = useState(true);
    const [showDelegateModal, setShowDelegateModal] = useState(false);
    const [delegateYetki, setDelegateYetki] = useState(null);
    const [delegateEmail, setDelegateEmail] = useState('');
    const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);
    const [deleteYetkiId, setDeleteYetkiId] = useState(null);

    const loadYetkiList = async () => {
        try {
            const response = await fetchData('yetki');
            if (response.success) {
                setYetkiList(response.data || []);
            }
        } catch (error) {
            console.error('Yetki listesi yüklenemedi:', error);
        }
    };

    const loadGrantedToMeList = async () => {
        try {
            const response = await fetchData('yetki/granted-to-me');
            if (response.success) {
                setGrantedToMeList(response.data || []);
            }
        } catch (error) {
            console.error('Bana verilen yetki listesi yüklenemedi:', error);
        }
    };

    useEffect(() => {
        if (visible) {
            loadYetkiList();
            loadGrantedToMeList();
        }
    }, [visible]);

    const showAlert = (title, message, callback = null, success = true) => {
        setAlertTitle(title);
        setAlertMessage(message);
        setAlertCallback(() => callback);
        setIsSuccess(success);
        setAlertVisible(true);
    };

    const handleYetkiSubmit = async () => {
        if (!yetkiliEmail || !yetkiliEmail.includes('@')) {
            showAlert('Uyarı', 'Geçerli bir email adresi giriniz', null, false);
            return;
        }

        const anyYetkiSelected = Object.values(selectedYetkiler).some(v => v === true);
        if (!anyYetkiSelected) {
            showAlert('Uyarı', 'En az bir yetki türü seçmelisiniz', null, false);
            return;
        }

        try {
            const data = {
                yetkili_kullanici: yetkiliEmail,
                ...selectedYetkiler
            };

            let response;
            if (editingYetkiId) {
                response = await updateData('yetki', editingYetkiId, data);
            } else {
                response = await postData('yetki', data);
            }

            setYetkiliEmail('');
            setSelectedYetkiler({
                varlik_ekleme: false,
                gelir_ekleme: false,
                harcama_borc_ekleme: false,
                istek_ekleme: false,
                hatirlatma_ekleme: false
            });
            setEditingYetkiId(null);
            await loadYetkiList();

            showAlert('Başarılı', response.message || 'Yetki başarıyla kaydedildi ve bilgilendirme maili gönderildi!', null, true);
        } catch (error) {
            console.error('Yetki verme hatası:', error);
            showAlert('Hata', 'Yetki verilirken bir hata oluştu: ' + error.message, null, false);
        }
    };

    const handleEditYetki = (yetki) => {
        setYetkiliEmail(yetki.yetkili_kullanici);
        setSelectedYetkiler({
            varlik_ekleme: yetki.varlik_ekleme === 1 || yetki.varlik_ekleme === true,
            gelir_ekleme: yetki.gelir_ekleme === 1 || yetki.gelir_ekleme === true,
            harcama_borc_ekleme: yetki.harcama_borc_ekleme === 1 || yetki.harcama_borc_ekleme === true,
            istek_ekleme: yetki.istek_ekleme === 1 || yetki.istek_ekleme === true,
            hatirlatma_ekleme: yetki.hatirlatma_ekleme === 1 || yetki.hatirlatma_ekleme === true
        });
        setEditingYetkiId(yetki.id);
    };

    const handleDeleteYetki = (id) => {
        setDeleteYetkiId(id);
        setShowDeleteConfirm(true);
    };

    const confirmDeleteYetki = async () => {
        try {
            await deleteData('yetki', deleteYetkiId);
            setShowDeleteConfirm(false);
            setDeleteYetkiId(null);
            await loadYetkiList();
            showAlert('Başarılı', 'Yetki başarıyla silindi!', null, true);
        } catch (error) {
            console.error('Yetki silme hatası:', error);
            setShowDeleteConfirm(false);
            setDeleteYetkiId(null);
            showAlert('Hata', 'Yetki silinirken bir hata oluştu: ' + error.message, null, false);
        }
    };

    const handleDelegateYetki = (yetki) => {
        setDelegateYetki(yetki);
        setDelegateEmail('');
        setShowDelegateModal(true);
    };

    const confirmDelegateYetki = async () => {
        if (!delegateEmail || !delegateEmail.includes('@')) {
            showAlert('Uyarı', 'Geçerli bir email adresi giriniz', null, false);
            return;
        }

        try {
            const data = {
                yetkili_kullanici: delegateEmail,
                varlik_ekleme: delegateYetki.varlik_ekleme,
                gelir_ekleme: delegateYetki.gelir_ekleme,
                harcama_borc_ekleme: delegateYetki.harcama_borc_ekleme,
                istek_ekleme: delegateYetki.istek_ekleme,
                hatirlatma_ekleme: delegateYetki.hatirlatma_ekleme
            };

            await postData('yetki', data);
            setShowDelegateModal(false);
            setDelegateYetki(null);
            setDelegateEmail('');
            await loadYetkiList();
            showAlert('Başarılı', 'Yetki başarıyla devredildi ve bilgilendirme maili gönderildi!', null, true);
        } catch (error) {
            console.error('Yetki devretme hatası:', error);
            showAlert('Hata', 'Yetki devredilirken bir hata oluştu: ' + error.message, null, false);
        }
    };

    if (!visible) return null;

    return (
        <>
            {/* Yetki Modalı */}
            <div
                style={{
                    position: 'fixed',
                    top: 0,
                    left: 0,
                    width: '100vw',
                    height: '100vh',
                    backgroundColor: 'rgba(0, 0, 0, 0.7)',
                    display: 'grid',
                    placeItems: 'center',
                    zIndex: 10004
                }}
                onClick={onClose}
            >
                <div
                    style={{
                        backgroundColor: 'rgba(30, 40, 50, 0.98)',
                        border: '1px solid rgba(0, 123, 255, 0.5)',
                        borderRadius: '16px',
                        padding: '24px',
                        maxWidth: '600px',
                        width: '90%',
                        maxHeight: '80vh',
                        overflow: 'auto',
                        boxShadow: '0 8px 32px rgba(0, 123, 255, 0.3)',
                        fontFamily: GLOBAL_FONT_FAMILY
                    }}
                    onClick={(e) => e.stopPropagation()}
                >
                    <h2 style={{
                        color: 'rgba(0, 123, 255, 0.95)',
                        fontSize: 'clamp(18px, 3vw, 24px)',
                        marginBottom: '20px',
                        textAlign: 'center'
                    }}>
                        Yetkilendirme Yönetimi
                    </h2>

                    {/* Üst Kısım: Yetki Verme Formu */}
                    <div style={{ marginBottom: '24px' }}>
                        <h3 style={{
                            color: 'rgba(255, 255, 255, 0.9)',
                            fontSize: 'clamp(14px, 2.5vw, 18px)',
                            marginBottom: '12px'
                        }}>
                            {editingYetkiId ? 'Yetki Düzenle' : 'Yeni Yetki Ver'}
                        </h3>

                        <input
                            type="email"
                            placeholder="Yetki vermek istediğiniz maili girin"
                            value={yetkiliEmail}
                            onChange={(e) => setYetkiliEmail(e.target.value)}
                            disabled={!!editingYetkiId}
                            style={{
                                width: '100%',
                                padding: '12px',
                                marginBottom: '16px',
                                borderRadius: '8px',
                                border: '1px solid rgba(0, 123, 255, 0.3)',
                                backgroundColor: 'rgba(30, 40, 50, 0.95)',
                                color: '#fff',
                                fontFamily: GLOBAL_FONT_FAMILY,
                                fontSize: '14px',
                                outline: 'none',
                                boxSizing: 'border-box'
                            }}
                        />

                        {/* Yetki Checkboxları */}
                        <div style={{ marginBottom: '16px' }}>
                            {[
                                { id: 'varlik_ekleme', label: 'Varlık Ekleme' },
                                { id: 'gelir_ekleme', label: 'Gelir Ekleme' },
                                { id: 'harcama_borc_ekleme', label: 'Harcama-Borç Ekleme' },
                                { id: 'istek_ekleme', label: 'İstek Ekleme' },
                                { id: 'hatirlatma_ekleme', label: 'Hatırlatma Ekleme' }
                            ].map((yetki) => (
                                <label
                                    key={yetki.id}
                                    style={{
                                        display: 'flex',
                                        alignItems: 'center',
                                        marginBottom: '8px',
                                        cursor: 'pointer',
                                        color: 'rgba(255, 255, 255, 0.9)',
                                        fontSize: '14px'
                                    }}
                                >
                                    <input
                                        type="checkbox"
                                        checked={selectedYetkiler[yetki.id]}
                                        onChange={(e) => setSelectedYetkiler({
                                            ...selectedYetkiler,
                                            [yetki.id]: e.target.checked
                                        })}
                                        style={{
                                            marginRight: '8px',
                                            width: '18px',
                                            height: '18px',
                                            cursor: 'pointer'
                                        }}
                                    />
                                    {yetki.label}
                                </label>
                            ))}
                        </div>

                        <button
                            onClick={handleYetkiSubmit}
                            style={{
                                width: '100%',
                                padding: '12px',
                                borderRadius: '8px',
                                border: '1px solid rgba(40, 167, 69, 0.5)',
                                backgroundColor: 'rgba(40, 167, 69, 0.2)',
                                color: 'rgba(40, 167, 69, 0.95)',
                                fontFamily: GLOBAL_FONT_FAMILY,
                                fontSize: '14px',
                                fontWeight: 'bold',
                                cursor: 'pointer',
                                transition: 'all 0.3s ease'
                            }}
                            onMouseEnter={(e) => {
                                e.target.style.backgroundColor = 'rgba(40, 167, 69, 0.3)';
                                e.target.style.transform = 'translateY(-2px)';
                            }}
                            onMouseLeave={(e) => {
                                e.target.style.backgroundColor = 'rgba(40, 167, 69, 0.2)';
                                e.target.style.transform = 'translateY(0)';
                            }}
                        >
                            {editingYetkiId ? 'Güncelle' : 'Yetki Ver'}
                        </button>
                    </div>

                    {/* Alt Kısım: İki Liste Yan Yana */}
                    <div style={{
                        display: 'grid',
                        gridTemplateColumns: '1fr 1fr',
                        gap: '20px',
                        marginBottom: '20px'
                    }}>
                        {/* Sol: Verdiğim Yetkiler */}
                        <div>
                            <h3 style={{
                                color: 'rgba(255, 255, 255, 0.9)',
                                fontSize: 'clamp(14px, 2.5vw, 18px)',
                                marginBottom: '12px'
                            }}>
                                Verdiğim Yetkiler
                            </h3>

                            {yetkiList.length === 0 ? (
                                <p style={{ color: 'rgba(255, 255, 255, 0.5)', textAlign: 'center', fontSize: '12px' }}>
                                    Henüz kimseye yetki vermediniz
                                </p>
                            ) : (
                                yetkiList.map((yetki) => (
                                    <div
                                        key={yetki.id}
                                        style={{
                                            backgroundColor: 'rgba(0, 123, 255, 0.1)',
                                            border: '1px solid rgba(0, 123, 255, 0.3)',
                                            borderRadius: '8px',
                                            padding: '12px',
                                            marginBottom: '8px'
                                        }}
                                    >
                                        <div style={{
                                            display: 'flex',
                                            justifyContent: 'space-between',
                                            alignItems: 'center',
                                            marginBottom: '8px'
                                        }}>
                                            <strong style={{ color: 'rgba(0, 123, 255, 0.95)', fontSize: '12px' }}>
                                                {yetki.yetkili_kullanici}
                                            </strong>
                                            <div style={{ display: 'flex', gap: '4px' }}>
                                                <button
                                                    onClick={() => handleEditYetki(yetki)}
                                                    style={{
                                                        padding: '2px 8px',
                                                        borderRadius: '4px',
                                                        border: '1px solid rgba(0, 123, 255, 0.4)',
                                                        backgroundColor: 'rgba(0, 123, 255, 0.2)',
                                                        color: 'rgba(0, 123, 255, 0.9)',
                                                        fontSize: '10px',
                                                        cursor: 'pointer'
                                                    }}
                                                >
                                                    Düzenle
                                                </button>
                                                <button
                                                    onClick={() => handleDeleteYetki(yetki.id)}
                                                    style={{
                                                        padding: '2px 8px',
                                                        borderRadius: '4px',
                                                        border: '1px solid rgba(220, 53, 69, 0.4)',
                                                        backgroundColor: 'rgba(220, 53, 69, 0.2)',
                                                        color: 'rgba(220, 53, 69, 0.9)',
                                                        fontSize: '10px',
                                                        cursor: 'pointer'
                                                    }}
                                                >
                                                    Sil
                                                </button>
                                            </div>
                                        </div>
                                        <div style={{ fontSize: '10px', color: 'rgba(255, 255, 255, 0.7)' }}>
                                            {[
                                                yetki.varlik_ekleme && 'Varlık',
                                                yetki.gelir_ekleme && 'Gelir',
                                                yetki.harcama_borc_ekleme && 'Harcama-Borç',
                                                yetki.istek_ekleme && 'İstek',
                                                yetki.hatirlatma_ekleme && 'Hatırlatma'
                                            ].filter(Boolean).join(', ')}
                                        </div>
                                    </div>
                                ))
                            )}
                        </div>

                        {/* Sağ: Bana Verilen Yetkiler */}
                        <div>
                            <h3 style={{
                                color: 'rgba(255, 255, 255, 0.9)',
                                fontSize: 'clamp(14px, 2.5vw, 18px)',
                                marginBottom: '12px'
                            }}>
                                Bana Verilen Yetkiler
                            </h3>

                            {grantedToMeList.length === 0 ? (
                                <p style={{ color: 'rgba(255, 255, 255, 0.5)', textAlign: 'center', fontSize: '12px' }}>
                                    Size verilmiş yetki yok
                                </p>
                            ) : (
                                grantedToMeList.map((yetki) => (
                                    <div
                                        key={yetki.id}
                                        style={{
                                            backgroundColor: 'rgba(40, 167, 69, 0.1)',
                                            border: '1px solid rgba(40, 167, 69, 0.3)',
                                            borderRadius: '8px',
                                            padding: '12px',
                                            marginBottom: '8px'
                                        }}
                                    >
                                        <div style={{
                                            display: 'flex',
                                            justifyContent: 'space-between',
                                            alignItems: 'center',
                                            marginBottom: '8px'
                                        }}>
                                            <strong style={{ color: 'rgba(40, 167, 69, 0.95)', fontSize: '12px' }}>
                                                {yetki.yetki_veren_kullanici}
                                            </strong>
                                            <button
                                                onClick={() => handleDelegateYetki(yetki)}
                                                style={{
                                                    padding: '2px 8px',
                                                    borderRadius: '4px',
                                                    border: '1px solid rgba(255, 193, 7, 0.4)',
                                                    backgroundColor: 'rgba(255, 193, 7, 0.2)',
                                                    color: 'rgba(255, 193, 7, 0.9)',
                                                    fontSize: '10px',
                                                    cursor: 'pointer',
                                                    whiteSpace: 'nowrap'
                                                }}
                                            >
                                                Başkasına Ekle
                                            </button>
                                        </div>
                                        <div style={{ fontSize: '10px', color: 'rgba(255, 255, 255, 0.7)' }}>
                                            {[
                                                yetki.varlik_ekleme && 'Varlık',
                                                yetki.gelir_ekleme && 'Gelir',
                                                yetki.harcama_borc_ekleme && 'Harcama-Borç',
                                                yetki.istek_ekleme && 'İstek',
                                                yetki.hatirlatma_ekleme && 'Hatırlatma'
                                            ].filter(Boolean).join(', ')}
                                        </div>
                                    </div>
                                ))
                            )}
                        </div>
                    </div>

                    <button
                        onClick={onClose}
                        style={{
                            width: '100%',
                            padding: '12px',
                            marginTop: '20px',
                            borderRadius: '8px',
                            border: '1px solid rgba(255, 255, 255, 0.3)',
                            backgroundColor: 'rgba(255, 255, 255, 0.1)',
                            color: 'rgba(255, 255, 255, 0.9)',
                            fontFamily: GLOBAL_FONT_FAMILY,
                            fontSize: '14px',
                            cursor: 'pointer'
                        }}
                    >
                        Kapat
                    </button>
                </div>
            </div>

            {/* Başkasına Ekle Modalı */}
            {showDelegateModal && delegateYetki && (
                <div
                    style={{
                        position: 'fixed',
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        backgroundColor: 'rgba(0, 0, 0, 0.7)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        zIndex: 10005
                    }}
                    onClick={() => setShowDelegateModal(false)}
                >
                    <div
                        style={{
                            backgroundColor: 'rgba(30, 40, 50, 0.98)',
                            border: '1px solid rgba(255, 193, 7, 0.5)',
                            borderRadius: '16px',
                            padding: '24px',
                            maxWidth: '450px',
                            width: '90%',
                            boxShadow: '0 8px 32px rgba(255, 193, 7, 0.3)',
                            fontFamily: GLOBAL_FONT_FAMILY
                        }}
                        onClick={(e) => e.stopPropagation()}
                    >
                        <h3 style={{
                            color: 'rgba(255, 193, 7, 0.95)',
                            fontSize: 'clamp(16px, 3vw, 20px)',
                            marginBottom: '12px',
                            textAlign: 'center',
                            fontWeight: 'bold'
                        }}>
                            Yetkiyi Başkasına Aktar
                        </h3>
                        <p style={{
                            color: 'rgba(255, 255, 255, 0.8)',
                            fontSize: 'clamp(13px, 2.5vw, 15px)',
                            marginBottom: '16px',
                            textAlign: 'center'
                        }}>
                            <strong style={{ color: 'rgba(40, 167, 69, 0.95)' }}>
                                {delegateYetki.yetki_veren_kullanici}
                            </strong> tarafından size verilen yetkiyi başka bir kullanıcıya aktarmak üzeresiniz.
                        </p>

                        <div style={{
                            backgroundColor: 'rgba(255, 193, 7, 0.1)',
                            border: '1px solid rgba(255, 193, 7, 0.3)',
                            borderRadius: '8px',
                            padding: '12px',
                            marginBottom: '16px'
                        }}>
                            <div style={{ fontSize: '12px', color: 'rgba(255, 255, 255, 0.9)', marginBottom: '4px' }}>
                                <strong>Aktarılacak Yetkiler:</strong>
                            </div>
                            <div style={{ fontSize: '12px', color: 'rgba(255, 193, 7, 0.9)' }}>
                                {[
                                    delegateYetki.varlik_ekleme && 'Varlık Ekleme',
                                    delegateYetki.gelir_ekleme && 'Gelir Ekleme',
                                    delegateYetki.harcama_borc_ekleme && 'Harcama-Borç Ekleme',
                                    delegateYetki.istek_ekleme && 'İstek Ekleme',
                                    delegateYetki.hatirlatma_ekleme && 'Hatırlatma Ekleme'
                                ].filter(Boolean).join(', ')}
                            </div>
                        </div>

                        <input
                            type="email"
                            placeholder="Yetkiyi aktarmak istediğiniz kullanıcının maili"
                            value={delegateEmail}
                            onChange={(e) => setDelegateEmail(e.target.value)}
                            style={{
                                width: '100%',
                                padding: '12px',
                                marginBottom: '16px',
                                borderRadius: '8px',
                                border: '1px solid rgba(255, 193, 7, 0.3)',
                                backgroundColor: 'rgba(30, 40, 50, 0.95)',
                                color: '#fff',
                                fontFamily: GLOBAL_FONT_FAMILY,
                                fontSize: '14px',
                                outline: 'none',
                                boxSizing: 'border-box'
                            }}
                        />

                        <div style={{
                            display: 'flex',
                            gap: '12px',
                            justifyContent: 'center'
                        }}>
                            <button
                                onClick={confirmDelegateYetki}
                                style={{
                                    padding: '10px 24px',
                                    borderRadius: '8px',
                                    border: '1px solid rgba(255, 193, 7, 0.5)',
                                    backgroundColor: 'rgba(255, 193, 7, 0.2)',
                                    color: 'rgba(255, 193, 7, 0.95)',
                                    fontFamily: GLOBAL_FONT_FAMILY,
                                    fontSize: 'clamp(13px, 2.5vw, 15px)',
                                    cursor: 'pointer',
                                    fontWeight: 'bold',
                                    transition: 'all 0.3s ease'
                                }}
                                onMouseEnter={(e) => {
                                    e.target.style.backgroundColor = 'rgba(255, 193, 7, 0.3)';
                                    e.target.style.transform = 'translateY(-2px)';
                                }}
                                onMouseLeave={(e) => {
                                    e.target.style.backgroundColor = 'rgba(255, 193, 7, 0.2)';
                                    e.target.style.transform = 'translateY(0)';
                                }}
                            >
                                Onayla ve Aktar
                            </button>
                            <button
                                onClick={() => setShowDelegateModal(false)}
                                style={{
                                    padding: '10px 24px',
                                    borderRadius: '8px',
                                    border: '1px solid rgba(255, 255, 255, 0.3)',
                                    backgroundColor: 'rgba(255, 255, 255, 0.1)',
                                    color: 'rgba(255, 255, 255, 0.9)',
                                    fontFamily: GLOBAL_FONT_FAMILY,
                                    fontSize: 'clamp(13px, 2.5vw, 15px)',
                                    cursor: 'pointer',
                                    transition: 'all 0.3s ease'
                                }}
                                onMouseEnter={(e) => {
                                    e.target.style.backgroundColor = 'rgba(255, 255, 255, 0.2)';
                                    e.target.style.transform = 'translateY(-2px)';
                                }}
                                onMouseLeave={(e) => {
                                    e.target.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                                    e.target.style.transform = 'translateY(0)';
                                }}
                            >
                                İptal
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Silme Onay Modalı */}
            {showDeleteConfirm && (
                <div
                    style={{
                        position: 'fixed',
                        top: 0,
                        left: 0,
                        right: 0,
                        bottom: 0,
                        backgroundColor: 'rgba(0, 0, 0, 0.7)',
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'center',
                        zIndex: 10006
                    }}
                    onClick={() => setShowDeleteConfirm(false)}
                >
                    <div
                        style={{
                            backgroundColor: 'rgba(30, 40, 50, 0.98)',
                            border: '1px solid rgba(220, 53, 69, 0.5)',
                            borderRadius: '16px',
                            padding: '24px',
                            maxWidth: '400px',
                            boxShadow: '0 8px 32px rgba(220, 53, 69, 0.3)',
                            fontFamily: GLOBAL_FONT_FAMILY
                        }}
                        onClick={(e) => e.stopPropagation()}
                    >
                        <div style={{ textAlign: 'center', marginBottom: '20px' }}>
                            <span style={{ fontSize: '48px' }}>⚠️</span>
                        </div>
                        <h3 style={{
                            color: 'rgba(220, 53, 69, 0.95)',
                            fontSize: 'clamp(16px, 3vw, 20px)',
                            marginBottom: '12px',
                            textAlign: 'center',
                            fontWeight: 'bold'
                        }}>
                            Bu Yetkiyi Silmek İstediğinize Emin Misiniz?
                        </h3>
                        <p style={{
                            color: 'rgba(255, 255, 255, 0.8)',
                            fontSize: 'clamp(13px, 2.5vw, 15px)',
                            marginBottom: '24px',
                            textAlign: 'center'
                        }}>
                            Bu işlem geri alınamaz.
                        </p>
                        <div style={{
                            display: 'flex',
                            gap: '12px',
                            justifyContent: 'center'
                        }}>
                            <button
                                onClick={confirmDeleteYetki}
                                style={{
                                    padding: '10px 24px',
                                    borderRadius: '8px',
                                    border: '1px solid rgba(220, 53, 69, 0.5)',
                                    backgroundColor: 'rgba(220, 53, 69, 0.2)',
                                    color: 'rgba(220, 53, 69, 0.95)',
                                    fontFamily: GLOBAL_FONT_FAMILY,
                                    fontSize: 'clamp(13px, 2.5vw, 15px)',
                                    cursor: 'pointer',
                                    fontWeight: 'bold',
                                    transition: 'all 0.3s ease'
                                }}
                                onMouseEnter={(e) => {
                                    e.target.style.backgroundColor = 'rgba(220, 53, 69, 0.3)';
                                    e.target.style.transform = 'translateY(-2px)';
                                }}
                                onMouseLeave={(e) => {
                                    e.target.style.backgroundColor = 'rgba(220, 53, 69, 0.2)';
                                    e.target.style.transform = 'translateY(0)';
                                }}
                            >
                                Evet, Sil
                            </button>
                            <button
                                onClick={() => setShowDeleteConfirm(false)}
                                style={{
                                    padding: '10px 24px',
                                    borderRadius: '8px',
                                    border: '1px solid rgba(255, 255, 255, 0.3)',
                                    backgroundColor: 'rgba(255, 255, 255, 0.1)',
                                    color: 'rgba(255, 255, 255, 0.9)',
                                    fontFamily: GLOBAL_FONT_FAMILY,
                                    fontSize: 'clamp(13px, 2.5vw, 15px)',
                                    cursor: 'pointer',
                                    transition: 'all 0.3s ease'
                                }}
                                onMouseEnter={(e) => {
                                    e.target.style.backgroundColor = 'rgba(255, 255, 255, 0.2)';
                                    e.target.style.transform = 'translateY(-2px)';
                                }}
                                onMouseLeave={(e) => {
                                    e.target.style.backgroundColor = 'rgba(255, 255, 255, 0.1)';
                                    e.target.style.transform = 'translateY(0)';
                                }}
                            >
                                İptal
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Alert Modal */}
            <AlertModal
                visible={alertVisible}
                title={alertTitle}
                message={alertMessage}
                onClose={() => {
                    setAlertVisible(false);
                    if (alertCallback) {
                        alertCallback();
                    }
                }}
                success={isSuccess}
            />
        </>
    );
};

export default YetkiModal;
