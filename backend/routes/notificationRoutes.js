const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');

// GET all notifications for a user
router.get('/user/:userId', notificationController.getNotificationsByUser);

// PATCH mark single notification as read
router.patch('/:id/read', notificationController.markAsRead);

// PATCH mark all notifications for a user as read
router.patch('/user/:userId/read-all', notificationController.markAllAsRead);

module.exports = router;
