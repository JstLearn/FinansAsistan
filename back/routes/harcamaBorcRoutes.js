// back/routes/harcamaBorcRoutes.js
const express = require("express");
const router = express.Router();
const { addHarcamaBorc, getAllHarcamaBorc, updateHarcamaBorc, deleteHarcamaBorc } = require("../controllers/harcamaBorcController");
const authMiddleware = require("../middleware/authMiddleware");
const yetkiCheck = require("../middleware/yetkiCheckMiddleware");

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// GET /api/harcama-borc
router.get("/", getAllHarcamaBorc);

// POST /api/harcama-borc
router.post("/", yetkiCheck('harcama_borc_ekleme'), addHarcamaBorc);

// PUT /api/harcama-borc/:id
router.put("/:id", yetkiCheck('harcama_borc_duzenleme'), updateHarcamaBorc);

// DELETE /api/harcama-borc/:id
router.delete("/:id", yetkiCheck('harcama_borc_silme'), deleteHarcamaBorc);

module.exports = router;

