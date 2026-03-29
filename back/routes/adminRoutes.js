const express = require('express');
const router = express.Router();
const { query } = require('../config/db');
const authMiddleware = require('../middleware/authMiddleware');
const {
    listTables,
    getTableData,
    insertRow,
    updateRow,
    deleteRow,
    executeQuery
} = require('../controllers/adminController');

// Admin check middleware - only admin users can access
const adminMiddleware = async (req, res, next) => {
    try {
        const userId = req.user.id;

        const result = await query(
            'SELECT admin FROM kullanicilar WHERE id = $1',
            [userId]
        );

        if (result.rows.length === 0 || result.rows[0].admin !== true) {
            return res.status(403).json({
                success: false,
                message: 'Admin yetkisi gerekli'
            });
        }

        next();
    } catch (error) {
        console.error('Admin middleware error:', error);
        res.status(500).json({ success: false, message: 'Yetki kontrolü başarısız' });
    }
};

// Apply auth AND admin middleware to all routes
router.use(authMiddleware);
router.use(adminMiddleware);

// GET /api/admin/tables - List all accessible tables
router.get('/tables', listTables);

// GET /api/admin/tables/:table - Get table data with pagination
router.get('/tables/:table', getTableData);

// POST /api/admin/tables/:table - Insert new row
router.post('/tables/:table', insertRow);

// PUT /api/admin/tables/:table/:id - Update a row
router.put('/tables/:table/:id', updateRow);

// DELETE /api/admin/tables/:table/:id - Delete a row
router.delete('/tables/:table/:id', deleteRow);

// POST /api/admin/query - Execute custom SQL
router.post('/query', executeQuery);

module.exports = router;
