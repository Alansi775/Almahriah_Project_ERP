// almahriah_backend/controllers/adminController.js
const db = require('../config/db');
const bcrypt = require('bcryptjs');


// Function to create a new user
exports.createUser = (req, res) => {
    const { username, password, department, role, fullName } = req.body;

    if (!username || !password || !department || !role || !fullName) {
        return res.status(400).json({ message: 'الرجاء إدخال جميع الحقول' });
    }

    // Hash the password before saving
    bcrypt.hash(password, 10, (err, hashedPassword) => {
        if (err) {
            return res.status(500).json({ message: 'فشل تشفير كلمة المرور' });
        }

        const sql = 'INSERT INTO users (username, password, role, department, fullName) VALUES (?, ?, ?, ?, ?)';
        db.query(sql, [username, hashedPassword, role, department, fullName], (err, result) => {
            if (err) {
                if (err.code === 'ER_DUP_ENTRY') {
                    return res.status(409).json({ message: 'اسم المستخدم موجود بالفعل' });
                }
                console.error('Database error:', err);
                return res.status(500).json({ message: 'فشل إضافة المستخدم' });
            }
            res.status(201).json({ message: 'تم إضافة المستخدم بنجاح!' });
        });
    });
};

// Function to get all users
exports.getUsers = (req, res) => {
    // ✅ تم إضافة profilePictureUrl إلى الاستعلام
    const sql = 'SELECT id, username, department, role, fullName, isActive, profilePictureUrl FROM users';
    db.query(sql, (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب المستخدمين', error: err.message });
        }
        res.status(200).json(results);
    });
};

// Function to get a specific user by ID
exports.getUser = (req, res) => {
    const userId = req.params.id;
    const sql = 'SELECT id, username, department, role, fullName, isActive, profilePictureUrl FROM users WHERE id = ?';
    db.query(sql, [userId], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب بيانات المستخدم' });
        }
        if (results.length === 0) {
            return res.status(404).json({ message: 'المستخدم غير موجود' });
        }
        res.status(200).json(results[0]);
    });
};

// Function to toggle a user's active status
exports.toggleUserActiveStatus = (req, res) => {
    const userId = req.params.id;
    const { isActive } = req.body;

    const sql = 'UPDATE users SET isActive = ? WHERE id = ?';
    db.query(sql, [isActive, userId], (err, result) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل تحديث حالة المستخدم' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'المستخدم غير موجود' });
        }
        res.status(200).json({ message: `تم ${isActive ? 'تفعيل' : 'حظر'} المستخدم بنجاح!` });
    });
};

// Function to delete a user
// Function to delete a user
exports.deleteUser = (req, res) => {
  const userId = req.params.id;

  // Ensure the user ID is a number for a strict comparison
  const userIdAsInt = parseInt(userId, 10);

  // Check if the user ID is exactly 1 (the main admin)
  if (userIdAsInt === 1) {
    return res.status(403).json({ message: 'لا يمكن حذف حساب المسؤول الرئيسي.' });
  }

  // Use a transaction for safety
  db.beginTransaction(err => {
    // If an error occurs during the transaction start
    if (err) {
      return res.status(500).json({ message: 'فشل بدء عملية الحذف.', error: err.message });
    }

    // Step 1: Delete from the sessions table
    const deleteSessionsSql = 'DELETE FROM sessions WHERE userId = ?';
    db.query(deleteSessionsSql, [userId], (err, result) => {
      if (err) {
        return db.rollback(() => {
          return res.status(500).json({ message: 'حدث خطأ أثناء حذف الجلسات المرتبطة.', error: err.message });
        });
      }

      // Step 2: Delete from the users table (only if Step 1 was successful)
      const deleteUserSql = 'DELETE FROM users WHERE id = ?';
      db.query(deleteUserSql, [userId], (err, result) => {
        if (err) {
          return db.rollback(() => {
            return res.status(500).json({ message: 'حدث خطأ أثناء حذف المستخدم.', error: err.message });
          });
        }

        if (result.affectedRows === 0) {
          return db.rollback(() => {
            return res.status(404).json({ message: 'المستخدم غير موجود.' });
          });
        }

        // Step 3: Commit the transaction if everything succeeded
        db.commit(err => {
          if (err) {
            return db.rollback(() => {
              return res.status(500).json({ message: 'فشل إتمام عملية الحذف.', error: err.message });
            });
          }
          res.status(200).json({ message: 'تم حذف المستخدم بنجاح.' });
        });
      });
    });
  });
};

// Function to get dashboard statistics
exports.getDashboardStats = (req, res) => {
    const totalUsersSql = 'SELECT COUNT(*) AS total FROM users';
    const activeUsersSql = 'SELECT COUNT(*) AS active FROM users WHERE isActive = 1';
    const adminsSql = 'SELECT COUNT(*) AS admins FROM users WHERE role = "Admin"';
    const usersByDepartmentSql = 'SELECT department, COUNT(*) AS count FROM users GROUP BY department';

    const stats = {};

    db.query(totalUsersSql, (err, result) => {
        if (err) return res.status(500).json({ message: 'Database error', error: err });
        stats.totalUsers = result[0].total;

        db.query(activeUsersSql, (err, result) => {
            if (err) return res.status(500).json({ message: 'Database error', error: err });
            stats.activeUsers = result[0].active;

            db.query(adminsSql, (err, result) => {
                if (err) return res.status(500).json({ message: 'Database error', error: err });
                stats.admins = result[0].admins;

                db.query(usersByDepartmentSql, (err, result) => {
                    if (err) return res.status(500).json({ message: 'Database error', error: err });
                    stats.usersByDepartment = result;

                    res.status(200).json(stats);
                });
            });
        });
    });
};

// Function to create a new leave request
exports.createLeaveRequest = (req, res) => {
    const { userId, startDate, endDate, reason } = req.body;
    const sql = 'INSERT INTO leave_requests (userId, startDate, endDate, reason) VALUES (?, ?, ?, ?)';
    db.query(sql, [userId, startDate, endDate, reason], (err, result) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل إرسال طلب الإجازة.', error: err.message });
        }
        res.status(201).json({ message: 'تم إرسال طلب الإجازة بنجاح!' });
    });
};


//  Function to get pending leave requests for a specific department (for managers)
exports.getManagerPendingLeaveRequests = (req, res) => {
    // The department is passed from the auth middleware
    const managerDepartment = req.user.department; 

    const query = `
        SELECT lr.*, u.fullName, u.department, u.role
        FROM leave_requests lr
        JOIN users u ON lr.userId = u.id
        WHERE lr.status = 'Pending' AND u.department = ?
        ORDER BY lr.createdAt DESC
    `;
    
    db.query(query, [managerDepartment], (err, results) => {
        if (err) {
            console.error('Database query error:', err);
            return res.status(500).json({ message: 'خطأ في الخادم' });
        }
        res.status(200).json(results);
    });
};

//  Add this function back
exports.getPendingLeaveRequests = (req, res) => {
    const query = `
        SELECT lr.*, u.fullName, u.department, u.role
        FROM leave_requests lr
        JOIN users u ON lr.userId = u.id
        WHERE lr.status = 'Pending'
        ORDER BY lr.createdAt DESC
    `;
    
    db.query(query, (err, results) => {
        if (err) {
            console.error('Database query error:', err);
            return res.status(500).json({ message: 'خطأ في الخادم' });
        }
        res.status(200).json(results);
    });
};


// Function to update leave request status (Accept or Reject)
exports.updateLeaveRequestStatus = (req, res) => {
    const { id } = req.params;
    const { status } = req.body;

    if (status !== 'Accepted' && status !== 'Rejected') {
        return res.status(400).json({ message: 'حالة الطلب غير صالحة.' });
    }

    const query = 'UPDATE leave_requests SET status = ? WHERE id = ?';
    db.query(query, [status, id], (err, result) => {
        if (err) {
            console.error('Database update error:', err);
            return res.status(500).json({ message: 'خطأ في الخادم' });
        }

        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'لم يتم العثور على الطلب.' });
        }

        res.status(200).json({ message: `تم ${status === 'Accepted' ? 'قبول' : 'رفض'} الطلب بنجاح.` });
    });
};

// Function to get employee's leave requests
exports.getEmployeeLeaveRequests = (req, res) => {
    const { userId } = req.params;
    const query = `
        SELECT * FROM leave_requests
        WHERE userId = ?
        ORDER BY createdAt DESC
    `;
    db.query(query, [userId], (err, results) => {
        if (err) {
            console.error('Database query error:', err);
            return res.status(500).json({ message: 'فشل جلب طلبات الإجازة.' });
        }
        res.status(200).json(results);
    });
};

// Function to delete a leave request
exports.deleteLeaveRequest = (req, res) => {
    const { id } = req.params;

    const query = 'DELETE FROM leave_requests WHERE id = ?';
    db.query(query, [id], (err, result) => {
        if (err) {
            console.error('Error deleting leave request:', err);
            return res.status(500).json({ message: 'Server error occurred while deleting the request.' });
        }
        
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'Leave request not found.' });
        }

        res.status(200).json({ message: 'Leave request deleted successfully.' });
    });
};

// Function for HR to get all leave requests
exports.getAllLeaveRequests = (req, res) => {
    const query = `
        SELECT 
            lr.id, 
            lr.userId, 
            lr.startDate, 
            lr.endDate, 
            lr.reason, 
            lr.status, 
            lr.createdAt, 
            u.fullName, 
            u.department
        FROM 
            leave_requests lr
        JOIN 
            users u ON lr.userId = u.id
        ORDER BY 
            lr.createdAt DESC
    `;
    
    db.query(query, (err, results) => {
        if (err) {
            console.error('Database query error:', err.message);
            console.log('Failing SQL Query:', query);
            return res.status(500).json({ message: 'فشل جلب سجل الإجازات.' });
        }
        res.status(200).json(results);
    });
};

// Function for HR to delete all leave requests
exports.deleteAllLeaveRequests = (req, res) => {
    const query = 'DELETE FROM leave_requests';

    db.query(query, (err, result) => {
        if (err) {
            console.error('Database deletion error:', err);
            return res.status(500).json({ message: `فشل حذف جميع طلبات الإجازة: ${err.message}` });
        }
        res.status(200).json({ message: 'تم حذف جميع طلبات الإجازة بنجاح.' });
    });
};

// Function to get unique departments
exports.getUniqueDepartments = (req, res) => {
    const sql = 'SELECT DISTINCT department FROM users WHERE department IS NOT NULL';
    db.query(sql, (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب الأقسام.' });
        }
        res.status(200).json(results);
    });
};


// Function to update user profile picture URL
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// إعداد التخزين
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const uploadPath = './uploads/profiles/';
        // إنشاء المجلد إذا لم يكن موجوداً
        if (!fs.existsSync(uploadPath)) {
            fs.mkdirSync(uploadPath, { recursive: true });
        }
        cb(null, uploadPath);
    },
    filename: (req, file, cb) => {
        // اسم الملف: user_id_timestamp.extension
        const userId = req.user.id;
        const timestamp = Date.now();
        const extension = path.extname(file.originalname);
        cb(null, `user_${userId}_${timestamp}${extension}`);
    }
});

// فلتر للصور فقط
const fileFilter = (req, file, cb) => {
    if (file.mimetype.startsWith('image/')) {
        cb(null, true);
    } else {
        cb(new Error('يُسمح برفع الصور فقط'), false);
    }
};

// إعداد multer
const upload = multer({ 
    storage: storage,
    limits: {
        fileSize: 5 * 1024 * 1024 // 5MB حد أقصى
    },
    fileFilter: fileFilter
});

// دالة رفع صورة الملف الشخصي
exports.uploadProfilePicture = (req, res) => {
    upload.single('profilePicture')(req, res, (err) => {
        if (err instanceof multer.MulterError) {
            if (err.code === 'LIMIT_FILE_SIZE') {
                return res.status(400).json({ message: 'حجم الملف كبير جداً (الحد الأقصى 5MB)' });
            }
            return res.status(400).json({ message: 'خطأ في رفع الملف: ' + err.message });
        } else if (err) {
            return res.status(400).json({ message: err.message });
        }

        if (!req.file) {
            return res.status(400).json({ message: 'لم يتم اختيار ملف' });
        }

        const userId = req.user.id;
        const profilePictureUrl = `/uploads/profiles/${req.file.filename}`;

        // تحديث قاعدة البيانات
        const sql = 'UPDATE users SET profilePictureUrl = ? WHERE id = ?';
        db.query(sql, [profilePictureUrl, userId], (err, result) => {
            if (err) {
                console.error('Database error:', err);
                // حذف الملف في حالة فشل قاعدة البيانات
                fs.unlinkSync(req.file.path);
                return res.status(500).json({ message: 'فشل تحديث قاعدة البيانات' });
            }

            if (result.affectedRows === 0) {
                fs.unlinkSync(req.file.path);
                return res.status(404).json({ message: 'المستخدم غير موجود' });
            }

            res.status(200).json({ 
                message: 'تم رفع الصورة بنجاح',
                profilePictureUrl: profilePictureUrl 
            });
        });
    });
};

// دالة حذف صورة الملف الشخصي
exports.deleteProfilePicture = (req, res) => {
    const userId = req.user.id;

    // الحصول على رابط الصورة الحالية
    const getSql = 'SELECT profilePictureUrl FROM users WHERE id = ?';
    db.query(getSql, [userId], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'خطأ في قاعدة البيانات' });
        }

        if (results.length === 0) {
            return res.status(404).json({ message: 'المستخدم غير موجود' });
        }

        const currentPictureUrl = results[0].profilePictureUrl;

        // تحديث قاعدة البيانات (حذف الرابط)
        const updateSql = 'UPDATE users SET profilePictureUrl = NULL WHERE id = ?';
        db.query(updateSql, [userId], (err, result) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ message: 'فشل حذف الصورة من قاعدة البيانات' });
            }

            // حذف الملف من النظام
            if (currentPictureUrl) {
                const filePath = path.join(__dirname, '..', currentPictureUrl);
                fs.unlink(filePath, (err) => {
                    if (err) {
                        console.log('تعذر حذف الملف:', err.message);
                    }
                });
            }

            res.status(200).json({ message: 'تم حذف الصورة بنجاح' });
        });
    });
};

/// end of user profile picture functions ///////////////////////////////