const express = require('express');
const router = express.Router();
const riderController = require('../controllers/riderController');

// 1. Auth: Send & Verify OTP
router.post('/auth/send-otp', riderController.sendOtp);
router.post('/auth/verify-otp', riderController.verifyOtp);

// 2. Profile Management
router.get('/profile/:riderId', riderController.getProfile);
router.put('/update-profile', riderController.updateProfile);

// 3. Online/Offline Duty & Live GPS
router.patch('/status', riderController.toggleOnline);
router.post('/location', riderController.updateLocation);

// 4. FCM Notifications Token & Session
router.post('/update-fcm-token', riderController.updateFcmToken);
router.post('/logout', riderController.logout);

module.exports = router;
