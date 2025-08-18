// almahriah_backend/config/db.js
const mysql = require('mysql2'); // قم بتغيير هذا السطر

const db = mysql.createConnection({
    host: 'localhost',
    user: 'Alansi77',
    password: 'Alansi77@',
    database: 'almahriah_db'
});

db.connect(err => {
    if (err) {
        console.error('Database connection failed:', err.stack);
        return;
    }
    console.log('Successfully connected to database with ID:', db.threadId);
});

module.exports = db;