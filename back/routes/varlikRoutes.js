// back/routes/varlikRoutes.js
const express = require("express");
const router = express.Router();
const { addVarlik, getAllVarlik, updateVarlik, deleteVarlik } = require("../controllers/varlikController");
const authMiddleware = require("../middleware/authMiddleware");

// Tüm route'lar için auth middleware'ini kullan
router.use(authMiddleware);

// GET /api/varlik
router.get("/", getAllVarlik);

// POST /api/varlik
router.post("/", addVarlik);

// PUT /api/varlik/:id
router.put("/:id", updateVarlik);

// DELETE /api/varlik/:id
router.delete("/:id", deleteVarlik);

module.exports = router;
