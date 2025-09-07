// almahriah_backend/routes/taskRoutes.js

const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const auth = require('../middleware/authMiddleware');

// مسار لإنشاء مهمة جديدة (متاح للمدراء فقط)
router.post('/tasks', auth.verifyToken, auth.isManager, taskController.createTask);

// مسار لجلب جميع المهام (للمدير العام)
router.get('/tasks/all', auth.verifyToken, auth.verifyRole(['Admin']), taskController.getAllTasks);

// مسار لجلب المهام حسب القسم (متاح للمدراء والمدراء العامين)
router.get('/tasks/by-department', auth.verifyToken, auth.verifyRole(['Admin', 'Manager']), taskController.getTasksByDepartment);


// مسار لجلب المهام حسب المستخدم (متاح للموظفين)
router.get('/tasks/by-user', auth.verifyToken, auth.verifyRole(['Admin', 'Employee', 'News', 'HR']), taskController.getUserTasks);

// مسار لتحديث حالة المهمة (متاح لجميع المستخدمين)
router.put('/tasks/:id/status', auth.verifyToken, taskController.updateTaskStatus);

// مسار لجلب موظفي القسم (متاح للمدراء فقط)
router.get('/tasks/employees', auth.verifyToken, auth.isManager, taskController.getDepartmentEmployees);

// مسار لحذف جميع مهام القسم (متاح للمدراء فقط)
router.delete('/tasks/by-department', auth.verifyToken, auth.isManager, taskController.deleteAllDepartmentTasks);

// مسار لحذف مهمة فردية (متاح للمدراء فقط)
router.delete('/tasks/:id', auth.verifyToken, auth.isManager, taskController.deleteTask);

//  New route for filtering tasks by status managers only
router.get('/tasks/department', auth.verifyToken, auth.isManager, taskController.getDepartmentTasks);


module.exports = router;