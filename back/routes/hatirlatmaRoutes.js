const express = require('express');
const router = express.Router();
const { addHatirlatma, getAllHatirlatma, updateHatirlatma, deleteHatirlatma } = require('../controllers/hatirlatmaController');
const authMiddleware = require('../middleware/authMiddleware');

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// Hatırlatma ekleme
router.post('/', addHatirlatma);

// Tüm hatırlatmaları getirme
router.get('/', getAllHatirlatma);

// Hatırlatma güncelleme
router.put('/:id', updateHatirlatma);

// Hatırlatma silme
router.delete('/:id', deleteHatirlatma);

module.exports = router;

