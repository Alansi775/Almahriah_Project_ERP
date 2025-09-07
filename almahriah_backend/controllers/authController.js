// almahriah_backend/controllers/authController.js

const db = require('../config/db');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const { v4 } = require('uuid'); // new 
let io; // Variable to hold the Socket.IO instance

//  دالة جديدة لتعيين كائن المقبس
exports.setIoInstance = (socketIo) => {
    io = socketIo;
};


exports.login = (req, res) => {
    const { username, password } = req.body;
    const query = 'SELECT * FROM users WHERE username = ?';

    db.query(query, [username], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'خطأ في الخادم' });
        }

        if (results.length === 0) {
            return res.status(401).json({ message: 'اسم المستخدم أو كلمة المرور غير صحيحة.' });
        }

        const user = results[0];

        // مقارنة كلمة المرور
        const passwordMatch = bcrypt.compareSync(password, user.password);
        if (!passwordMatch) {
            return res.status(401).json({ message: 'اسم المستخدم أو كلمة المرور غير صحيحة.' });
        }

        //  إضافة هذا السطر لتحديث حالة تسجيل الدخول
        const updateLoginStatusSql = 'UPDATE users SET isLoggedIn = 1 WHERE id = ?';
        db.query(updateLoginStatusSql, [user.id], (err, result) => {
            if (err) {
                console.error('Error updating login status:', err);
            }
            //  إرسال بث لجميع العملاء عند تسجيل الدخول
            if (io) {
                io.emit('user-status-changed', { userId: user.id.toString(), status: true });
            }
        });

        // إنشاء رمز وصول (Token)
        const token = jwt.sign(
            // تم إضافة "department" هنا
            { id: user.id, role: user.role, department: user.department },
            process.env.JWT_SECRET,
            { expiresIn: '1h' } // صلاحية الرمز لساعة واحدة
        );

        // إزالة كلمة المرور من بيانات المستخدم قبل إرسالها
        delete user.password;

        // إرسال الرمز وبيانات المستخدم في الاستجابة
        res.status(200).json({
            message: 'تم تسجيل الدخول بنجاح.',
            user: user,
            token: token
        });
    });
};

exports.logout = (req, res) => {
    const userId = req.body.userId;
    const sql = 'UPDATE users SET isLoggedIn = 0 WHERE id = ?';
    db.query(sql, [userId], (err, result) => {
        if (err) {
            console.error('Database error on logout:', err);
            return res.status(500).json({ message: 'فشل تسجيل الخروج.' });
        }
        
        //  إرسال بث لجميع العملاء عند تسجيل الخروج
        if (io) {
            io.emit('user-status-changed', { userId: userId.toString(), status: false });
        }
        res.status(200).json({ message: 'تم تسجيل الخروج بنجاح.' });
    });
};

// دالة جديدة لتسجيل مستخدم جديد
exports.register = (req, res) => {
    const { username, password } = req.body;

    if (!username || !password) {
        return res.status(400).json({ message: 'الرجاء إدخال اسم المستخدم وكلمة المرور' });
    }

    // تشفير كلمة المرور قبل حفظها في قاعدة البيانات
    bcrypt.hash(password, 10, (err, hashedPassword) => {
        if (err) {
            console.error('Hashing error:', err);
            return res.status(500).json({ message: 'حدث خطأ أثناء تشفير كلمة المرور.' });
        }

        const sql = 'INSERT INTO users (username, password) VALUES (?, ?)';
        db.query(sql, [username, hashedPassword], (err, result) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ message: 'فشل تسجيل المستخدم.' });
            }
            res.status(201).json({ message: 'تم تسجيل المستخدم بنجاح!' });
        });
    });
};

// new function to generate a QR token
exports.generateQrToken = (req, res) => {
    const { userId } = req.body; 
    const qrToken = v4();

    const sql = 'INSERT INTO qr_tokens (qrToken, userId) VALUES (?, ?)';
    db.query(sql, [qrToken, userId], (err, result) => {
        if (err) {
            console.error('Error storing QR token:', err);
            return res.status(500).json({message: 'فشل توليد رمز QR.'});
        }
        res.status(200).json({ message: 'تم توليد رمز QR بنجاح.', qrToken });
    });
};

// New function to log in with a QR token
exports.loginWithQr = (req, res) => {
    const { qrToken } = req.body;

    const sql = 'SELECT * FROM qr_tokens WHERE qrToken = ?';
    db.query(sql, [qrToken], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'خطأ في الخادم.' });
        }

        if (results.length === 0) {
            return res.status(401).json({ message: 'رمز QR غير صالح أو منتهي الصلاحية.' });
        }

        const tokenData = results[0];
        const userId = tokenData.userId;

        // Clean up the used QR token immediately
        const deleteSql = 'DELETE FROM qr_tokens WHERE qrToken = ?';
        db.query(deleteSql, [qrToken], (err, result) => {
            if (err) {
                console.error('Error deleting QR token:', err);
                // We will continue to log in the user even if deletion fails to avoid login issues.
            }
        });

        // Get the user data and generate a new JWT
        const userQuery = 'SELECT * FROM users WHERE id = ?';
        db.query(userQuery, [userId], (err, userResults) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ message: 'خطأ في الخادم.' });
            }

            if (userResults.length === 0) {
                return res.status(404).json({ message: 'المستخدم غير موجود.' });
            }

            const user = userResults[0];
            const token = jwt.sign(
                { id: user.id, role: user.role, department: user.department },
                process.env.JWT_SECRET,
                { expiresIn: '1h' }
            );

            delete user.password;
            res.status(200).json({
                message: 'تم تسجيل الدخول بنجاح.',
                user: user,
                token: token
            });
        });
    });
};

//  دالة جديدة لتوليد رمز QR مؤقت لصفحة تسجيل الدخول
exports.generateTempQr = (req, res) => {
    const qrToken = v4(); // توليد رمز مؤقت فريد
    const sql = 'INSERT INTO qr_tokens (qrToken) VALUES (?)';
    
    db.query(sql, [qrToken], (err, result) => {
        if (err) {
            console.error('Error storing temporary QR token:', err);
            return res.status(500).json({ message: 'فشل توليد رمز QR مؤقت.' });
        }
        //  إرسال الرمز المؤقت فقط
        res.status(200).json({ message: 'تم توليد الرمز بنجاح.', qrToken });
    });
};

//  دالة جديدة لربط الجلسة
exports.linkQrSession = (req, res) => {
    const { qrToken } = req.body;
    const userId = req.user.id; // يتم الحصول على الـ userId من رمز التوثيق (JWT)

    const sql = 'UPDATE qr_tokens SET userId = ?, createdAt = NOW() WHERE qrToken = ?';
    db.query(sql, [userId, qrToken], (err, result) => {
        if (err) {
            console.error('Error linking QR session:', err);
            return res.status(500).json({ message: 'فشل ربط الجلسة.' });
        }
        
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'رمز QR غير صالح أو منتهي الصلاحية.' });
        }
        
        res.status(200).json({ message: 'تم ربط الجلسة بنجاح.' });
    });
};

//  دالة جديدة للتحقق من حالة الـ QR
exports.checkQrSession = (req, res) => {
    const { qrToken } = req.query; // 💡 يتم استقبال الرمز من الـ query
    
    // 💡 الاستعلام عن الرمز المؤقت
    const sql = 'SELECT userId FROM qr_tokens WHERE qrToken = ?';
    db.query(sql, [qrToken], (err, results) => {
        if (err) {
            console.error('Error checking QR session:', err);
            return res.status(500).json({ message: 'خطأ في الخادم.' });
        }
        
        if (results.length > 0 && results[0].userId) {
            const userId = results[0].userId;
            
            //  إذا كان الرمز مرتبطًا بمستخدم، قم بإزالة الرمز من الجدول
            const deleteSql = 'DELETE FROM qr_tokens WHERE qrToken = ?';
            db.query(deleteSql, [qrToken], (deleteErr, deleteResult) => {
                if (deleteErr) {
                    console.error('Error deleting used QR token:', deleteErr);
                }
            });
            
            //  الآن، قم باسترجاع بيانات المستخدم لإنشاء رمز JWT جديد
            const userQuery = 'SELECT * FROM users WHERE id = ?';
            db.query(userQuery, [userId], (userErr, userResults) => {
                if (userErr) {
                    return res.status(500).json({ message: 'خطأ في الخادم.' });
                }
                const user = userResults[0];
                const token = jwt.sign(
                    { id: user.id, role: user.role, department: user.department },
                    process.env.JWT_SECRET,
                    { expiresIn: '1h' }
                );
                
                delete user.password;
                res.status(200).json({
                    message: 'تم تسجيل الدخول بنجاح.',
                    user: user,
                    token: token
                });
            });
        } else {
            //  لا يوجد مستخدم مرتبط بعد، استمر في الانتظار
            res.status(200).json({ message: 'في انتظار المسح.' });
        }
    });
};

//  دالة جديدة لتسجيل الدخول مباشرةً عبر QR
exports.qrLogin = (req, res) => {
    const { qrToken } = req.body;
    
    // 1. البحث عن الرمز في قاعدة البيانات
    const sql = 'SELECT userId FROM qr_tokens WHERE qrToken = ? AND userId IS NOT NULL';
    db.query(sql, [qrToken], (err, results) => {
        if (err) {
            console.error('Error during QR login:', err);
            return res.status(500).json({ message: 'خطأ في الخادم.' });
        }
        
        if (results.length === 0) {
            return res.status(404).json({ message: 'رمز QR غير صالح أو منتهي الصلاحية.' });
        }
        
        const userId = results[0].userId;
        
        // 2. الحصول على بيانات المستخدم كاملة
        const userQuery = 'SELECT * FROM users WHERE id = ?';
        db.query(userQuery, [userId], (userErr, userResults) => {
            if (userErr) {
                console.error('Error fetching user data for QR login:', userErr);
                return res.status(500).json({ message: 'خطأ في الخادم.' });
            }
            
            const user = userResults[0];
            const token = jwt.sign(
                { id: user.id, role: user.role, department: user.department },
                process.env.JWT_SECRET,
                { expiresIn: '1h' }
            );

            // 3. حذف الرمز من قاعدة البيانات لمنع استخدامه مرة أخرى
            const deleteSql = 'DELETE FROM qr_tokens WHERE qrToken = ?';
            db.query(deleteSql, [qrToken], (deleteErr, deleteResult) => {
                if (deleteErr) {
                    console.error('Error deleting used QR token:', deleteErr);
                }
            });
            
            delete user.password;
            res.status(200).json({
                message: 'تم تسجيل الدخول بنجاح!',
                user: user,
                token: token
            });
        });
    });
};
