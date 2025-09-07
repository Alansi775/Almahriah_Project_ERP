const db = require('../config/db');

// almahriah_backend/controllers/taskController.js


// دالة لإنشاء مهمة جديدة
exports.createTask = (req, res) => {
    const { title, description, assignedToId, priority } = req.body;
    const assignedById = req.user.id; // يتم الحصول على معرف المدير من الـ token

    if (!title || !assignedToId) {
        return res.status(400).json({ message: 'الرجاء إدخال عنوان المهمة واختيار الموظف المسؤول.' });
    }

    const sql = 'INSERT INTO tasks (title, description, assignedToId, assignedById, priority) VALUES (?, ?, ?, ?, ?)';
    db.query(sql, [title, description, assignedToId, assignedById, priority], (err, result) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل إضافة المهمة.' });
        }
        res.status(201).json({ message: 'تم إضافة المهمة بنجاح!', taskId: result.insertId });
    });
};

// دالة لجلب المهام المخصصة لموظف معين
exports.getUserTasks = (req, res) => {
    const userId = req.user.id; // يتم الحصول على معرف المستخدم من الـ token
    const sql = `
        SELECT t.*, u.fullName as assignedToName, m.fullName as assignedByName
        FROM tasks t
        JOIN users u ON t.assignedToId = u.id
        JOIN users m ON t.assignedById = m.id
        WHERE t.assignedToId = ?
        ORDER BY t.createdAt DESC;
    `;
    db.query(sql, [userId], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب المهام.' });
        }
        res.status(200).json(results);
    });
};

// دالة لجلب جميع المهام الخاصة بقسم معين (للمدير)
exports.getDepartmentTasks = (req, res) => {
    const departmentName = req.user.department; // يتم الحصول على اسم القسم من الـ token
    const sql = `
        SELECT t.*, u.fullName as assignedToName, m.fullName as assignedByName
        FROM tasks t
        JOIN users u ON t.assignedToId = u.id
        JOIN users m ON t.assignedById = m.id
        WHERE u.department = ?
        ORDER BY t.createdAt DESC;
    `;
    db.query(sql, [departmentName], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب مهام القسم.' });
        }
        res.status(200).json(results);
    });
};

// دالة لتحديث حالة المهمة
//  دالة لتحديث حالة المهمة (النسخة النهائية والمُصححة)
exports.updateTaskStatus = (req, res) => {
    const { id } = req.params;
    const { status } = req.body;
    const userId = req.user.id; 

    const validStatuses = ['pending', 'in_progress', 'completed', 'canceled']; 
    if (!validStatuses.includes(status)) {
        return res.status(400).json({ message: 'حالة غير صالحة.' });
    }

    let updateField = '';
    
    //  تحديث الكود ليشمل حالة "الإلغاء"
    if (status === 'in_progress') {
        updateField = 'inProgressAt';
    } else if (status === 'completed') {
        updateField = 'completedAt';
    } else if (status === 'canceled') { // ✨ تم إضافة هذا الشرط
        updateField = 'canceledAt';
    }
    
    // Check if a specific date field needs to be updated.
    // If updateField is empty, it means the status is 'pending', and we only update the status.
    const sql = `
        UPDATE tasks 
        SET status = ?, 
            ${updateField ? `${updateField} = NOW()` : ''} 
        WHERE id = ?;
    `;
    
    // Clean up extra commas if updateField is empty
    const finalSql = sql.replace(/,\s*WHERE/, ' WHERE');

    const params = [status, id];

    db.query(finalSql, params, (err, result) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل تحديث حالة المهمة.' });
        }
        if (result.affectedRows === 0) {
            return res.status(404).json({ message: 'المهمة غير موجودة.' });
        }
        res.status(200).json({ message: 'تم تحديث حالة المهمة بنجاح.' });
    });
};


// دالة جديدة لجلب جميع المهام (للمدير العام)
exports.getAllTasks = (req, res) => {
    const sql = `
        SELECT t.*, u.fullName as assignedToName, m.fullName as assignedByName
        FROM tasks t
        JOIN users u ON t.assignedToId = u.id
        JOIN users m ON t.assignedById = m.id
        ORDER BY t.createdAt DESC;
    `;
    db.query(sql, (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب جميع المهام.' });
        }
        res.status(200).json(results);
    });
};

// دالة لجلب الموظفين التابعين لمدير القسم
exports.getDepartmentEmployees = (req, res) => {
    const managerDepartment = req.user.department;

    console.log('Fetching employees for department:', managerDepartment); // Keep this for debugging

    console.log('Fetching employees for department:', managerDepartment, 'with role:', 'Employee');


    // Corrected SQL query to only fetch users with the 'Employee' role in the manager's department
    const sql = 'SELECT id, fullName, role FROM users WHERE department = ? AND role = "Employee"';

    db.query(sql, [managerDepartment], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب موظفي القسم.' });
        }
        res.status(200).json(results);
    });
};

exports.getTasksByDepartment = (req, res) => {
    let department;
    
    // Check if the department is provided in the query (for Admin)
    if (req.query.department) {
        department = req.query.department;
    } else {
        // If not, get it from the user's token (for Manager)
        department = req.user.department;
    }

    const sql = `
        SELECT
            t.*,
            u.fullName AS assignedToName,
            a.fullName AS assignedByName
        FROM tasks t
        JOIN users u ON t.assignedToId = u.id
        LEFT JOIN users a ON t.assignedById = a.id
        WHERE u.department = ?
    `;

    
    db.query(sql, [department], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب مهام القسم.' });
        }
        res.status(200).json(results);
    });
};

// دالة جديدة لحذف جميع المهام الخاصة بقسم المدير
exports.deleteAllDepartmentTasks = (req, res) => {
    const departmentName = req.user.department; // الحصول على قسم المدير من الـ token

    const sql = `
        DELETE t FROM tasks t
        JOIN users u ON t.assignedToId = u.id
        WHERE u.department = ?;
    `;
    db.query(sql, [departmentName], (err, result) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل حذف مهام القسم.' });
        }
        res.status(200).json({ message: `تم حذف ${result.affectedRows} مهمة من قسم ${departmentName}.` });
    });
};

// دالة لحذف مهمة فردية (للمدير فقط)
exports.deleteTask = (req, res) => {
    const { id } = req.params;
    const managerDepartment = req.user.department;

    // التأكد من أن المهمة تابعة لقسم المدير قبل حذفها
    const sqlCheck = `SELECT assignedToId FROM tasks WHERE id = ?`;
    db.query(sqlCheck, [id], (err, results) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل التحقق من المهمة.' });
        }
        if (results.length === 0) {
            return res.status(404).json({ message: 'المهمة غير موجودة.' });
        }
        const assignedToId = results[0].assignedToId;

        const sqlCheckUser = `SELECT department FROM users WHERE id = ?`;
        db.query(sqlCheckUser, [assignedToId], (err, userResults) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ message: 'فشل التحقق من الموظف.' });
            }
            if (userResults[0].department !== managerDepartment) {
                return res.status(403).json({ message: 'لا تملك صلاحية حذف هذه المهمة.' });
            }

            // إذا كانت المهمة تابعة لقسمه، قم بالحذف
            const sqlDelete = 'DELETE FROM tasks WHERE id = ?';
            db.query(sqlDelete, [id], (err, result) => {
                if (err) {
                    console.error('Database error:', err);
                    return res.status(500).json({ message: 'فشل حذف المهمة.' });
                }
                res.status(200).json({ message: 'تم حذف المهمة بنجاح.' });
            });
        });
    });
};


//  New function to get tasks for a department with optional status filter
exports.getDepartmentTasks = (req, res) => {
    const departmentName = req.user.department;
    const status = req.query.status;

    let sql = `
        SELECT t.*, u.fullName as assignedToName, m.fullName as assignedByName
        FROM tasks t
        JOIN users u ON t.assignedToId = u.id
        JOIN users m ON t.assignedById = m.id
        WHERE u.department = ?
    `;
    const params = [departmentName];

    if (status) {
        sql += ' AND t.status = ?';
        params.push(status);
    }
    
    db.query(sql, params, (err, tasks) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب المهام.' });
        }
        res.status(200).json({ tasks: tasks });
    });
};