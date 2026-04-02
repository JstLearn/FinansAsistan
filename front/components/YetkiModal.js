import React, { useState, useEffect } from 'react';
import { postData, fetchData, updateData, deleteData } from '../services/api';
import AlertModal from './Modal/AlertModal';
import { GLOBAL_FONT_FAMILY } from '../styles/styles';
import { useUser } from '../context/UserContext';

const YetkiModal = ({ visible, onClose }) => {
    const { activeAccount, switchAccount } = useUser();
    const [yetkiliEmail, setYetkiliEmail] = useState('');
    const [selectedYetkiler, setSelectedYetkiler] = useState({
        varlik_ekleme: false, varlik_silme: false, varlik_duzenleme: false,
        gelir_ekleme: false, gelir_silme: false, gelir_duzenleme: false,
        harcama_borc_ekleme: false, harcama_borc_silme: false, harcama_borc_duzenleme: false,
        istek_ekleme: false, istek_silme: false, istek_duzenleme: false,
        hatirlatma_ekleme: false, hatirlatma_silme: false, hatirlatma_duzenleme: false
    });
    const [yetkiList, setYetkiList] = useState([]);
    const [grantedToMeList, setGrantedToMeList] = useState([]);
    const [editingYetkiId, setEditingYetkiId] = useState(null);
    const [inlineEditingId, setInlineEditingId] = useState(null);
    const [isNewYetki, setIsNewYetki] = useState(false);
    const [newYetkiEmail, setNewYetkiEmail] = useState('');
    const [inlineSelectedYetkiler, setInlineSelectedYetkiler] = useState({
        varlik_ekleme: false, varlik_silme: false, varlik_duzenleme: false,
        gelir_ekleme: false, gelir_silme: false, gelir_duzenleme: false,
        harcama_borc_ekleme: false, harcama_borc_silme: false, harcama_borc_duzenleme: false,
        istek_ekleme: false, istek_silme: false, istek_duzenleme: false,
        hatirlatma_ekleme: false, hatirlatma_silme: false, hatirlatma_duzenleme: false
    });
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
            const data = { yetkili_kullanici: yetkiliEmail, ...selectedYetkiler };
            const response = await postData('yetki', data);

            setYetkiliEmail('');
            setSelectedYetkiler({ varlik_ekleme: false, varlik_silme: false, varlik_duzenleme: false, gelir_ekleme: false, gelir_silme: false, gelir_duzenleme: false, harcama_borc_ekleme: false, harcama_borc_silme: false, harcama_borc_duzenleme: false, istek_ekleme: false, istek_silme: false, istek_duzenleme: false, hatirlatma_ekleme: false, hatirlatma_silme: false, hatirlatma_duzenleme: false });
            await loadYetkiList();

            showAlert('Başarılı', response.message || 'Yetki başarıyla kaydedildi!', null, true);
        } catch (error) {
            console.error('Yetki verme hatası:', error);
            showAlert('Hata', 'Yetki verilirken bir hata oluştu: ' + error.message, null, false);
        }
    };

    const handleEditYetki = (yetki) => {
        setInlineEditingId(yetki.id);
        setInlineSelectedYetkiler({
            varlik_ekleme: yetki.varlik_ekleme === 1 || yetki.varlik_ekleme === true,
            varlik_silme: yetki.varlik_silme === 1 || yetki.varlik_silme === true,
            varlik_duzenleme: yetki.varlik_duzenleme === 1 || yetki.varlik_duzenleme === true,
            gelir_ekleme: yetki.gelir_ekleme === 1 || yetki.gelir_ekleme === true,
            gelir_silme: yetki.gelir_silme === 1 || yetki.gelir_silme === true,
            gelir_duzenleme: yetki.gelir_duzenleme === 1 || yetki.gelir_duzenleme === true,
            harcama_borc_ekleme: yetki.harcama_borc_ekleme === 1 || yetki.harcama_borc_ekleme === true,
            harcama_borc_silme: yetki.harcama_borc_silme === 1 || yetki.harcama_borc_silme === true,
            harcama_borc_duzenleme: yetki.harcama_borc_duzenleme === 1 || yetki.harcama_borc_duzenleme === true,
            istek_ekleme: yetki.istek_ekleme === 1 || yetki.istek_ekleme === true,
            istek_silme: yetki.istek_silme === 1 || yetki.istek_silme === true,
            istek_duzenleme: yetki.istek_duzenleme === 1 || yetki.istek_duzenleme === true,
            hatirlatma_ekleme: yetki.hatirlatma_ekleme === 1 || yetki.hatirlatma_ekleme === true,
            hatirlatma_silme: yetki.hatirlatma_silme === 1 || yetki.hatirlatma_silme === true,
            hatirlatma_duzenleme: yetki.hatirlatma_duzenleme === 1 || yetki.hatirlatma_duzenleme === true
        });
    };

    const handleInlineSave = async (yetki) => {
        const anySelected = Object.values(inlineSelectedYetkiler).some(v => v === true);
        if (!anySelected) {
            showAlert('Uyarı', 'En az bir yetki türü seçmelisiniz', null, false);
            return;
        }
        try {
            const data = { yetkili_kullanici: yetki.yetkili_kullanici, ...inlineSelectedYetkiler };
            const response = await updateData('yetki', inlineEditingId, data);
            setInlineEditingId(null);
            setInlineSelectedYetkiler({ varlik_ekleme: false, varlik_silme: false, varlik_duzenleme: false, gelir_ekleme: false, gelir_silme: false, gelir_duzenleme: false, harcama_borc_ekleme: false, harcama_borc_silme: false, harcama_borc_duzenleme: false, istek_ekleme: false, istek_silme: false, istek_duzenleme: false, hatirlatma_ekleme: false, hatirlatma_silme: false, hatirlatma_duzenleme: false });
            await loadYetkiList();
            showAlert('Başarılı', response.message || 'Yetki güncellendi!', null, true);
        } catch (error) {
            showAlert('Hata', 'Güncelleme hatası: ' + error.message, null, false);
        }
    };

    const handleNewYetkiClick = () => {
        setIsNewYetki(true);
        setNewYetkiEmail('');
        setInlineSelectedYetkiler({ varlik_ekleme: false, varlik_silme: false, varlik_duzenleme: false, gelir_ekleme: false, gelir_silme: false, gelir_duzenleme: false, harcama_borc_ekleme: false, harcama_borc_silme: false, harcama_borc_duzenleme: false, istek_ekleme: false, istek_silme: false, istek_duzenleme: false, hatirlatma_ekleme: false, hatirlatma_silme: false, hatirlatma_duzenleme: false });
    };

    const handleNewYetkiSubmit = async () => {
        if (!newYetkiEmail || !newYetkiEmail.includes('@')) {
            showAlert('Uyarı', 'Geçerli bir email adresi giriniz', null, false);
            return;
        }
        const anySelected = Object.values(inlineSelectedYetkiler).some(v => v === true);
        if (!anySelected) {
            showAlert('Uyarı', 'En az bir yetki türü seçmelisiniz', null, false);
            return;
        }
        try {
            const data = { yetkili_kullanici: newYetkiEmail, ...inlineSelectedYetkiler };
            const response = await postData('yetki', data);
            setIsNewYetki(false);
            setNewYetkiEmail('');
            setInlineSelectedYetkiler({ varlik_ekleme: false, varlik_silme: false, varlik_duzenleme: false, gelir_ekleme: false, gelir_silme: false, gelir_duzenleme: false, harcama_borc_ekleme: false, harcama_borc_silme: false, harcama_borc_duzenleme: false, istek_ekleme: false, istek_silme: false, istek_duzenleme: false, hatirlatma_ekleme: false, hatirlatma_silme: false, hatirlatma_duzenleme: false });
            await loadYetkiList();
            showAlert('Başarılı', response.message || 'Yetki başarıyla kaydedildi!', null, true);
        } catch (error) {
            showAlert('Hata', 'Yetki verilirken bir hata oluştu: ' + error.message, null, false);
        }
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
                    right: 0,
                    bottom: 0,
                    backgroundColor: 'rgba(0, 0, 0, 0.7)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    zIndex: 10004,
                    padding: '16px',
                    boxSizing: 'border-box',
                }}
                onClick={onClose}
            >
                <div
                    style={{
                        backgroundColor: 'rgba(30, 40, 50, 0.98)',
                        border: '1px solid rgba(0, 123, 255, 0.5)',
                        borderRadius: '16px',
                        padding: 'clamp(12px, 4vw, 24px)',
                        maxWidth: '600px',
                        width: '100%',
                        maxHeight: '80vh',
                        overflow: 'auto',
                        boxShadow: '0 8px 32px rgba(0, 123, 255, 0.3)',
                        fontFamily: GLOBAL_FONT_FAMILY,
                        boxSizing: 'border-box',
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
                                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
                                            <strong style={{ color: 'rgba(0, 123, 255, 0.95)', fontSize: '12px' }}>
                                                {yetki.yetkili_kullanici}
                                            </strong>
                                            <div style={{ display: 'flex', gap: '4px' }}>
                                                {inlineEditingId !== yetki.id && (
                                                    <button
                                                        onClick={() => handleEditYetki(yetki)}
                                                        style={{ padding: '2px 8px', borderRadius: '4px', border: '1px solid rgba(0, 123, 255, 0.4)', backgroundColor: 'rgba(0, 123, 255, 0.2)', color: 'rgba(0, 123, 255, 0.9)', fontSize: '10px', cursor: 'pointer' }}
                                                    >
                                                        Düzenle
                                                    </button>
                                                )}
                                                <button
                                                    onClick={() => handleDeleteYetki(yetki.id)}
                                                    style={{ padding: '2px 8px', borderRadius: '4px', border: '1px solid rgba(220, 53, 69, 0.4)', backgroundColor: 'rgba(220, 53, 69, 0.2)', color: 'rgba(220, 53, 69, 0.9)', fontSize: '10px', cursor: 'pointer' }}
                                                >
                                                    Sil
                                                </button>
                                            </div>
                                        </div>

                                        {inlineEditingId === yetki.id ? (
                                            <div style={{ marginTop: '8px' }}>
                                                {[
                                                    { kategori: 'Varlık', ekle: 'varlik_ekleme', sil: 'varlik_silme', duzenle: 'varlik_duzenleme' },
                                                    { kategori: 'Gelir', ekle: 'gelir_ekleme', sil: 'gelir_silme', duzenle: 'gelir_duzenleme' },
                                                    { kategori: 'Harcama', ekle: 'harcama_borc_ekleme', sil: 'harcama_borc_silme', duzenle: 'harcama_borc_duzenleme' },
                                                    { kategori: 'İstek', ekle: 'istek_ekleme', sil: 'istek_silme', duzenle: 'istek_duzenleme' },
                                                    { kategori: 'Hatırlatma', ekle: 'hatirlatma_ekleme', sil: 'hatirlatma_silme', duzenle: 'hatirlatma_duzenleme' }
                                                ].map((item) => (
                                                    <div key={item.kategori} style={{ marginBottom: '6px' }}>
                                                        <div style={{ fontSize: '10px', color: 'rgba(0,123,255,0.7)', fontWeight: 'bold', marginBottom: '3px' }}>{item.kategori}</div>
                                                        <div style={{ display: 'flex', gap: '8px' }}>
                                                            {[{ id: item.ekle, label: 'Ekle' }, { id: item.sil, label: 'Sil' }, { id: item.duzenle, label: 'Düzenle' }].map((p) => (
                                                                <label key={p.id} style={{ display: 'flex', alignItems: 'center', gap: '3px', cursor: 'pointer', color: 'rgba(255,255,255,0.8)', fontSize: '11px' }}>
                                                                    <input type="checkbox" checked={inlineSelectedYetkiler[p.id]} onChange={(e) => setInlineSelectedYetkiler({ ...inlineSelectedYetkiler, [p.id]: e.target.checked })} style={{ width: '12px', height: '12px', cursor: 'pointer' }} />
                                                                    {p.label}
                                                                </label>
                                                            ))}
                                                        </div>
                                                    </div>
                                                ))}
                                                <div style={{ display: 'flex', gap: '6px', marginTop: '10px' }}>
                                                    <button onClick={() => handleInlineSave(yetki)} style={{ flex: 1, padding: '5px', borderRadius: '5px', border: '1px solid rgba(40,167,69,0.5)', backgroundColor: 'rgba(40,167,69,0.2)', color: 'rgba(40,167,69,0.95)', fontSize: '11px', cursor: 'pointer', fontWeight: 'bold' }}>Kaydet</button>
                                                    <button onClick={() => setInlineEditingId(null)} style={{ flex: 1, padding: '5px', borderRadius: '5px', border: '1px solid rgba(255,255,255,0.2)', backgroundColor: 'rgba(255,255,255,0.05)', color: 'rgba(255,255,255,0.6)', fontSize: '11px', cursor: 'pointer' }}>İptal</button>
                                                </div>
                                            </div>
                                        ) : (
                                            <div style={{ fontSize: '10px', color: 'rgba(255, 255, 255, 0.7)' }}>
                                                {[
                                                    yetki.varlik_ekleme && 'Varlık Ekle',
                                                    yetki.varlik_silme && 'Varlık Sil',
                                                    yetki.varlik_duzenleme && 'Varlık Düz',
                                                    yetki.gelir_ekleme && 'Gelir Ekle',
                                                    yetki.gelir_silme && 'Gelir Sil',
                                                    yetki.gelir_duzenleme && 'Gelir Düz',
                                                    yetki.harcama_borc_ekleme && 'Harcama Ekle',
                                                    yetki.harcama_borc_silme && 'Harcama Sil',
                                                    yetki.harcama_borc_duzenleme && 'Harcama Düz',
                                                    yetki.istek_ekleme && 'İstek Ekle',
                                                    yetki.istek_silme && 'İstek Sil',
                                                    yetki.istek_duzenleme && 'İstek Düz',
                                                    yetki.hatirlatma_ekleme && 'Hatırlatma Ekle',
                                                    yetki.hatirlatma_silme && 'Hatırlatma Sil',
                                                    yetki.hatirlatma_duzenleme && 'Hatırlatma Düz'
                                                ].filter(Boolean).join(', ')}
                                            </div>
                                        )}
                                    </div>
                                ))
                            )}

                            {/* Yeni Yetki Ver - Inline Form */}
                            {isNewYetki ? (
                                <div style={{
                                    backgroundColor: 'rgba(0, 123, 255, 0.1)',
                                    border: '1px solid rgba(0, 123, 255, 0.4)',
                                    borderRadius: '8px',
                                    padding: '12px',
                                    marginTop: '8px'
                                }}>
                                    <input
                                        type="text"
                                        autoComplete="off"
                                        data-lpignore="true"
                                        data-1p-ignore="true"
                                        data-bwignore="true"
                                        placeholder="Yetki vermek istediğiniz maili girin"
                                        value={newYetkiEmail}
                                        onChange={(e) => setNewYetkiEmail(e.target.value)}
                                        style={{
                                            width: '100%',
                                            padding: '8px',
                                            marginBottom: '10px',
                                            borderRadius: '6px',
                                            border: '1px solid rgba(0, 123, 255, 0.3)',
                                            backgroundColor: 'rgba(30, 40, 50, 0.95)',
                                            color: '#fff',
                                            fontFamily: GLOBAL_FONT_FAMILY,
                                            fontSize: '12px',
                                            outline: 'none',
                                            boxSizing: 'border-box'
                                        }}
                                    />
                                    {[
                                        { kategori: 'Varlık', ekle: 'varlik_ekleme', sil: 'varlik_silme', duzenle: 'varlik_duzenleme' },
                                        { kategori: 'Gelir', ekle: 'gelir_ekleme', sil: 'gelir_silme', duzenle: 'gelir_duzenleme' },
                                        { kategori: 'Harcama', ekle: 'harcama_borc_ekleme', sil: 'harcama_borc_silme', duzenle: 'harcama_borc_duzenleme' },
                                        { kategori: 'İstek', ekle: 'istek_ekleme', sil: 'istek_silme', duzenle: 'istek_duzenleme' },
                                        { kategori: 'Hatırlatma', ekle: 'hatirlatma_ekleme', sil: 'hatirlatma_silme', duzenle: 'hatirlatma_duzenleme' }
                                    ].map((item) => (
                                        <div key={item.kategori} style={{ marginBottom: '6px' }}>
                                            <div style={{ fontSize: '10px', color: 'rgba(0,123,255,0.7)', fontWeight: 'bold', marginBottom: '3px' }}>{item.kategori}</div>
                                            <div style={{ display: 'flex', gap: '8px' }}>
                                                {[{ id: item.ekle, label: 'Ekle' }, { id: item.sil, label: 'Sil' }, { id: item.duzenle, label: 'Düzenle' }].map((p) => (
                                                    <label key={p.id} style={{ display: 'flex', alignItems: 'center', gap: '3px', cursor: 'pointer', color: 'rgba(255,255,255,0.8)', fontSize: '11px' }}>
                                                        <input type="checkbox" checked={inlineSelectedYetkiler[p.id]} onChange={(e) => setInlineSelectedYetkiler({ ...inlineSelectedYetkiler, [p.id]: e.target.checked })} style={{ width: '12px', height: '12px', cursor: 'pointer' }} />
                                                        {p.label}
                                                    </label>
                                                ))}
                                            </div>
                                        </div>
                                    ))}
                                    <div style={{ display: 'flex', gap: '6px', marginTop: '10px' }}>
                                        <button onClick={handleNewYetkiSubmit} style={{ flex: 1, padding: '6px', borderRadius: '5px', border: '1px solid rgba(40,167,69,0.5)', backgroundColor: 'rgba(40,167,69,0.2)', color: 'rgba(40,167,69,0.95)', fontSize: '11px', cursor: 'pointer', fontWeight: 'bold' }}>Kaydet</button>
                                        <button onClick={() => setIsNewYetki(false)} style={{ flex: 1, padding: '6px', borderRadius: '5px', border: '1px solid rgba(255,255,255,0.2)', backgroundColor: 'rgba(255,255,255,0.05)', color: 'rgba(255,255,255,0.6)', fontSize: '11px', cursor: 'pointer' }}>İptal</button>
                                    </div>
                                </div>
                            ) : (
                                <button
                                    onClick={handleNewYetkiClick}
                                    style={{
                                        width: '100%',
                                        padding: '10px',
                                        marginTop: '8px',
                                        borderRadius: '8px',
                                        border: '1px solid rgba(40, 167, 69, 0.5)',
                                        backgroundColor: 'rgba(40, 167, 69, 0.15)',
                                        color: 'rgba(40, 167, 69, 0.95)',
                                        fontFamily: GLOBAL_FONT_FAMILY,
                                        fontSize: '13px',
                                        fontWeight: 'bold',
                                        cursor: 'pointer'
                                    }}
                                >
                                    + Yeni Yetki Ver
                                </button>
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
                                            marginBottom: '6px'
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
                                        <div style={{ fontSize: '10px', color: 'rgba(255, 255, 255, 0.7)', marginBottom: '10px' }}>
                                            {[
                                                yetki.varlik_ekleme && 'Varlık',
                                                yetki.gelir_ekleme && 'Gelir',
                                                yetki.harcama_borc_ekleme && 'Harcama-Borç',
                                                yetki.istek_ekleme && 'İstek',
                                                yetki.hatirlatma_ekleme && 'Hatırlatma'
                                            ].filter(Boolean).join(', ')}
                                        </div>
                                        <button
                                            onClick={() => {
                                                switchAccount(yetki);
                                                onClose();
                                            }}
                                            style={{
                                                width: '100%',
                                                padding: '6px',
                                                borderRadius: '6px',
                                                border: `1px solid ${activeAccount?.username === yetki.yetki_veren_kullanici ? 'rgba(34,197,94,0.7)' : 'rgba(0,123,255,0.4)'}`,
                                                backgroundColor: activeAccount?.username === yetki.yetki_veren_kullanici ? 'rgba(34,197,94,0.2)' : 'rgba(0,123,255,0.12)',
                                                color: activeAccount?.username === yetki.yetki_veren_kullanici ? 'rgba(34,197,94,0.95)' : 'rgba(0,123,255,0.9)',
                                                fontSize: '11px',
                                                cursor: 'pointer',
                                                fontWeight: 'bold',
                                            }}
                                        >
                                            {activeAccount?.username === yetki.yetki_veren_kullanici ? '✓ Aktif Hesap' : 'Bu Hesabı Kullan'}
                                        </button>
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
                            padding: 'clamp(12px, 4vw, 24px)',
                            maxWidth: '450px',
                            width: '100%',
                            boxShadow: '0 8px 32px rgba(255, 193, 7, 0.3)',
                            fontFamily: GLOBAL_FONT_FAMILY,
                            boxSizing: 'border-box',
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
                            type="text"
                            autoComplete="off"
                            data-lpignore="true"
                            data-1p-ignore="true"
                            data-bwignore="true"
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
                        zIndex: 10006,
                        padding: '16px',
                        boxSizing: 'border-box',
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
                            width: '100%',
                            boxSizing: 'border-box',
                            padding: 'clamp(12px, 4vw, 24px)',
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
