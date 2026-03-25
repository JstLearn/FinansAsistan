// back/routes/harcamaBorcRoutes.js
const express = require("express");
const router = express.Router();
const { addHarcamaBorc, getAllHarcamaBorc, updateHarcamaBorc, deleteHarcamaBorc } = require("../controllers/harcamaBorcController");
const authMiddleware = require("../middleware/authMiddleware");

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// GET /api/harcama-borc
router.get("/", getAllHarcamaBorc);

// POST /api/harcama-borc
router.post("/", addHarcamaBorc);

// PUT /api/harcama-borc/:id
router.put("/:id", updateHarcamaBorc);

// DELETE /api/harcama-borc/:id
router.delete("/:id", deleteHarcamaBorc);

module.exports = router;

