// almahriah_backend/controllers/chatController.js - النسخة المصححة والكاملة

const db = require('../services/db');
const activeUsers = require('../utils/activeUsers'); 

const registerChatEvents = (socket) => {
    const userId = socket.handshake.query.userId;
    console.log(`User connected: ${socket.id} (User ID: ${userId})`);

    if (userId) {
        activeUsers.set(userId, socket.id);
        console.log(`User ${userId} is now active. Total active users: ${activeUsers.size}`);

        socket.broadcast.emit('user-status-changed', {
            userId: userId,
            status: true
        });
    }

    // ✅ تحديث معالج إرسال الرسائل لدعم الرد مع المحتوى والوقت
    socket.on('sendMessage', (data) => {
        const { senderId, receiverId, content, tempId, replyToMessageId, replyToMessageContent, createdAt } = data;
        const deliveredStatus = activeUsers.has(receiverId.toString()) ? 1 : 0;
        const readStatus = 0;
        const messageTimestamp = createdAt ? new Date(createdAt) : new Date();

        console.log('Sending message with reply:', {
            senderId,
            receiverId,
            content,
            replyToMessageId,
            replyToMessageContent
        });

        // ✅ إضافة replyToMessageContent في قاعدة البيانات
        const sql = 'INSERT INTO messages (senderId, receiverId, content, deliveredStatus, readStatus, replyToMessageId, replyToMessageContent, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?)';
        db.query(sql, [senderId, receiverId, content, deliveredStatus, readStatus, replyToMessageId, replyToMessageContent, messageTimestamp], (error, result) => {
            if (error) {
                console.error('Error sending message:', error);
                socket.emit('messageError', { error: 'Failed to send message' });
                return;
            }

            const messageId = result.insertId;
            const messageData = {
                id: messageId.toString(),
                senderId: senderId.toString(),
                receiverId: receiverId.toString(),
                content: content,
                readStatus: readStatus === 1,
                deliveredStatus: deliveredStatus === 1,
                replyToMessageId: replyToMessageId,
                replyToMessageContent: replyToMessageContent, // ✅ إضافة المحتوى
                createdAt: messageTimestamp.toISOString()
            };

            const receiverSocketId = activeUsers.get(receiverId.toString());
            if (receiverSocketId) {
                // إرسال الرسالة للمستلم مع بيانات الرد الكاملة
                socket.to(receiverSocketId).emit('receiveMessage', messageData);
                // إرسال إشعار "تم التسليم" للمرسل
                socket.emit('messageStatusUpdate', { 
                    messageId: messageId.toString(), 
                    tempId: tempId, 
                    status: 'delivered' 
                });
                console.log(`Message ${messageId} delivered to user ${receiverId} with reply data.`);
            } else {
                // إرسال إشعار "تم الإرسال" للمرسل (المستلم غير متصل)
                socket.emit('messageStatusUpdate', { 
                    messageId: messageId.toString(), 
                    tempId: tempId, 
                    status: 'sent' 
                });
                console.log(`Message ${messageId} sent to offline user ${receiverId}.`);
            }
        });
    });

    // معالج حذف الرسائل
    socket.on('deleteMessage', (data) => {
        const { messageId, senderId, receiverId } = data;
        
        if (socket.handshake.query.userId.toString() !== senderId.toString()) {
            console.log(`Unauthorized delete attempt by user ${socket.handshake.query.userId} for message ${messageId}.`);
            return;
        }

        const sql = 'DELETE FROM messages WHERE id = ? AND senderId = ?';
        db.query(sql, [messageId, senderId], (error, result) => {
            if (error) {
                console.error('Error deleting message:', error);
                return;
            }

            if (result.affectedRows > 0) {
                const receiverSocketId = activeUsers.get(receiverId.toString());
                if (receiverSocketId) {
                    socket.to(receiverSocketId).emit('messageDeleted', { messageId });
                }
                socket.emit('messageDeleted', { messageId });
                console.log(`Message ${messageId} deleted by user ${senderId}.`);
            } else {
                console.log(`No rows affected. Message ${messageId} not found or not owned by sender ${senderId}.`);
            }
        });
    });

    // ✅ تحديث معالج تعديل الرسائل
    socket.on('editMessage', (data) => {
        const { messageId, senderId, newContent, receiverId } = data;
        
        if (socket.handshake.query.userId.toString() !== senderId.toString()) {
            console.log(`Unauthorized edit attempt by user ${socket.handshake.query.userId} for message ${messageId}.`);
            return;
        }

        // ✅ تحديث العمودين: content و updatedAt
        const sql = 'UPDATE messages SET content = ?, updatedAt = ? WHERE id = ? AND senderId = ?';
        const editedAt = new Date();
        db.query(sql, [newContent, editedAt, messageId, senderId], (error, result) => {
            if (error) {
                console.error('Error editing message:', error);
                return;
            }

            if (result.affectedRows > 0) {
                const editedMessageData = {
                    id: messageId.toString(),
                    senderId: senderId.toString(),
                    newContent: newContent,
                    // ✅ إرسال وقت التعديل
                    updatedAt: editedAt.toISOString() 
                };
                
                const receiverSocketId = activeUsers.get(receiverId.toString());
                if (receiverSocketId) {
                    socket.to(receiverSocketId).emit('messageEdited', editedMessageData);
                }
                socket.emit('messageEdited', editedMessageData);
                console.log(`Message ${messageId} edited by user ${senderId}.`);
            } else {
                console.log(`No rows affected. Message ${messageId} not found or not owned by sender ${senderId}.`);
            }
        });
    });

    // معالج قراءة الرسائل
    socket.on('readMessage', (data) => {
        const { messageId, senderId, receiverId } = data;
        console.log(`Processing readMessage: MessageID=${messageId}, SenderID=${senderId}, ReceiverID=${receiverId}`);
        
        const checkSql = 'SELECT id, senderId, receiverId, readStatus FROM messages WHERE id = ?';
        db.query(checkSql, [messageId], (checkError, checkResult) => {
            if (checkError) {
                console.error('Error checking message:', checkError);
                return;
            }

            if (checkResult.length === 0) {
                console.log(`Message ${messageId} not found in database.`);
                return;
            }

            const messageData = checkResult[0];
            console.log(`Message data: SenderId=${messageData.senderId}, ReceiverId=${messageData.receiverId}, ReadStatus=${messageData.readStatus}`);

            if (messageData.receiverId.toString() !== receiverId.toString()) {
                console.log(`User ${receiverId} is not the receiver of message ${messageId}. Actual receiver: ${messageData.receiverId}`);
                return;
            }

            if (messageData.readStatus === 1) {
                console.log(`Message ${messageId} is already read, sending read status to sender ${messageData.senderId}`);
                const senderSocketId = activeUsers.get(messageData.senderId.toString());
                if (senderSocketId) {
                    socket.to(senderSocketId).emit('messageStatusUpdate', { 
                        messageId: messageId.toString(), 
                        status: 'read' 
                    });
                    console.log(`Read status sent to sender ${messageData.senderId} for already read message ${messageId}.`);
                }
                return;
            }

            const updateSql = 'UPDATE messages SET readStatus = 1, deliveredStatus = 1 WHERE id = ? AND receiverId = ? AND readStatus = 0';
            db.query(updateSql, [messageId, receiverId], (error, result) => {
                if (error) {
                    console.error('Error marking message as read:', error);
                    return;
                }

                console.log(`Database update result: affectedRows=${result.affectedRows} for messageId=${messageId}`);

                if (result.affectedRows > 0) {
                    const senderSocketId = activeUsers.get(messageData.senderId.toString());
                    console.log(`Looking for sender ${messageData.senderId}: socketId=${senderSocketId}`);
                    
                    if (senderSocketId) {
                        socket.to(senderSocketId).emit('messageStatusUpdate', { 
                            messageId: messageId.toString(), 
                            status: 'read' 
                        });
                        console.log(`Message ${messageId} read status sent to sender ${messageData.senderId}.`);
                    } else {
                        console.log(`Sender ${messageData.senderId} is not online to receive read notification.`);
                    }
                } else {
                    console.log(`No rows affected when marking message ${messageId} as read.`);
                }
            });
        });
    });

    // معالج الكتابة
    socket.on('typing', (data) => {
        const receiverSocketId = activeUsers.get(data.receiverId.toString());
        if (receiverSocketId) {
            socket.to(receiverSocketId).emit('typing', {
                senderId: data.senderId,
                isTyping: data.isTyping
            });
        }
    });

    // معالج قطع الاتصال
    socket.on('disconnect', () => {
        const userId = [...activeUsers.entries()].find(([key, val]) => val === socket.id)?.[0];
        if (userId) {
            activeUsers.delete(userId);
            console.log(`User ${userId} disconnected. Total active users: ${activeUsers.size}`);

            socket.broadcast.emit('user-status-changed', {
                userId: userId,
                status: false
            });
        }
    });
};

// ✅ تحديث API لجلب تاريخ المحادثة مع دعم replyToMessageContent و updatedAt
const getChatHistory = (req, res) => {
    const { receiverId } = req.params;
    const senderId = req.user.id;

    const sql = `
        SELECT id, senderId, receiverId, content, deliveredStatus, readStatus, createdAt, replyToMessageId, replyToMessageContent, updatedAt
        FROM messages
        WHERE (senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?)
        ORDER BY createdAt ASC;
    `;
    
    db.query(sql, [senderId, receiverId, receiverId, senderId], (error, rows) => {
        if (error) {
            console.error('Error getting chat history:', error);
            return res.status(500).json({ message: 'Failed to retrieve chat history.' });
        }
        
        // تحويل البيانات للتأكد من التنسيق الصحيح
        const formattedMessages = rows.map(row => ({
            id: row.id.toString(),
            senderId: row.senderId.toString(),
            receiverId: row.receiverId.toString(),
            content: row.content,
            deliveredStatus: row.deliveredStatus === 1,
            readStatus: row.readStatus === 1,
            replyToMessageId: row.replyToMessageId,
            replyToMessageContent: row.replyToMessageContent, 
            createdAt: row.createdAt,
            updatedAt: row.updatedAt 
        }));
        
        console.log(`Retrieved ${formattedMessages.length} messages for chat between ${senderId} and ${receiverId}`);
        res.status(200).json(formattedMessages);
    });
};

const deleteAllChats = (req, res) => {
    const sql = 'DELETE FROM messages';

    db.query(sql, (error, result) => {
        if (error) {
            console.error('Error deleting all chats:', error);
            return res.status(500).json({ message: 'Failed to delete all chat history.' });
        }
        res.status(200).json({ message: 'All chat history has been deleted successfully.' });
    });
};

const getChatUsers = (req, res) => {
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

module.exports = {
    registerChatEvents,
    getChatHistory,
    deleteAllChats,
    getChatUsers
};