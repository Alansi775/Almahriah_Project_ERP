// almahriah_backend/routes/adminRoutes.js
const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');

// جميع المسارات التالية تتطلب رمز وصول صالح
router.use(authMiddleware.verifyToken);

// مسارات إدارة المستخدمين (للمدير فقط)
router.post('/users', authMiddleware.verifyRole(['Admin']), adminController.createUser);
router.get('/users', authMiddleware.verifyRole(['Admin']), adminController.getUsers);
router.put('/users/:id/toggle-active', authMiddleware.verifyRole(['Admin']), adminController.toggleUserActiveStatus);
router.delete('/users/:id', authMiddleware.verifyRole(['Admin']), adminController.deleteUser);

// مسارات لوحة التحكم (للمدير والموارد البشرية)
router.get('/dashboard-stats', authMiddleware.verifyRole(['Admin', 'HR']), adminController.getDashboardStats);

// مسارات طلبات الإجازة
// هذا المسار متاح لجميع من لديهم رمز وصول صالح (وهو ما تحقق منه verifyToken)
router.post('/leave-requests', adminController.createLeaveRequest);
// المسارات التالية تتطلب صلاحيات محددة
router.get('/leave-requests/pending', authMiddleware.verifyRole(['Admin', 'HR']), adminController.getPendingLeaveRequests);
router.put('/leave-requests/update-status/:id', authMiddleware.verifyRole(['Admin', 'HR']), adminController.updateLeaveRequestStatus);

// Get all leave requests for a specific employee
router.get('/leave-requests/employee/:userId', authMiddleware.verifyToken, adminController.getEmployeeLeaveRequests);
router.delete('/leave-requests/all', authMiddleware.verifyRole(['Admin', 'HR']), adminController.deleteAllLeaveRequests);
router.delete('/leave-requests/:id', authMiddleware.verifyRole(['Admin', 'HR', 'News']), adminController.deleteLeaveRequest);
router.get('/leave-requests/all', authMiddleware.verifyRole(['Admin', 'HR']), adminController.getAllLeaveRequests); // this is for the HR to see all

router.get('/departments', authMiddleware.verifyRole(['Admin']), adminController.getUniqueDepartments);


module.exports = router;