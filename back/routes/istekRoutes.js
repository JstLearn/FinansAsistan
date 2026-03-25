const express = require('express');
const router = express.Router();
const { addIstek, getAllIstek, updateIstek, deleteIstek } = require('../controllers/istekController');
const authMiddleware = require('../middleware/authMiddleware');

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// İstek ekleme
router.post('/', addIstek);

// Tüm istekleri getirme
router.get('/', getAllIstek);

// İstek güncelleme
router.put('/:id', updateIstek);

// İstek silme
router.delete('/:id', deleteIstek);

module.exports = router;

