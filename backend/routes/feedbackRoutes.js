const express = require('express');
const router = express.Router();
const feedbackController = require('../controllers/feedbackController');

// 1. Submit Feedback / Survey
router.post('/create', feedbackController.submitFeedback);

// 2. Query Feedbacks & KPIs
router.get('/all', feedbackController.getAllFeedback);
router.get('/stats', feedbackController.getStats);

module.exports = router;
