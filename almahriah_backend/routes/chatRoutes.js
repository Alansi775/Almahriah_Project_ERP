// almahriah_backend/routes/chatRoutes.js
const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const { verifyToken, verifyRole } = require('../middleware/authMiddleware');

router.get('/history/:receiverId', verifyToken, chatController.getChatHistory);
router.get('/users', verifyToken, chatController.getChatUsers);
router.get('/unread-counts', verifyToken, chatController.getUnreadCounts);
router.delete('/delete-all', verifyToken, verifyRole(['Admin']), chatController.deleteAllChats);
router.post('/delete-message', verifyToken, chatController.deleteMessage);
router.post('/delete-bulk-messages', verifyToken, chatController.deleteMessage); // استخدام نفس دالة deleteMessage

module.exports = router;