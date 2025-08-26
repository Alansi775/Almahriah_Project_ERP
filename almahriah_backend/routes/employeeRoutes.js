// almahriah_backend/routes/employeeRoutes.js (Example)
const express = require('express');
const router = express.Router();
const { verifyToken } = require('../middleware/authMiddleware');
const employeeController = require('../controllers/employeeController');

console.log('Is employeeController an object?', typeof employeeController);
console.log('Does deleteOwnLeaveRequest exist?', typeof employeeController.deleteOwnLeaveRequest);

router.delete('/leave-requests/:id', verifyToken, employeeController.deleteOwnLeaveRequest);

module.exports = router;