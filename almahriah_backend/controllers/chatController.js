// Belqees_backend/controllers/chatController.js - النسخة المُحسنة والمُصححة

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

    // إرسال الرسائل
    socket.on('sendMessage', (data) => {
    const { senderId, receiverId, content, tempId, replyToMessageId, replyToMessageContent, createdAt } = data;
    const deliveredStatus = activeUsers.has(receiverId.toString()) ? 1 : 0;
    const readStatus = 0;
    const messageTimestamp = createdAt ? new Date(createdAt) : new Date();

    console.log('📤 Sending message with reply data:', {
        senderId,
        receiverId,
        content,
        replyToMessageId: replyToMessageId || 'none',
        replyToMessageContent: replyToMessageContent || 'none'
    });

    const sql = 'INSERT INTO messages (senderId, receiverId, content, deliveredStatus, readStatus, replyToMessageId, replyToMessageContent, createdAt) VALUES (?, ?, ?, ?, ?, ?, ?, ?)';
    db.query(sql, [senderId, receiverId, content, deliveredStatus, readStatus, replyToMessageId, replyToMessageContent, messageTimestamp], (error, result) => {
        if (error) {
            console.error('❌ Error sending message:', error);
            socket.emit('messageError', { error: 'Failed to send message', tempId });
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
            replyToMessageId: replyToMessageId ? replyToMessageId.toString() : null,
            replyToMessageContent: replyToMessageContent || null,
            createdAt: messageTimestamp.toISOString(),
            tempId: tempId
        };
        
        console.log(' Message created with reply data:', {
            messageId: messageId,
            hasReply: !!replyToMessageContent,
            replyContent: replyToMessageContent ? replyToMessageContent.substring(0, 20) + '...' : 'none'
        });
        
        // إرسال الرسالة للمرسل مع tempId للتحديث
        socket.emit('receiveMessage', {
            ...messageData,
            status: 'sent'
        });

        // إرسال الرسالة للمستقبل
        const receiverSocketId = activeUsers.get(receiverId.toString());
        if (receiverSocketId) {
            socket.to(receiverSocketId).emit('receiveMessage', messageData);
            console.log(` Message ${messageId} delivered to user ${receiverId} with reply data`);
        } else {
            console.log(`📴 User ${receiverId} is offline. Message stored with reply data.`);
        }
    });
});

    // حذف الرسائل
    socket.on('deleteMessage', (data) => {
        const { messageId, senderId, receiverId, deleteType } = data;
        
        console.log('🗑️ Delete message request:', { messageId, senderId, receiverId, deleteType });

        if (socket.handshake.query.userId.toString() !== senderId.toString()) {
            console.log('❌ Unauthorized delete attempt');
            return;
        }

        if (deleteType === 'forEveryone') {
            // حذف نهائي من قاعدة البيانات
            const sql = 'DELETE FROM messages WHERE id = ? AND senderId = ?';
            db.query(sql, [messageId, senderId], (error, result) => {
                if (error) {
                    console.error('❌ Error deleting message for everyone:', error);
                    return;
                }

                if (result.affectedRows > 0) {
                    // إشعار المستقبل بالحذف
                    const receiverSocketId = activeUsers.get(receiverId.toString());
                    if (receiverSocketId) {
                        socket.to(receiverSocketId).emit('messageDeleted', { 
                            messageId: messageId.toString(), 
                            deleteType: 'forEveryone' 
                        });
                    }
                    
                    // إشعار المرسل بنجاح الحذف
                    socket.emit('messageDeleted', { 
                        messageId: messageId.toString(), 
                        deleteType: 'forEveryone' 
                    });
                    
                    console.log(` Message ${messageId} deleted for everyone`);
                } else {
                    console.log('❌ Message not found or already deleted');
                }
            });

        } else if (deleteType === 'forMe') {
            const currentUserId = socket.handshake.query.userId;
            const sql = 'UPDATE messages SET deletedForId = ? WHERE id = ?';
            db.query(sql, [currentUserId, messageId], (error, result) => {
                if (error) {
                    console.error('❌ Error deleting message for user:', error);
                    return;
                }

                if (result.affectedRows > 0) {
                    socket.emit('messageDeleted', { 
                        messageId: messageId.toString(), 
                        deleteType: 'forMe' 
                    });
                    console.log(` Message ${messageId} deleted for user ${currentUserId} only`);
                }
            });
        }
    });

    // تعديل الرسائل
    socket.on('editMessage', (data) => {
        const { messageId, senderId, newContent, receiverId } = data;
        
        if (socket.handshake.query.userId.toString() !== senderId.toString()) {
            console.log(`❌ Unauthorized edit attempt`);
            return;
        }

        const sql = 'UPDATE messages SET content = ?, updatedAt = ? WHERE id = ? AND senderId = ?';
        const editedAt = new Date();
        
        db.query(sql, [newContent, editedAt, messageId, senderId], (error, result) => {
            if (error) {
                console.error('❌ Error editing message:', error);
                return;
            }

            if (result.affectedRows > 0) {
                const editedMessageData = {
                    messageId: messageId.toString(),
                    newContent: newContent,
                    updatedAt: editedAt.toISOString(),
                    action: 'edited'
                };
                
                // إرسال التحديث للمستقبل
                const receiverSocketId = activeUsers.get(receiverId.toString());
                if (receiverSocketId) {
                    socket.to(receiverSocketId).emit('messageEdited', editedMessageData);
                }
                
                // إرسال التحديث للمرسل
                socket.emit('messageEdited', editedMessageData);
                console.log(` Message ${messageId} edited successfully`);
            }
        });
    });

    // قراءة الرسائل
    socket.on('readMessage', (data) => {
        const { messageId, senderId, receiverId } = data;
        console.log('📖 Read message request:', { messageId, senderId, receiverId });
        
        const sql = 'UPDATE messages SET readStatus = 1, deliveredStatus = 1 WHERE id = ? AND receiverId = ? AND readStatus = 0';
        db.query(sql, [messageId, receiverId], (error, result) => {
            if (error) {
                console.error('❌ Error marking message as read:', error);
                return;
            }

            if (result.affectedRows > 0) {
                // إشعار المرسل بالقراءة
                const senderSocketId = activeUsers.get(senderId.toString());
                if (senderSocketId) {
                    socket.to(senderSocketId).emit('messageStatusUpdate', { 
                        messageId: messageId.toString(), 
                        status: 'read' 
                    });
                }
                console.log(` Message ${messageId} marked as read`);
            }
        });
    });

    // تصفير عداد الرسائل غير المقروءة
    socket.on('clearUnreadCount', (data) => {
        const { senderId, receiverId } = data;
        console.log('🧹 Clearing unread count:', { senderId, receiverId });

        const sql = 'UPDATE messages SET readStatus = 1 WHERE senderId = ? AND receiverId = ? AND readStatus = 0';
        db.query(sql, [senderId, receiverId], (error, result) => {
            if (error) {
                console.error('❌ Error clearing unread count:', error);
                return;
            }

            if (result.affectedRows > 0) {
                console.log(` Cleared ${result.affectedRows} unread messages`);
                
                // إشعار المرسل بأن رسائله تم قراءتها
                const senderSocketId = activeUsers.get(senderId.toString());
                if (senderSocketId) {
                    socket.to(senderSocketId).emit('messagesMarkedAsRead', { 
                        senderId: receiverId,
                        readCount: result.affectedRows 
                    });
                }

                // إشعار المستقبل بتصفير العداد
                socket.emit('unreadCountCleared', { 
                    senderId: senderId,
                    clearedCount: result.affectedRows 
                });
            }
        });
    });

    // الكتابة
    socket.on('typing', (data) => {
        const receiverSocketId = activeUsers.get(data.receiverId.toString());
        if (receiverSocketId) {
            socket.to(receiverSocketId).emit('typing', {
                senderId: data.senderId,
                isTyping: data.isTyping
            });
        }
    });

    // قطع الاتصال
    socket.on('disconnect', () => {
        const userId = [...activeUsers.entries()].find(([key, val]) => val === socket.id)?.[0];
        if (userId) {
            activeUsers.delete(userId);
            console.log(`👋 User ${userId} disconnected. Total active users: ${activeUsers.size}`);

            socket.broadcast.emit('user-status-changed', {
                userId: userId,
                status: false
            });
        }
    });
};

// جلب تاريخ المحادثة
const getChatHistory = (req, res) => {
    const { receiverId } = req.params;
    const senderId = req.user.id;
    const userId = req.user.id;

    const sql = `
        SELECT id, senderId, receiverId, content, deliveredStatus, readStatus, createdAt, 
               replyToMessageId, replyToMessageContent, updatedAt
        FROM messages
        WHERE ((senderId = ? AND receiverId = ?) OR (senderId = ? AND receiverId = ?))
        AND (deletedForId IS NULL OR deletedForId != ?)
        ORDER BY createdAt ASC
    `;
    
    db.query(sql, [senderId, receiverId, receiverId, senderId, userId], (error, rows) => {
        if (error) {
            console.error('❌ Error getting chat history:', error);
            return res.status(500).json({ message: 'Failed to retrieve chat history.' });
        }
        
        const formattedMessages = rows.map(row => ({
            id: row.id.toString(),
            senderId: row.senderId.toString(),
            receiverId: row.receiverId.toString(),
            content: row.content,
            deliveredStatus: row.deliveredStatus === 1,
            readStatus: row.readStatus === 1,
            replyToMessageId: row.replyToMessageId ? row.replyToMessageId.toString() : null,
            replyToMessageContent: row.replyToMessageContent || null,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt 
        }));
        
        console.log(` Retrieved ${formattedMessages.length} messages for chat between ${senderId} and ${receiverId}`);
        
        const messagesWithReplies = formattedMessages.filter(msg => msg.replyToMessageContent);
        console.log(`📊 Messages with replies: ${messagesWithReplies.length}`);
        
        res.status(200).json(formattedMessages);
    });
};

// حذف جميع المحادثات
const deleteAllChats = (req, res) => {
    const sql = 'DELETE FROM messages';

    db.query(sql, (error, result) => {
        if (error) {
            console.error('❌ Error deleting all chats:', error);
            return res.status(500).json({ message: 'Failed to delete all chat history.' });
        }
        res.status(200).json({ message: 'All chat history has been deleted successfully.' });
    });
};

// ✅  جلب قائمة المستخدمين مع عداد الرسائل غير المقروءة - النسخة المُحسنة
const getChatUsers = (req, res) => {
    const userId = req.user.id;
    
    const sql = `
        SELECT 
            id, 
            fullName, 
            role, 
            department, 
            profilePictureUrl,  
            isLoggedIn 
        FROM users 
        WHERE id != ? AND isActive = 1
        ORDER BY fullName
    `;

    db.query(sql, [userId], (error, users) => {
        if (error) {
            console.error('❌ Error getting chat users:', error);
            return res.status(500).json({ message: 'Failed to retrieve users.' });
        }
        
        // تحويل البيانات إلى تنسيق مناسب
        const formattedUsers = users.map(user => {
            const isOnline = activeUsers.has(user.id.toString());
            return {
                id: user.id.toString(),
                fullName: user.fullName,
                role: user.role,
                department: user.department,
                profilePictureUrl: user.profilePictureUrl, // ✅ إضافة رابط الصورة
                isLoggedIn: isOnline ? 1 : 0,
                unreadCount: 0 // تم حذف العداد من هنا وسيتم جلبه بنقطة نهاية منفصلة
            };
        });

        res.status(200).json(formattedUsers);
    });
};

// جلب عداد الرسائل غير المقروءة
const getUnreadCounts = (req, res) => {
    const userId = req.user.id;
    
    const sql = `
        SELECT senderId, COUNT(*) as count
        FROM messages 
        WHERE receiverId = ? AND readStatus = 0
        GROUP BY senderId
    `;
    
    db.query(sql, [userId], (error, rows) => {
        if (error) {
            console.error('❌ Error getting unread counts:', error);
            return res.status(500).json({ message: 'Failed to get unread counts.' });
        }
        
        const unreadCounts = {};
        rows.forEach(row => {
            unreadCounts[row.senderId.toString()] = parseInt(row.count);
        });
        
        res.status(200).json(unreadCounts);
    });
};

// حذف رسائل متعددة
const deleteMessage = async (req, res) => {
    const { messageIds, deleteType } = req.body;
    const userId = req.user.id;

    if (!messageIds || !Array.isArray(messageIds) || messageIds.length === 0 || !deleteType) {
        return res.status(400).json({ message: 'Message IDs and deleteType are required.' });
    }

    try {
        if (deleteType === 'forMe') {
            const placeholders = messageIds.map(() => '?').join(',');
            const sql = `UPDATE messages SET deletedForId = ? WHERE id IN (${placeholders})`;
            const queryParams = [userId, ...messageIds];

            db.query(sql, queryParams, (error, result) => {
                if (error) {
                    console.error('❌ Error deleting messages for user:', error);
                    return res.status(500).json({ message: 'Server error.' });
                }
                res.status(200).json({ message: `${result.affectedRows} messages hidden for user.` });
            });
        
        } else if (deleteType === 'forEveryone') {
            const placeholders = messageIds.map(() => '?').join(',');
            const sqlCheck = `SELECT COUNT(id) AS count FROM messages WHERE id IN (${placeholders}) AND senderId != ?`;
            
            db.query(sqlCheck, [...messageIds, userId], (checkError, checkResult) => {
                if (checkError) {
                    return res.status(500).json({ message: 'Server error.' });
                }
                if (checkResult[0].count > 0) {
                    return res.status(403).json({ message: 'Unauthorized to delete some messages for everyone.' });
                }
                
                const sqlDelete = `DELETE FROM messages WHERE id IN (${placeholders})`;
                db.query(sqlDelete, [...messageIds], (deleteError, deleteResult) => {
                    if (deleteError) {
                        console.error('❌ Error deleting messages for everyone:', deleteError);
                        return res.status(500).json({ message: 'Server error.' });
                    }
                    res.status(200).json({ message: `${deleteResult.affectedRows} messages deleted successfully for everyone.` });
                });
            });
        
        } else {
            return res.status(400).json({ message: 'Invalid delete type provided.' });
        }

    } catch (error) {
        console.error('❌ Error deleting messages:', error);
        res.status(500).json({ message: 'Server error.', error: error.message });
    }
};

module.exports = {
    registerChatEvents,
    getChatHistory,
    deleteAllChats,
    getChatUsers,
    getUnreadCounts,
    deleteMessage,
    deleteBulkMessages: deleteMessage // استخدام نفس دالة deleteMessage للحذف المتعدد
};