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
    const sql = 'SELECT id, username, department, role, fullName, isActive FROM users';
    db.query(sql, (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب المستخدمين', error: err.message });
        }
        res.status(200).json(results);
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
exports.deleteUser = (req, res) => {
  const userId = req.params.id;

  if (userId == 1) {
    return res.status(403).json({ message: 'لا يمكن حذف حساب المسؤول الرئيسي.' });
  }

  // Use a transaction for safety
  db.beginTransaction(err => {
    if (err) {
      return res.status(500).json({ message: 'فشل بدء عملية الحذف.', error: err.message });
    }

    // Step 1: Check for the sessions table before deleting
    const checkTableSql = 'SHOW TABLES LIKE "sessions"';
    db.query(checkTableSql, (err, tables) => {
      if (err) {
        return db.rollback(() => {
          return res.status(500).json({ message: 'فشل التحقق من جدول الجلسات.', error: err.message });
        });
      }

      // If the sessions table exists, delete from it
      if (tables.length > 0) {
        const deleteSessionsSql = 'DELETE FROM sessions WHERE userId = ?';
        db.query(deleteSessionsSql, [userId], (err, result) => {
          if (err) {
            return db.rollback(() => {
              return res.status(500).json({ message: 'حدث خطأ أثناء حذف الجلسات المرتبطة.', error: err.message });
            });
          }
          // Continue to the next step
          deleteFromUsersTable();
        });
      } else {
        // If sessions table does not exist, skip this step
        console.warn('Warning: sessions table not found. Skipping session deletion.');
        deleteFromUsersTable();
      }
    });

    // Step 2: Delete from the users table (this is a nested function)
    function deleteFromUsersTable() {
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
    }
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


// Function to get pending leave requests
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