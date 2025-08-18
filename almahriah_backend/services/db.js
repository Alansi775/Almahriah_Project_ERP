const mysql = require('mysql2');

const connection = mysql.createPool({
    host: 'localhost',
    user: 'Alansi77', // اسم مستخدم MySQL
    password: 'Alansi77@', // كلمة المرور
    database: 'almahriah_db' // اسم قاعدة البيانات
});

module.exports = connection;