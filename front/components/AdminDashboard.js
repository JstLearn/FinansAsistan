// front/components/AdminDashboard.js
import React, { useState, useEffect, useCallback } from 'react';
import {
    View,
    Text,
    ScrollView,
    TouchableOpacity,
    TextInput,
    Modal,
    StyleSheet,
    Animated
} from 'react-native';
import { postData, fetchData, deleteData } from '../services/api';

const ADMIN_FONT = "'JetBrains Mono', 'Fira Code', 'SF Mono', 'Cascadia Code', monospace";

const AdminDashboard = ({ onClose }) => {
    const [tables, setTables] = useState([]);
    const [selectedTable, setSelectedTable] = useState(null);
    const [tableData, setTableData] = useState({ columns: [], rows: [], pagination: {} });
    const [loading, setLoading] = useState(false);
    const [page, setPage] = useState(1);
    const [showInsertModal, setShowInsertModal] = useState(false);
    const [showEditModal, setShowEditModal] = useState(false);
    const [showDeleteModal, setShowDeleteModal] = useState(false);
    const [editingRow, setEditingRow] = useState(null);
    const [deletingRow, setDeletingRow] = useState(null);
    const [formData, setFormData] = useState({});
    const [customQuery, setCustomQuery] = useState('');
    const [queryResult, setQueryResult] = useState(null);
    const [showQueryPanel, setShowQueryPanel] = useState(false);
    const [sidebarAnim] = useState(new Animated.Value(0));

    // Fade-in animation
    useEffect(() => {
        Animated.timing(sidebarAnim, {
            toValue: 1,
            duration: 400,
            useNativeDriver: true
        }).start();
    }, []);

    // Load tables on mount
    useEffect(() => {
        loadTables();
    }, []);

    // Load table data when table changes
    useEffect(() => {
        if (selectedTable) {
            loadTableData(selectedTable, page);
        }
    }, [selectedTable, page]);

    const loadTables = async () => {
        try {
            const res = await fetchData('admin/tables');
            if (res.success) {
                setTables(res.data);
                if (res.data.length > 0) {
                    setSelectedTable(res.data[0].name);
                }
            }
        } catch (err) {
            console.error('Load tables error:', err);
        }
    };

    const loadTableData = async (table, pageNum) => {
        setLoading(true);
        try {
            const res = await fetchData(`admin/tables/${table}?page=${pageNum}&limit=50`);
            if (res.success) {
                setTableData(res.data);
            }
        } catch (err) {
            console.error('Load table data error:', err);
        } finally {
            setLoading(false);
        }
    };

    const handleInsert = async () => {
        try {
            const res = await postData(`admin/tables/${selectedTable}`, formData);
            if (res.success) {
                setShowInsertModal(false);
                setFormData({});
                loadTableData(selectedTable, page);
            } else {
                alert('Hata: ' + res.message);
            }
        } catch (err) {
            alert('Ekleme hatası: ' + err.message);
        }
    };

    const handleUpdate = async () => {
        try {
            const res = await postData(`admin/tables/${selectedTable}/${editingRow.id}`, formData);
            if (res.success) {
                setShowEditModal(false);
                setEditingRow(null);
                setFormData({});
                loadTableData(selectedTable, page);
            } else {
                alert('Hata: ' + res.message);
            }
        } catch (err) {
            alert('Güncelleme hatası: ' + err.message);
        }
    };

    const handleDelete = async () => {
        try {
            const res = await deleteData(`admin/tables/${selectedTable}`, deletingRow.id);

            if (res.success) {
                setShowDeleteModal(false);
                setDeletingRow(null);
                loadTableData(selectedTable, page);
            } else {
                alert('Hata: ' + res.message);
            }
        } catch (err) {
            alert('Silme hatası: ' + err.message);
        }
    };

    const handleCustomQuery = async () => {
        if (!customQuery.trim()) return;
        setLoading(true);
        try {
            const res = await postData('admin/query', { sql: customQuery });
            setQueryResult(res);
        } catch (err) {
            setQueryResult({ success: false, message: err.message });
        } finally {
            setLoading(false);
        }
    };

    const openEditModal = (row) => {
        setEditingRow(row);
        setFormData({ ...row });
        setShowEditModal(true);
    };

    const openDeleteModal = (row) => {
        setDeletingRow(row);
        setShowDeleteModal(true);
    };

    const openInsertModal = () => {
        const newData = {};
        tableData.columns.forEach(col => {
            if (col.column_name !== 'id' && col.column_name !== 'tarih' && col.column_name !== 'created_at') {
                newData[col.column_name] = '';
            }
        });
        setFormData(newData);
        setShowInsertModal(true);
    };

    const renderValue = (value) => {
        if (value === null) return <span style={{ color: '#666', fontStyle: 'italic' }}>NULL</span>;
        if (typeof value === 'boolean') return value ? '✓' : '✗';
        if (typeof value === 'object') return JSON.stringify(value);
        return String(value);
    };

    return (
        <View style={styles.container}>
            {/* Header */}
            <View style={styles.header}>
                <View style={styles.headerLeft}>
                    <Text style={styles.headerTitle}>◆ ADMIN PANEL</Text>
                    <Text style={styles.headerSub}>Veritabanı Yönetim Sistemi</Text>
                </View>
                <TouchableOpacity style={styles.closeBtn} onPress={onClose}>
                    <Text style={styles.closeBtnText}>✕</Text>
                </TouchableOpacity>
            </View>

            <View style={styles.body}>
                {/* Sidebar */}
                <Animated.View style={[styles.sidebar, { opacity: sidebarAnim }]}>
                    <View style={styles.sidebarHeader}>
                        <Text style={styles.sidebarTitle}>TABLOLAR</Text>
                        <TouchableOpacity
                            style={styles.queryToggle}
                            onPress={() => setShowQueryPanel(!showQueryPanel)}
                        >
                            <Text style={styles.queryToggleText}>SQL</Text>
                        </TouchableOpacity>
                    </View>
                    <ScrollView style={styles.tableList}>
                        {tables.map((t) => (
                            <TouchableOpacity
                                key={t.name}
                                style={[
                                    styles.tableItem,
                                    selectedTable === t.name && styles.tableItemActive
                                ]}
                                onPress={() => { setSelectedTable(t.name); setPage(1); }}
                            >
                                <Text style={styles.tableName}>{t.name}</Text>
                                <Text style={styles.tableCount}>{t.rowCount}</Text>
                            </TouchableOpacity>
                        ))}
                    </ScrollView>
                </Animated.View>

                {/* Main Content */}
                <View style={styles.main}>
                    {showQueryPanel ? (
                        /* SQL Query Panel */
                        <View style={styles.queryPanel}>
                            <Text style={styles.panelTitle}>◆ SQL KOMUT</Text>
                            <TextInput
                                style={styles.queryInput}
                                value={customQuery}
                                onChangeText={setCustomQuery}
                                placeholder="SELECT * FROM kullanicilar LIMIT 10;"
                                placeholderTextColor="#555"
                                multiline
                            />
                            <TouchableOpacity
                                style={styles.runBtn}
                                onPress={handleCustomQuery}
                                disabled={loading}
                            >
                                <Text style={styles.runBtnText}>▶ ÇALIŞTIR</Text>
                            </TouchableOpacity>

                            {queryResult && (
                                <ScrollView style={styles.queryResult}>
                                    {queryResult.success ? (
                                        <>
                                            <Text style={styles.resultInfo}>
                                                {queryResult.rowCount} satın etkilendi • {queryResult.command}
                                            </Text>
                                            <ScrollView horizontal>
                                                <Text style={styles.resultData}>
                                                    {JSON.stringify(queryResult.data, null, 2)}
                                                </Text>
                                            </ScrollView>
                                        </>
                                    ) : (
                                        <Text style={styles.errorText}>{queryResult.message}</Text>
                                    )}
                                </ScrollView>
                            )}
                        </View>
                    ) : (
                        /* Data Grid */
                        <View style={styles.dataPanel}>
                            {/* Toolbar */}
                            <View style={styles.toolbar}>
                                <Text style={styles.toolbarTitle}>
                                    {selectedTable?.toUpperCase()} — {tableData.pagination.total} kayıt
                                </Text>
                                <View style={styles.toolbarActions}>
                                    <TouchableOpacity style={styles.insertBtn} onPress={openInsertModal}>
                                        <Text style={styles.insertBtnText}>+ Ekle</Text>
                                    </TouchableOpacity>
                                    <TouchableOpacity
                                        style={styles.refreshBtn}
                                        onPress={() => loadTableData(selectedTable, page)}
                                    >
                                        <Text style={styles.refreshBtnText}>↻</Text>
                                    </TouchableOpacity>
                                </View>
                            </View>

                            {/* Loading */}
                            {loading && (
                                <View style={styles.loading}>
                                    <Text style={styles.loadingText}>Yükleniyor...</Text>
                                </View>
                            )}

                            {/* Data Table */}
                            {!loading && tableData.rows.length > 0 && (
                                <ScrollView style={styles.tableContainer} horizontal>
                                    <View>
                                        {/* Header */}
                                        <View style={styles.tableHeader}>
                                            {tableData.columns.map((col) => (
                                                <View key={col.column_name} style={styles.headerCell}>
                                                    <Text style={styles.headerCellText}>{col.column_name}</Text>
                                                </View>
                                            ))}
                                            <View style={[styles.headerCell, styles.actionsCell]}>
                                                <Text style={styles.headerCellText}>İŞLEMLER</Text>
                                            </View>
                                        </View>

                                        {/* Rows */}
                                        <ScrollView style={styles.tableBody}>
                                            {tableData.rows.map((row) => (
                                                <View key={row.id} style={styles.tableRow}>
                                                    {tableData.columns.map((col) => (
                                                        <View key={col.column_name} style={styles.dataCell}>
                                                            <Text style={styles.dataCellText} numberOfLines={1}>
                                                                {renderValue(row[col.column_name])}
                                                            </Text>
                                                        </View>
                                                    ))}
                                                    <View style={[styles.dataCell, styles.actionsCell]}>
                                                        <TouchableOpacity
                                                            style={styles.editBtn}
                                                            onPress={() => openEditModal(row)}
                                                        >
                                                            <Text style={styles.editBtnText}>Düzenle</Text>
                                                        </TouchableOpacity>
                                                        <TouchableOpacity
                                                            style={styles.deleteBtn}
                                                            onPress={() => openDeleteModal(row)}
                                                        >
                                                            <Text style={styles.deleteBtnText}>Sil</Text>
                                                        </TouchableOpacity>
                                                    </View>
                                                </View>
                                            ))}
                                        </ScrollView>
                                    </View>
                                </ScrollView>
                            )}

                            {/* Pagination */}
                            {tableData.pagination.totalPages > 1 && (
                                <View style={styles.pagination}>
                                    <TouchableOpacity
                                        style={styles.pageBtn}
                                        onPress={() => setPage(Math.max(1, page - 1))}
                                        disabled={page === 1}
                                    >
                                        <Text style={styles.pageBtnText}>◀</Text>
                                    </TouchableOpacity>
                                    <Text style={styles.pageInfo}>
                                        Sayfa {page} / {tableData.pagination.totalPages}
                                    </Text>
                                    <TouchableOpacity
                                        style={styles.pageBtn}
                                        onPress={() => setPage(Math.min(tableData.pagination.totalPages, page + 1))}
                                        disabled={page === tableData.pagination.totalPages}
                                    >
                                        <Text style={styles.pageBtnText}>▶</Text>
                                    </TouchableOpacity>
                                </View>
                            )}
                        </View>
                    )}
                </View>
            </View>

            {/* Insert Modal */}
            <Modal visible={showInsertModal} transparent animationType="fade">
                <View style={styles.modalOverlay}>
                    <View style={styles.modal}>
                        <Text style={styles.modalTitle}>◆ YENİ KAYIT EKLE — {selectedTable}</Text>
                        <ScrollView style={styles.formScroll}>
                            {tableData.columns.filter(c => c.column_name !== 'id' && c.column_name !== 'tarih').map((col) => (
                                <View key={col.column_name} style={styles.formField}>
                                    <Text style={styles.formLabel}>{col.column_name}</Text>
                                    <TextInput
                                        style={styles.formInput}
                                        value={formData[col.column_name] || ''}
                                        onChangeText={(v) => setFormData({ ...formData, [col.column_name]: v })}
                                        placeholder={col.data_type}
                                        placeholderTextColor="#555"
                                    />
                                </View>
                            ))}
                        </ScrollView>
                        <View style={styles.modalActions}>
                            <TouchableOpacity style={styles.cancelBtn} onPress={() => setShowInsertModal(false)}>
                                <Text style={styles.cancelBtnText}>İPTAL</Text>
                            </TouchableOpacity>
                            <TouchableOpacity style={styles.saveBtn} onPress={handleInsert}>
                                <Text style={styles.saveBtnText}>KAYDET</Text>
                            </TouchableOpacity>
                        </View>
                    </View>
                </View>
            </Modal>

            {/* Edit Modal */}
            <Modal visible={showEditModal} transparent animationType="fade">
                <View style={styles.modalOverlay}>
                    <View style={styles.modal}>
                        <Text style={styles.modalTitle}>◆ KAYIT DÜZENLE — {selectedTable}</Text>
                        <ScrollView style={styles.formScroll}>
                            {tableData.columns.filter(c => c.column_name !== 'id').map((col) => (
                                <View key={col.column_name} style={styles.formField}>
                                    <Text style={styles.formLabel}>{col.column_name}</Text>
                                    <TextInput
                                        style={styles.formInput}
                                        value={formData[col.column_name] || ''}
                                        onChangeText={(v) => setFormData({ ...formData, [col.column_name]: v })}
                                        placeholder={col.data_type}
                                        placeholderTextColor="#555"
                                    />
                                </View>
                            ))}
                        </ScrollView>
                        <View style={styles.modalActions}>
                            <TouchableOpacity style={styles.cancelBtn} onPress={() => setShowEditModal(false)}>
                                <Text style={styles.cancelBtnText}>İPTAL</Text>
                            </TouchableOpacity>
                            <TouchableOpacity style={styles.saveBtn} onPress={handleUpdate}>
                                <Text style={styles.saveBtnText}>GÜNCELLE</Text>
                            </TouchableOpacity>
                        </View>
                    </View>
                </View>
            </Modal>

            {/* Delete Confirmation Modal */}
            <Modal visible={showDeleteModal} transparent animationType="fade">
                <View style={styles.modalOverlay}>
                    <View style={[styles.modal, styles.deleteModal]}>
                        <Text style={styles.modalTitle}>⚠ KAYIT SİL</Text>
                        <Text style={styles.deleteText}>
                            Bu kaydı silmek istediğinize emin misiniz?
                        </Text>
                        {deletingRow && (
                            <Text style={styles.deletePreview}>
                                ID: {deletingRow.id}
                            </Text>
                        )}
                        <View style={styles.modalActions}>
                            <TouchableOpacity style={styles.cancelBtn} onPress={() => setShowDeleteModal(false)}>
                                <Text style={styles.cancelBtnText}>İPTAL</Text>
                            </TouchableOpacity>
                            <TouchableOpacity style={styles.confirmDeleteBtn} onPress={handleDelete}>
                                <Text style={styles.confirmDeleteBtnText}>SİL</Text>
                            </TouchableOpacity>
                        </View>
                    </View>
                </View>
            </Modal>
        </View>
    );
};

const styles = StyleSheet.create({
    container: {
        flex: 1,
        backgroundColor: '#0a0e17',
    },
    header: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingHorizontal: 20,
        paddingVertical: 16,
        borderBottom: '1px solid #1a2744',
        backgroundColor: '#0d1424',
    },
    headerLeft: {
        flexDirection: 'column',
    },
    headerTitle: {
        fontFamily: ADMIN_FONT,
        fontSize: 18,
        fontWeight: 'bold',
        color: '#00f5d4',
        letterSpacing: 2,
    },
    headerSub: {
        fontFamily: ADMIN_FONT,
        fontSize: 10,
        color: '#4a5568',
        marginTop: 4,
        letterSpacing: 1,
    },
    closeBtn: {
        width: 36,
        height: 36,
        borderRadius: 8,
        backgroundColor: '#1a2744',
        justifyContent: 'center',
        alignItems: 'center',
    },
    closeBtnText: {
        color: '#e53e3e',
        fontSize: 18,
        fontWeight: 'bold',
    },
    body: {
        flex: 1,
        flexDirection: 'row',
    },
    sidebar: {
        width: 220,
        backgroundColor: '#0d1424',
        borderRight: '1px solid #1a2744',
    },
    sidebarHeader: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        padding: 16,
        borderBottom: '1px solid #1a2744',
    },
    sidebarTitle: {
        fontFamily: ADMIN_FONT,
        fontSize: 10,
        color: '#4a5568',
        letterSpacing: 2,
    },
    queryToggle: {
        paddingHorizontal: 8,
        paddingVertical: 4,
        backgroundColor: '#1a2744',
        borderRadius: 4,
    },
    queryToggleText: {
        fontFamily: ADMIN_FONT,
        fontSize: 10,
        color: '#f72585',
        fontWeight: 'bold',
    },
    tableList: {
        flex: 1,
    },
    tableItem: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        paddingVertical: 12,
        paddingHorizontal: 16,
        borderBottom: '1px solid #1a2744',
        cursor: 'pointer',
    },
    tableItemActive: {
        backgroundColor: '#1a2744',
        borderLeft: '3px solid #00f5d4',
    },
    tableName: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        color: '#e2e8f0',
    },
    tableCount: {
        fontFamily: ADMIN_FONT,
        fontSize: 10,
        color: '#4a5568',
        backgroundColor: '#1a2744',
        paddingHorizontal: 6,
        paddingVertical: 2,
        borderRadius: 4,
    },
    main: {
        flex: 1,
        backgroundColor: '#0a0e17',
    },
    dataPanel: {
        flex: 1,
        padding: 16,
    },
    toolbar: {
        flexDirection: 'row',
        justifyContent: 'space-between',
        alignItems: 'center',
        marginBottom: 16,
    },
    toolbarTitle: {
        fontFamily: ADMIN_FONT,
        fontSize: 14,
        color: '#00f5d4',
        letterSpacing: 1,
    },
    toolbarActions: {
        flexDirection: 'row',
        gap: 8,
    },
    insertBtn: {
        paddingHorizontal: 16,
        paddingVertical: 8,
        backgroundColor: '#00f5d4',
        borderRadius: 6,
    },
    insertBtnText: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        fontWeight: 'bold',
        color: '#0a0e17',
    },
    refreshBtn: {
        width: 32,
        height: 32,
        borderRadius: 6,
        backgroundColor: '#1a2744',
        justifyContent: 'center',
        alignItems: 'center',
    },
    refreshBtnText: {
        fontSize: 16,
        color: '#00f5d4',
    },
    loading: {
        padding: 40,
        alignItems: 'center',
    },
    loadingText: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        color: '#4a5568',
    },
    tableContainer: {
        flex: 1,
    },
    tableHeader: {
        flexDirection: 'row',
        backgroundColor: '#1a2744',
        borderRadius: 6,
        marginBottom: 4,
    },
    headerCell: {
        minWidth: 120,
        paddingVertical: 10,
        paddingHorizontal: 12,
    },
    headerCellText: {
        fontFamily: ADMIN_FONT,
        fontSize: 10,
        fontWeight: 'bold',
        color: '#00f5d4',
        letterSpacing: 1,
    },
    actionsCell: {
        minWidth: 140,
    },
    tableBody: {
        backgroundColor: '#0d1424',
        borderRadius: 6,
    },
    tableRow: {
        flexDirection: 'row',
        borderBottom: '1px solid #1a2744',
    },
    dataCell: {
        minWidth: 120,
        paddingVertical: 8,
        paddingHorizontal: 12,
        justifyContent: 'center',
    },
    dataCellText: {
        fontFamily: ADMIN_FONT,
        fontSize: 11,
        color: '#e2e8f0',
    },
    editBtn: {
        paddingHorizontal: 8,
        paddingVertical: 4,
        backgroundColor: '#2d3748',
        borderRadius: 4,
        marginRight: 6,
    },
    editBtnText: {
        fontFamily: ADMIN_FONT,
        fontSize: 10,
        color: '#fbd38d',
    },
    deleteBtn: {
        paddingHorizontal: 8,
        paddingVertical: 4,
        backgroundColor: '#2d1a1a',
        borderRadius: 4,
    },
    deleteBtnText: {
        fontFamily: ADMIN_FONT,
        fontSize: 10,
        color: '#fc8181',
    },
    pagination: {
        flexDirection: 'row',
        justifyContent: 'center',
        alignItems: 'center',
        paddingVertical: 16,
        gap: 16,
    },
    pageBtn: {
        width: 36,
        height: 36,
        borderRadius: 6,
        backgroundColor: '#1a2744',
        justifyContent: 'center',
        alignItems: 'center',
    },
    pageBtnText: {
        fontFamily: ADMIN_FONT,
        fontSize: 14,
        color: '#00f5d4',
    },
    pageInfo: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        color: '#4a5568',
    },
    queryPanel: {
        flex: 1,
        padding: 16,
    },
    panelTitle: {
        fontFamily: ADMIN_FONT,
        fontSize: 14,
        color: '#f72585',
        letterSpacing: 1,
        marginBottom: 16,
    },
    queryInput: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        color: '#e2e8f0',
        backgroundColor: '#0d1424',
        border: '1px solid #1a2744',
        borderRadius: 6,
        padding: 12,
        minHeight: 80,
        textAlignVertical: 'top',
    },
    runBtn: {
        alignSelf: 'flex-start',
        paddingHorizontal: 20,
        paddingVertical: 10,
        backgroundColor: '#f72585',
        borderRadius: 6,
        marginTop: 12,
    },
    runBtnText: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        fontWeight: 'bold',
        color: '#fff',
    },
    queryResult: {
        flex: 1,
        marginTop: 16,
        backgroundColor: '#0d1424',
        borderRadius: 6,
        padding: 12,
    },
    resultInfo: {
        fontFamily: ADMIN_FONT,
        fontSize: 10,
        color: '#4a5568',
        marginBottom: 8,
    },
    resultData: {
        fontFamily: ADMIN_FONT,
        fontSize: 11,
        color: '#e2e8f0',
    },
    errorText: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        color: '#fc8181',
    },
    modalOverlay: {
        flex: 1,
        backgroundColor: 'rgba(0,0,0,0.8)',
        justifyContent: 'center',
        alignItems: 'center',
        padding: 20,
    },
    modal: {
        backgroundColor: '#0d1424',
        border: '1px solid #1a2744',
        borderRadius: 12,
        padding: 24,
        width: '100%',
        maxWidth: 500,
        maxHeight: '80%',
    },
    deleteModal: {
        maxWidth: 400,
    },
    modalTitle: {
        fontFamily: ADMIN_FONT,
        fontSize: 14,
        color: '#00f5d4',
        letterSpacing: 1,
        marginBottom: 16,
    },
    formScroll: {
        maxHeight: 400,
    },
    formField: {
        marginBottom: 12,
    },
    formLabel: {
        fontFamily: ADMIN_FONT,
        fontSize: 10,
        color: '#4a5568',
        marginBottom: 4,
        letterSpacing: 1,
        textTransform: 'uppercase',
    },
    formInput: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        color: '#e2e8f0',
        backgroundColor: '#1a2744',
        border: '1px solid #2d3748',
        borderRadius: 6,
        padding: 10,
    },
    modalActions: {
        flexDirection: 'row',
        justifyContent: 'flex-end',
        gap: 12,
        marginTop: 20,
    },
    cancelBtn: {
        paddingHorizontal: 16,
        paddingVertical: 10,
        backgroundColor: '#1a2744',
        borderRadius: 6,
    },
    cancelBtnText: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        color: '#4a5568',
    },
    saveBtn: {
        paddingHorizontal: 20,
        paddingVertical: 10,
        backgroundColor: '#00f5d4',
        borderRadius: 6,
    },
    saveBtnText: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        fontWeight: 'bold',
        color: '#0a0e17',
    },
    deleteText: {
        fontFamily: ADMIN_FONT,
        fontSize: 13,
        color: '#e2e8f0',
        marginBottom: 12,
    },
    deletePreview: {
        fontFamily: ADMIN_FONT,
        fontSize: 11,
        color: '#fc8181',
        backgroundColor: '#2d1a1a',
        padding: 8,
        borderRadius: 4,
        marginBottom: 8,
    },
    confirmDeleteBtn: {
        paddingHorizontal: 20,
        paddingVertical: 10,
        backgroundColor: '#e53e3e',
        borderRadius: 6,
    },
    confirmDeleteBtnText: {
        fontFamily: ADMIN_FONT,
        fontSize: 12,
        fontWeight: 'bold',
        color: '#fff',
    },
});

export default AdminDashboard;
