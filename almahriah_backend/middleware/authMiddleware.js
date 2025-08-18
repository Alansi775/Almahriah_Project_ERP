// almahriah_backend/middleware/authMiddleware.js
const jwt = require('jsonwebtoken');

// Middleware to verify the JWT token
exports.verifyToken = (req, res, next) => {
  const token = req.headers.authorization?.split(' ')[1];
  if (!token) {
    return res.status(403).json({ message: 'لا يوجد رمز وصول' });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(401).json({ message: 'رمز الوصول غير صالح.' });
  }
};

// Middleware to check user's role
exports.verifyRole = (roles) => {
  return (req, res, next) => {
    if (!req.user || !roles.includes(req.user.role)) {
      return res.status(403).json({ message: 'لا تملك الصلاحية للوصول إلى هذا المسار.' });
    }
    next();
  };
};

// New Middleware for specific roles
exports.isManager = (req, res, next) => {
  if (req.user && req.user.role === 'Manager') {
    next();
  } else {
    res.status(403).json({ message: 'الوصول مقتصر على المدراء فقط.' });
  }
};

exports.isEmployee = (req, res, next) => {
  if (req.user && ['Employee', 'News'].includes(req.user.role)) {
    next();
  } else {
    res.status(403).json({ message: 'الوصول مقتصر على الموظفين فقط.' });
  }
};