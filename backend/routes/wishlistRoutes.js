const express = require('express');
const router = express.Router();
const wishlistController = require('../controllers/wishlistController');

// 1. Fetch Wishlist
router.get('/:userId', wishlistController.getWishlist);

// 2. Toggle Favorite
router.post('/toggle', wishlistController.toggleWishlist);

// 3. Remove Item
router.delete('/:userId/item/:productId', wishlistController.removeItem);

// 4. Bulk Sync
router.post('/:userId/sync', wishlistController.syncWishlist);

module.exports = router;
