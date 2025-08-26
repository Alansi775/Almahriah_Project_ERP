// routes/aiRoutes.js
const express = require('express');
const router = express.Router();
const aiController = require('../controllers/aiController');
const { verifyToken } = require('../middleware/authMiddleware'); // ✅ Import verifyToken

// Define the AI chat route
router.post('/chat', verifyToken, aiController.handleChat); // ✅ Use verifyToken here

module.exports = router;