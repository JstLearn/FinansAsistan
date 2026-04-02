const express = require('express');
const router = express.Router();
const { addHatirlatma, getAllHatirlatma, updateHatirlatma, deleteHatirlatma } = require('../controllers/hatirlatmaController');
const authMiddleware = require('../middleware/authMiddleware');
const yetkiCheck = require('../middleware/yetkiCheckMiddleware');

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// Hatırlatma ekleme
router.post('/', yetkiCheck('hatirlatma_ekleme'), addHatirlatma);

// Tüm hatırlatmaları getirme
router.get('/', getAllHatirlatma);

// Hatırlatma güncelleme
router.put('/:id', yetkiCheck('hatirlatma_duzenleme'), updateHatirlatma);

// Hatırlatma silme
router.delete('/:id', yetkiCheck('hatirlatma_silme'), deleteHatirlatma);

module.exports = router;

