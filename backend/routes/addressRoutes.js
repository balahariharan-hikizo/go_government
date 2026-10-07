const express = require('express');
const router = express.Router();
const addressController = require('../controllers/addressController');

// 1. Fetch User Addresses
router.get('/:userId', addressController.getAddresses);

// 2. Add Address
router.post('/create', addressController.createAddress);

// 3. Update Address
router.put('/update/:id', addressController.updateAddress);

// 4. Soft-Delete Address
router.delete('/delete/:id', addressController.deleteAddress);

module.exports = router;
