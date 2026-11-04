const express = require('express');
const router = express.Router();
const adminAuthController = require('../controllers/adminAuthController');
const { adminAuthMiddleware } = require('../middleware/adminAuth');

// 1. Public Route: Admin Login
router.post('/login', adminAuthController.login);

// 2. Protected Routes: Current Admin Profile & Verification
router.get('/me', adminAuthMiddleware, adminAuthController.getProfile);

// 3. Protected Routes: Admin Management
router.post('/create-admin', adminAuthMiddleware, adminAuthController.createAdmin);
router.get('/list', adminAuthMiddleware, adminAuthController.listAdmins);
router.patch('/reset-officer-password', adminAuthMiddleware, adminAuthController.resetOfficerPassword);
router.patch('/change-my-password', adminAuthMiddleware, adminAuthController.changeMyPassword);

module.exports = router;

