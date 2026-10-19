const express = require('express');
const router = express.Router();
const categoryController = require('../controllers/categoryController');

// 1. Create Category
router.post('/create', categoryController.createCategory);

// 2. Fetch Categories by Store & Single Category
router.get('/store/:storeId', categoryController.getCategoriesByStore);
router.get('/:categoryId', categoryController.getCategoryById);

// 3. Update Category (supports PUT and PATCH)
router.put('/:categoryId', categoryController.updateCategory);
router.patch('/:categoryId', categoryController.updateCategory);

// 4. Soft Delete Category
router.delete('/:categoryId', categoryController.deleteCategory);

module.exports = router;
