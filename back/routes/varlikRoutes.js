// back/routes/varlikRoutes.js
const express = require("express");
const router = express.Router();
const { addVarlik, getAllVarlik, updateVarlik, deleteVarlik } = require("../controllers/varlikController");
const authMiddleware = require("../middleware/authMiddleware");
const yetkiCheck = require("../middleware/yetkiCheckMiddleware");

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// GET /api/varlik
router.get("/", getAllVarlik);

// POST /api/varlik
router.post("/", yetkiCheck('varlik_ekleme'), addVarlik);

// PUT /api/varlik/:id
router.put("/:id", yetkiCheck('varlik_duzenleme'), updateVarlik);

// DELETE /api/varlik/:id
router.delete("/:id", yetkiCheck('varlik_silme'), deleteVarlik);

module.exports = router;
