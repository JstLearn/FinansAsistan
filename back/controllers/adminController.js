const { query, pool } = require('../config/db');

// Allowed tables for admin access (security - prevent accessing system tables)
const ALLOWED_TABLES = [
    'kullanicilar',
    'varliklar',
    'gelir_alacak',
    'harcama_borc',
    'gider',
    'istekler',
    'hatirlatmalar'
];

// Validate table name to prevent SQL injection
const isAllowedTable = (tableName) => {
    return ALLOWED_TABLES.includes(tableName.toLowerCase());
};

// Validate column name to prevent SQL injection
const isValidColumnName = (name) => {
    return /^[a-zA-Z_][a-zA-Z0-9_]*$/.test(name);
};

// List all accessible tables with row count
const listTables = async (req, res) => {
    try {
        const result = await query(`
            SELECT
                table_name,
                (SELECT COUNT(*) FROM information_schema.tables t WHERE t.table_name = x.table_name AND t.table_schema = x.table_schema) as row_count
            FROM information_schema.tables x
            WHERE table_schema = 'public'
            AND table_name = ANY($1)
            ORDER BY table_name
        `, [ALLOWED_TABLES]);

        res.json({
            success: true,
            data: result.rows.map(r => ({
                name: r.table_name,
                rowCount: parseInt(r.row_count)
            }))
        });
    } catch (error) {
        console.error('Admin listTables error:', error);
        res.status(500).json({ success: false, message: 'Sunucu hatası' });
    }
};

// Get table data with pagination
const getTableData = async (req, res) => {
    try {
        const { table } = req.params;
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;
        const offset = (page - 1) * limit;

        if (!isAllowedTable(table)) {
            return res.status(403).json({ success: false, message: 'Bu tabloya erişim yetkiniz yok' });
        }

        // Get column info
        const columnsResult = await query(`
            SELECT column_name, data_type, is_nullable
            FROM information_schema.columns
            WHERE table_name = $1 AND table_schema = 'public'
            ORDER BY ordinal_position
        `, [table]);

        // Get row count
        const countResult = await query(`SELECT COUNT(*) FROM ${table}`);

        // Get paginated data
        const dataResult = await query(
            `SELECT * FROM ${table} ORDER BY id OFFSET $1 LIMIT $2`,
            [offset, limit]
        );

        res.json({
            success: true,
            data: {
                columns: columnsResult.rows,
                rows: dataResult.rows,
                pagination: {
                    page,
                    limit,
                    offset,
                    total: parseInt(countResult.rows[0].count),
                    totalPages: Math.ceil(countResult.rows[0].count / limit)
                }
            }
        });
    } catch (error) {
        console.error('Admin getTableData error:', error);
        res.status(500).json({ success: false, message: 'Sorgu hatası: ' + error.message });
    }
};

// Insert a new row
const insertRow = async (req, res) => {
    try {
        const { table } = req.params;
        const data = req.body;

        if (!isAllowedTable(table)) {
            return res.status(403).json({ success: false, message: 'Bu tabloya erişim yetkiniz yok' });
        }

        // Remove id if provided (auto-increment)
        delete data.id;

        const keys = Object.keys(data);
        const values = Object.values(data);

        // Validate column names to prevent SQL injection
        const invalidColumn = keys.find(k => !isValidColumnName(k));
        if (invalidColumn) {
            return res.status(400).json({ success: false, message: `Geçersiz sütun adı: ${invalidColumn}` });
        }

        const placeholders = keys.map((_, i) => `$${i + 1}`).join(', ');
        const columns = keys.join(', ');

        const result = await query(
            `INSERT INTO ${table} (${columns}) VALUES (${placeholders}) RETURNING *`,
            values
        );

        res.json({ success: true, data: result.rows[0] });
    } catch (error) {
        console.error('Admin insertRow error:', error);
        res.status(500).json({ success: false, message: 'Ekleme hatası: ' + error.message });
    }
};

// Update a row
const updateRow = async (req, res) => {
    try {
        const { table, id } = req.params;
        const data = req.body;

        if (!isAllowedTable(table)) {
            return res.status(403).json({ success: false, message: 'Bu tabloya erişim yetkiniz yok' });
        }

        delete data.id; // Prevent updating id

        const keys = Object.keys(data);
        const values = Object.values(data);

        // Validate column names to prevent SQL injection
        const invalidColumn = keys.find(k => !isValidColumnName(k));
        if (invalidColumn) {
            return res.status(400).json({ success: false, message: `Geçersiz sütun adı: ${invalidColumn}` });
        }

        const setClause = keys.map((key, i) => `${key} = $${i + 1}`).join(', ');

        const result = await query(
            `UPDATE ${table} SET ${setClause} WHERE id = $${keys.length + 1} RETURNING *`,
            [...values, id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Kayıt bulunamadı' });
        }

        res.json({ success: true, data: result.rows[0] });
    } catch (error) {
        console.error('Admin updateRow error:', error);
        res.status(500).json({ success: false, message: 'Güncelleme hatası: ' + error.message });
    }
};

// Delete a row
const deleteRow = async (req, res) => {
    try {
        const { table, id } = req.params;

        if (!isAllowedTable(table)) {
            return res.status(403).json({ success: false, message: 'Bu tabloya erişim yetkiniz yok' });
        }

        const result = await query(`DELETE FROM ${table} WHERE id = $1 RETURNING *`, [id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Kayıt bulunamadı' });
        }

        res.json({ success: true, message: 'Kayıt silindi', data: result.rows[0] });
    } catch (error) {
        console.error('Admin deleteRow error:', error);
        res.status(500).json({ success: false, message: 'Silme hatası: ' + error.message });
    }
};

// Run custom SQL query (dangerous but powerful)
const executeQuery = async (req, res) => {
    try {
        const { sql } = req.body;

        if (!sql || typeof sql !== 'string') {
            return res.status(400).json({ success: false, message: 'SQL sorgusu gerekli' });
        }

        // Block multiple statements (semicolon)
        if (sql.includes(';')) {
            return res.status(403).json({ success: false, message: 'Birden fazla sorgu izin verilmiyor' });
        }

        const upperSql = sql.trim().toUpperCase();

        // Only allow SELECT, INSERT, UPDATE, DELETE
        const firstWord = upperSql.split(/\s+/)[0];
        if (!['SELECT', 'INSERT', 'UPDATE', 'DELETE'].includes(firstWord)) {
            return res.status(403).json({ success: false, message: 'Sadece SELECT, INSERT, UPDATE, DELETE izin var' });
        }

        // Block dangerous operations (case-insensitive)
        const dangerous = ['DROP', 'TRUNCATE', 'ALTER', 'CREATE', 'GRANT', 'REVOKE', 'EXECUTE', 'EXEC', 'CALL', 'INTO OUTFILE', 'INTO DUMPFILE'];
        if (dangerous.some(k => upperSql.includes(k))) {
            return res.status(403).json({ success: false, message: 'Bu operasyon izin verilmiyor' });
        }

        const result = await query(sql);

        res.json({
            success: true,
            data: result.rows,
            rowCount: result.rowCount,
            command: result.command
        });
    } catch (error) {
        console.error('Admin executeQuery error:', error);
        res.status(500).json({ success: false, message: 'Sorgu hatası: ' + error.message });
    }
};

module.exports = {
    listTables,
    getTableData,
    insertRow,
    updateRow,
    deleteRow,
    executeQuery
};
