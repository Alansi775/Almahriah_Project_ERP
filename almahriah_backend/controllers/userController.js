// هذا الكود مجرد نموذج مبدئي
exports.addUser = (req, res) => {
    // هنا ستتم عملية إضافة مستخدم جديد إلى قاعدة البيانات
    res.status(201).json({ message: 'User added successfully' });
};

exports.blockUser = (req, res) => {
    // هنا ستتم عملية حظر مستخدم
    res.status(200).json({ message: 'User blocked successfully' });
};