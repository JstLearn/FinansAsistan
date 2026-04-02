const express = require('express');
const router = express.Router();
const { addIstek, getAllIstek, updateIstek, deleteIstek } = require('../controllers/istekController');
const authMiddleware = require('../middleware/authMiddleware');
const yetkiCheck = require('../middleware/yetkiCheckMiddleware');

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// İstek ekleme
router.post('/', yetkiCheck('istek_ekleme'), addIstek);

// Tüm istekleri getirme
router.get('/', getAllIstek);

// İstek güncelleme
router.put('/:id', yetkiCheck('istek_duzenleme'), updateIstek);

// İstek silme
router.delete('/:id', yetkiCheck('istek_silme'), deleteIstek);

module.exports = router;

