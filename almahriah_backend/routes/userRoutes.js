const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');

// مسار إضافة مستخدم جديد
router.post('/add', userController.addUser);

// مسار لإدارة المستخدمين (مثلاً: حظر مستخدم)
router.post('/block', userController.blockUser);

module.exports = router;