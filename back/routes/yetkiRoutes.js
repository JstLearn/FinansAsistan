const express = require('express');
const router = express.Router();
const { 
    addYetki, 
    getMyAuthorizations,
    getGrantedToMeAuthorizations,
    checkAuthorization,
    updateYetki,
    deleteYetki 
} = require('../controllers/yetkiController');
const authMiddleware = require('../middleware/authMiddleware');

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// Yetki ekleme/güncelleme
router.post('/', addYetki);

// Verdiğim yetkileri listele
router.get('/', getMyAuthorizations);

// Bana verilen yetkileri listele
router.get('/granted-to-me', getGrantedToMeAuthorizations);

// Yetki kontrolü
router.get('/check', checkAuthorization);

// Yetki güncelleme
router.put('/:id', updateYetki);

// Yetki silme
router.delete('/:id', deleteYetki);

module.exports = router;

