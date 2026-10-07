const express = require('express');
const router = express.Router();
const storeController = require('../controllers/storeController');

// 1. Store Auth: Send & Verify OTP
router.post('/auth/send-otp', storeController.sendOtp);
router.post('/auth/verify-otp', storeController.verifyOtp);

// 2. Store Registration & Fetch Profile
router.post('/register', storeController.registerStore);
router.get('/my-store/:identifier', storeController.getMyStore);

// 3. Store Listings (Citizen Discovery & Admin Review)
router.get('/approved', storeController.getApprovedStores);
router.get('/pending', storeController.getPendingStores);
router.get('/all', storeController.getAllStores);
router.get('/:storeId', storeController.getStoreById);

// 4. Operations & Updates
router.patch('/:storeId/online', storeController.toggleOnline);
router.patch('/:storeId/status', storeController.reviewStore);
router.put('/:storeId/update-profile', storeController.updateProfile);
router.post('/update-fcm-token', storeController.updateFcmToken);

module.exports = router;
