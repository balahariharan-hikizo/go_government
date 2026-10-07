const express = require('express');
const router = express.Router();
const cartController = require('../controllers/cartController');

// 1. Fetch Cart
router.get('/:userId', cartController.getCart);

// 2. Add / Update Quantity
router.post('/add', cartController.addToCart);
router.put('/update', cartController.updateQuantity);

// 3. Remove / Clear
router.delete('/:userId/item/:productId', cartController.removeItem);
router.delete('/:userId/clear', cartController.clearCart);

// 4. Bulk Sync
router.post('/:userId/sync', cartController.syncCart);

module.exports = router;
