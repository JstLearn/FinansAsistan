// back/routes/giderRoutes.js
const express = require("express");
const router = express.Router();
const { addGider, getAllGider } = require("../controllers/giderController");
const authMiddleware = require("../middleware/authMiddleware");
const yetkiCheck = require("../middleware/yetkiCheckMiddleware");

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// GET /api/gider
router.get("/", getAllGider);

// POST /api/gider
router.post("/", yetkiCheck('harcama_borc_ekleme'), addGider);

module.exports = router;
