const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware'); // new


// مسار تسجيل الدخول
router.post('/login', authController.login);
router.post('/logout', authController.logout);

// مسارات QR Code الجديدة
router.post('/generate-qr-token', authMiddleware.verifyToken, authController.generateQrToken);
router.post('/login-with-qr', authController.loginWithQr);

//  المسار الجديد لتوليد رمز QR مؤقت (لا يتطلب توثيق)
router.post('/generate-temp-qr', authController.generateTempQr);

//  المسار الجديد لربط الجلسة (يتطلب توثيق من الهاتف)
router.post('/link-qr-session', authMiddleware.verifyToken, authController.linkQrSession);

//  المسار الجديد للتحقق من حالة الـ QR
router.get('/check-qr-session', authController.checkQrSession);

//  مسار جديد لتسجيل الدخول مباشرةً من رمز QR
router.post('/qr-login', authController.qrLogin);



module.exports = router;