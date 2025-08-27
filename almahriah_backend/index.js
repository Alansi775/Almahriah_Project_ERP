// almahriah_backend/index.js

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const http = require('http');
const socketIo = require('socket.io');
const path = require('path');
const db = require('./services/db');

// استيراد المسارات
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const adminRoutes = require('./routes/adminRoutes');
const taskRoutes = require('./routes/taskRoutes');
const dashboardRoutes = require('./routes/dashboardRoutes');
const employeeRoutes = require('./routes/employeeRoutes');
const aiRoutes = require('./routes/aiRoutes');
const chatRoutes = require('./routes/chatRoutes');

// استيراد متحكم المحادثة والتحقق
const chatController = require('./controllers/chatController');
const authController = require('./controllers/authController');

const app = express();
const PORT = 5050;
const HOST = '192.168.3.87';

// ================== تهيئة خادم HTTP و Socket.IO ==================

const server = http.createServer(app);

const io = new socketIo.Server(server, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});

// ✅ تمرير كائن المقبس الرئيسي (io) إلى authController
authController.setIoInstance(io);

// ✅ ربط متحكم المحادثة بحدث الاتصال
io.on('connection', chatController.registerChatEvents);

// ================== نهاية تهيئة Socket.IO ==================


// استخدام Middleware
app.use(cors());
app.use(express.json());

// اختبار الاتصال بقاعدة البيانات
db.getConnection((err, connection) => {
    if (err) {
        console.error('Error connecting to MySQL:', err);
        return;
    }
    console.log('Connected to the MySQL database');
    connection.release();
});

// استخدام المسارات
app.use('/api/auth', authRoutes);
app.use('/api/users', userRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api', taskRoutes);
app.use('/api', dashboardRoutes);
app.use('/api/employee', employeeRoutes);
app.use('/api/ai', aiRoutes);
app.use('/api/chat', chatRoutes);

server.listen(PORT, HOST, () => {
    console.log(`Server is running at http://${HOST}:${PORT}`);
});