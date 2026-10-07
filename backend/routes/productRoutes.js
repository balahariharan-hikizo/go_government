const express = require('express');
const router = express.Router();
const productController = require('../controllers/productController');

// 1. Create Product
router.post('/create', productController.createProduct);

// 2. Fetch Store Catalog & Single Product
router.get('/store/:storeId', productController.getProductsByStore);
router.get('/:productId', productController.getProductById);

// 3. Update & Delete
router.patch('/:productId', productController.updateProduct);
router.delete('/:productId', productController.deleteProduct);

module.exports = router;
