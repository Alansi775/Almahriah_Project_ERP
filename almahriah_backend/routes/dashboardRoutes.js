// almahriah_backend/routes/dashboardRoutes.js

const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const auth = require('../middleware/authMiddleware');

// قم بتغيير السطر الأول
router.get('/manager/dashboard-stats', auth.verifyToken, auth.isManager, dashboardController.getManagerDashboardStats);

// وقم بتغيير السطر الثاني
//  قم بتبديل دالة "auth.isAdmin" بدالة "auth.isManager" مؤقتًا للتأكد من أنها تعمل
router.get('/admin/dashboard-stats', auth.verifyToken, auth.isManager, dashboardController.getAdminDashboardStats);

module.exports = router;