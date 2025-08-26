// almahriah_backend/routes/adminRoutes.js

const express = require('express');
const router = express.Router();
const adminController = require('../controllers/adminController');
const authMiddleware = require('../middleware/authMiddleware');

// All routes below this line require a valid token
router.use(authMiddleware.verifyToken);

// User Management Routes (Admin only)
router.post('/users', authMiddleware.verifyRole(['Admin']), adminController.createUser);
router.get('/users', authMiddleware.verifyRole(['Admin']), adminController.getUsers);
router.put('/users/:id/toggle-active', authMiddleware.verifyRole(['Admin']), adminController.toggleUserActiveStatus);
router.delete('/users/:id', authMiddleware.verifyRole(['Admin']), adminController.deleteUser);

// Dashboard Routes (Admin and HR)
router.get('/dashboard-stats', authMiddleware.verifyRole(['Admin', 'HR']), adminController.getDashboardStats);

// Leave Request Routes
router.post('/leave-requests', adminController.createLeaveRequest); // this is a special case, it might need to verify the user not a specific role
router.get('/leave-requests/pending', authMiddleware.verifyRole(['Admin', 'HR']), adminController.getPendingLeaveRequests);
router.put('/leave-requests/update-status/:id', authMiddleware.verifyRole(['Admin', 'HR']), adminController.updateLeaveRequestStatus);

// Get all leave requests for a specific employee
router.get('/leave-requests/employee/:userId', adminController.getEmployeeLeaveRequests);
router.delete('/leave-requests/all', authMiddleware.verifyRole(['Admin', 'HR']), adminController.deleteAllLeaveRequests);
// `News` role is likely a typo, I've removed it for clarity
router.delete('/leave-requests/:id', authMiddleware.verifyRole(['Admin', 'HR']), adminController.deleteLeaveRequest);
router.get('/leave-requests/all', authMiddleware.verifyRole(['Admin', 'HR']), adminController.getAllLeaveRequests);

// Department Routes (Admin only)
router.get('/departments', authMiddleware.verifyRole(['Admin']), adminController.getUniqueDepartments);

// ✅ Manager Leave Requests
router.get('/manager/leave-requests/pending', authMiddleware.verifyRole(['Manager']), adminController.getManagerPendingLeaveRequests);

module.exports = router;