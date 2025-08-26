// almahriah_backend/controllers/chatController.js

const db = require('../config/db');
const activeUsers = new Map(); // Map to store active users: userId -> socketId

// Main Socket.IO connection handler (only for socket events)
exports.handleSocketConnection = (socket) => {
    const userId = socket.handshake.query.userId;
    console.log(`User connected: ${socket.id} (User ID: ${userId})`);

    if (userId) {
        activeUsers.set(userId, socket.id);
        console.log(`User ${userId} is now active.`);

        // ✨ الإضافة رقم 1: إرسال إشعار للمستخدمين الآخرين بأن هذا المستخدم أصبح متصلًا
        socket.broadcast.emit('user-status-changed', {
            userId: userId,
            status: true // true تعني متصل
        });
    }

    // Handle new message event
    socket.on('sendMessage', (data) => {
        const { senderId, receiverId, content } = data;
        const sql = 'INSERT INTO messages (senderId, receiverId, content, deliveredStatus) VALUES (?, ?, ?, ?)';
        
        const isReceiverOnline = activeUsers.has(receiverId.toString());

        db.query(sql, [senderId, receiverId, content, isReceiverOnline], (error, result) => {
            if (error) {
                console.error('Error sending message:', error);
                return;
            }
            const messageId = result.insertId;
            const messageData = {
                id: messageId,
                senderId: senderId.toString(),
                receiverId: receiverId.toString(),
                content: content,
                readStatus: false,
                deliveredStatus: isReceiverOnline,
                createdAt: new Date()
            };

            const receiverSocketId = activeUsers.get(receiverId.toString());
            if (receiverSocketId) {
                socket.to(receiverSocketId).emit('receiveMessage', messageData);
            }
            
            socket.emit('messageSent', messageData);
        });
    });

    // Handle message read event
    socket.on('readMessage', (data) => {
        const { senderId, messageId } = data;
        const sql = 'UPDATE messages SET readStatus = TRUE WHERE id = ?';
        
        db.query(sql, [messageId], (error, result) => {
            if (error) {
                console.error('Error updating read status:', error);
            }
            const senderSocketId = activeUsers.get(senderId.toString());
            if (senderSocketId) {
                socket.to(senderSocketId).emit('messageRead', { messageId });
            }
        });
    });

    // Handle typing event
    socket.on('typing', (data) => {
        const receiverSocketId = activeUsers.get(data.receiverId.toString());
        if (receiverSocketId) {
            socket.to(receiverSocketId).emit('typing', {
                senderId: data.senderId,
                isTyping: data.isTyping
            });
        }
    });

    // Handle user disconnections
    socket.on('disconnect', () => {
        const userId = [...activeUsers.entries()].find(([key, val]) => val === socket.id)?.[0];
        if (userId) {
            activeUsers.delete(userId);
            console.log(`User ${userId} disconnected.`);

            // ✨ الإضافة رقم 2: إرسال إشعار للمستخدمين الآخرين بأن هذا المستخدم أصبح غير متصل
            socket.broadcast.emit('user-status-changed', {
                userId: userId,
                status: false // false تعني غير متصل
            });
        }
    });
};

// ✅ REST API endpoints (must be outside the handleSocketConnection function)

exports.getChatHistory = (req, res) => {
    const { receiverId } = req.params;
    const senderId = req.user.id;

    const sql = `
        SELECT *
        FROM messages
        WHERE (senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)
        ORDER BY createdAt ASC;
    `;
    
    db.query(sql, [senderId, receiverId, receiverId, senderId], (error, rows) => {
        if (error) {
            console.error('Error getting chat history:', error);
            return res.status(500).json({ message: 'Failed to retrieve chat history.' });
        }
        res.status(200).json(rows);
    });
};

exports.deleteAllChats = (req, res) => {
    const sql = 'DELETE FROM messages';

    db.query(sql, (error, result) => {
        if (error) {
            console.error('Error deleting all chats:', error);
            return res.status(500).json({ message: 'Failed to delete all chat history.' });
        }
        res.status(200).json({ message: 'All chat history has been deleted successfully.' });
    });
};

exports.getChatUsers = (req, res) => {
    const userId = req.user.id;
    const sql = 'SELECT id, fullName, role, department, isLoggedIn FROM users WHERE id != ?';

    db.query(sql, [userId], (error, rows) => {
        if (error) {
            console.error('Error getting chat users:', error);
            return res.status(500).json({ message: 'Failed to retrieve users.' });
        }
        res.status(200).json(rows);
    });
};