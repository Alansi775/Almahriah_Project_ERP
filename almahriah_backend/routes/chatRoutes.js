const express = require('express');
const router = express.Router();
const chatController = require('../controllers/chatController');
const { verifyToken, verifyRole } = require('../middleware/authMiddleware');

// Route to get chat history with a specific user
router.get('/history/:receiverId', verifyToken, chatController.getChatHistory);

// Route to get a list of all users to chat with
router.get('/users', verifyToken, chatController.getChatUsers);

// Route for Admin to delete all chats
router.delete('/delete-all', verifyToken, verifyRole(['Admin']), chatController.deleteAllChats);

module.exports = router;