// almahriah_backend/index.js

require('dotenv').config(); 
const express = require('express');
const cors = require('cors');
const path = require('path');
const db = require('./services/db');
const authRoutes = require('./routes/authRoutes');
const userRoutes = require('./routes/userRoutes');
const adminRoutes = require('./routes/adminRoutes');
// استيراد مسار المهام الجديد
const taskRoutes = require('./routes/taskRoutes');


const app = express();
const PORT = 5050;
const HOST = '192.168.1.107'; // ضع هنا الـ IP الخاص بك

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
// استخدام مسارات المهام الجديدة
app.use('/api', taskRoutes);

app.listen(PORT, HOST, () => {
    console.log(`Server is running at http://${HOST}:${PORT}`);
});