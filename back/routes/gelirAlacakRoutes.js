// back/routes/gelirAlacakRoutes.js
const express = require("express");
const router = express.Router();
const { addGelirAlacak, getAllGelirAlacak, updateGelirAlacak, deleteGelirAlacak } = require("../controllers/gelirAlacakController");
const authMiddleware = require("../middleware/authMiddleware");

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// GET /api/gelir-alacak
router.get("/", getAllGelirAlacak);

// POST /api/gelir-alacak
router.post("/", addGelirAlacak);

// PUT /api/gelir-alacak/:id
router.put("/:id", updateGelirAlacak);

// DELETE /api/gelir-alacak/:id
router.delete("/:id", deleteGelirAlacak);

module.exports = router;

