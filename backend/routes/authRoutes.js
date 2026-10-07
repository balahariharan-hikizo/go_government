const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');

// 1. Citizen OTP Auth
router.post('/send-otp', userController.sendOtp);
router.post('/verify-otp', userController.verifyOtp);

// 2. Profile Management
router.get('/profile/:userId', userController.getProfile);
router.put('/update-profile', userController.updateProfile);

// 3. Registered Phone Update
router.post('/send-phone-update-otp', userController.sendPhoneUpdateOtp);
router.post('/verify-phone-update-otp', userController.verifyPhoneUpdateOtp);

// 4. Notifications & Session
router.post('/update-fcm-token', userController.updateFcmToken);
router.post('/logout', userController.logout);

module.exports = router;
