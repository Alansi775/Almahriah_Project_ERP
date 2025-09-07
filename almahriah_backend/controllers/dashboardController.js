// almahriah_backend/controllers/dashboardController.js جديد 

const db = require('../config/db');

// دالة لجلب إحصائيات لوحة تحكم المدير
exports.getManagerDashboardStats = (req, res) => {
    const departmentName = req.user.department;

    const tasksStatsSql = `
        SELECT
            COUNT(*) AS totalTasks,
            SUM(CASE WHEN status = 'completed' THEN 1 ELSE 0 END) AS completedTasks,
            SUM(CASE WHEN status = 'in_progress' THEN 1 ELSE 0 END) AS inProgressTasks,
            --  تم تعديل هذا السطر من 'not_started' إلى 'pending'
            SUM(CASE WHEN status = 'pending' THEN 1 ELSE 0 END) AS notStartedTasks
        FROM tasks
        WHERE assignedToId IN (
            SELECT id FROM users WHERE department = ?
        );
    `;

    //  استعلام SQL لجلب إحصائيات الموظفين الخاصة بالقسم
    const usersStatsSql = `
        SELECT
            COUNT(*) AS totalUsers,
            SUM(CASE WHEN isLoggedIn = 1 THEN 1 ELSE 0 END) AS activeUsers
        FROM users
        WHERE department = ? AND role = 'Employee';
    `;

    // تنفيذ الاستعلامين في نفس الوقت
    db.query(tasksStatsSql, [departmentName], (err, tasksStats) => {
        if (err) {
            console.error('Database error:', err);
            return res.status(500).json({ message: 'فشل جلب إحصائيات المهام.' });
        }

        db.query(usersStatsSql, [departmentName], (err, usersStats) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ message: 'فشل جلب إحصائيات المستخدمين.' });
            }

            // تجميع النتائج في كائن واحد وإرساله
            const responseData = {
                totalTasks: tasksStats[0].totalTasks,
                completedTasks: tasksStats[0].completedTasks,
                inProgressTasks: tasksStats[0].inProgressTasks,
                notStartedTasks: tasksStats[0].notStartedTasks,
                totalUsers: usersStats[0].totalUsers,
                activeUsers: usersStats[0].activeUsers,
                pendingLeaveRequests: 0 // يتم إضافة هذا لاحقًا إذا كانت هناك دالة خاصة به
            };

            res.status(200).json(responseData);
        });
    });
};

// دالة لجلب إحصائيات لوحة تحكم المدير العام (مطلوبة للوحة Admin)
exports.getAdminDashboardStats = (req, res) => {
    // استعلام SQL لجلب إجمالي المستخدمين والمدراء النشطين
    const usersStatsSql = `
        SELECT 
            COUNT(*) AS totalUsers,
            SUM(CASE WHEN isLoggedIn = 1 THEN 1 ELSE 0 END) AS activeUsers,
            SUM(CASE WHEN role = 'Admin' THEN 1 ELSE 0 END) AS admins
        FROM users;
    `;

    // استعلام SQL لجلب عدد المستخدمين حسب القسم
    const usersByDepartmentSql = `
        SELECT department, COUNT(*) AS count 
        FROM users 
        GROUP BY department;
    `;

    // استعلام SQL لجلب عدد طلبات الإجازة المعلقة
    const pendingLeaveRequestsSql = `
        SELECT COUNT(*) AS count FROM leave_requests WHERE status = 'pending';
    `;

    // تنفيذ جميع الاستعلامات
    db.query(usersStatsSql, (err, usersStats) => {
        if (err) return res.status(500).json({ message: 'فشل جلب إحصائيات المستخدمين.' });

        db.query(usersByDepartmentSql, (err, usersByDepartment) => {
            if (err) return res.status(500).json({ message: 'فشل جلب إحصائيات الأقسام.' });
            
            db.query(pendingLeaveRequestsSql, (err, pendingLeaveRequests) => {
                if (err) return res.status(500).json({ message: 'فشل جلب إحصائيات الإجازات.' });

                const responseData = {
                    totalUsers: usersStats[0].totalUsers,
                    activeUsers: usersStats[0].activeUsers,
                    admins: usersStats[0].admins,
                    pendingLeaveRequests: pendingLeaveRequests[0].count,
                    usersByDepartment: usersByDepartment
                };

                res.status(200).json(responseData);
            });
        });
    });
};