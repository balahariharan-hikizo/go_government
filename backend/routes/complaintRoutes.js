const express = require('express');
const router = express.Router();
const complaintController = require('../controllers/complaintController');

// 1. Stats & Complaints List
router.get('/meta/stats', complaintController.getStats);
router.get('/all', complaintController.getAllComplaints);
router.get('/:complaintId', complaintController.getComplaintById);
router.get('/user/:userId', complaintController.getUserComplaints);

// 2. Submit & Interactions
router.post('/create', complaintController.createComplaint);
router.post('/:complaintId/like', complaintController.toggleLike);
router.post('/:complaintId/comment', complaintController.addComment);

// 3. Status Transitions (Admin)
router.patch('/:complaintId/status', complaintController.updateStatus);

module.exports = router;
