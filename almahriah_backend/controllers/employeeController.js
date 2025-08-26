// almahriah_backend/controllers/employeeController.js (Create this file)
const db = require('../config/db');

exports.deleteOwnLeaveRequest = (req, res) => {
    const requestId = req.params.id;
    const userId = req.user.id; // Get the user ID from the auth token

    // Add a check to ensure the user can only delete their own request
    const query = 'DELETE FROM leave_requests WHERE id = ? AND userId = ?';
    db.query(query, [requestId, userId], (err, result) => {
        if (err) {
            console.error('Error deleting leave request:', err);
            return res.status(500).json({ message: 'Server error occurred while deleting the request.' });
        }

        if (result.affectedRows === 0) {
            // This means either the request wasn't found or it doesn't belong to the user
            return res.status(404).json({ message: 'Leave request not found or you do not have permission to delete it.' });
        }

        res.status(200).json({ message: 'Leave request deleted successfully.' });
    });
};