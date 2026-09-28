const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const Store = require('../models/Store');

// 1. ADD NEW PRODUCT FOR A STORE
router.post('/', async (req, res) => {
  try {
    const {
      storeId,
      title,
      category,
      unit,
      price,
      originalPrice,
      stock,
      isAvailable,
      image,
      description,
      brand,
      packOf,
      type,
      shelfLife,
      formFactor,
      origin,
      isSubsidized,
      subsidyLimit,
    } = req.body;

    if (!storeId || !title || price === undefined) {
      return res.status(400).json({
        error: 'Missing required fields: storeId, title, and price are mandatory',
      });
    }

    // Verify store exists
    const store = await Store.findOne({ storeId });
    if (!store) {
      return res.status(404).json({ error: `Store with ID ${storeId} not found` });
    }

    const productId = 'PROD_' + Math.floor(100000 + Math.random() * 900000);

    // Calculate discount percentage if originalPrice is higher
    let discountStr = '';
    const numericPrice = Number(price);
    const numericOrig = originalPrice ? Number(originalPrice) : 0;
    if (numericOrig > numericPrice && numericOrig > 0) {
      const discountVal = Math.round(((numericOrig - numericPrice) / numericOrig) * 100);
      discountStr = `${discountVal}% OFF`;
    }

    const newProduct = new Product({
      productId,
      storeId,
      title,
      category: category || store.category || 'general',
      unit: unit || '1 Units',
      price: numericPrice,
      originalPrice: numericOrig,
      discountPercentage: discountStr,
      stock: stock !== undefined ? Number(stock) : 10,
      isAvailable: isAvailable !== undefined ? Boolean(isAvailable) : true,
      image: image || '',
      description: description || '',
      brand: brand || 'Unbranded',
      packOf: packOf || '1',
      type: type || '',
      shelfLife: shelfLife || '7 Days',
      formFactor: formFactor || 'Whole',
      origin: origin || 'India',
      isSubsidized: Boolean(isSubsidized),
      subsidyLimit: subsidyLimit || '',
    });

    await newProduct.save();

    console.log(`📦 [Product Added] ${title} (${productId}) for Store: ${store.name} (${storeId})`);

    res.status(201).json({
      success: true,
      message: 'Product added successfully! 🎉',
      product: newProduct,
    });
  } catch (error) {
    console.error('Error adding product:', error);
    res.status(500).json({ error: 'Failed to add product', details: error.message });
  }
});

// 2. GET ALL PRODUCTS FOR A SPECIFIC STORE
router.get('/store/:storeId', async (req, res) => {
  try {
    const { storeId } = req.params;
    const products = await Product.find({ storeId }).sort({ createdAt: -1 });

    res.status(200).json({
      success: true,
      count: products.length,
      products,
    });
  } catch (error) {
    console.error('Error fetching store products:', error);
    res.status(500).json({ error: 'Failed to fetch store products' });
  }
});

// 3. GET SINGLE PRODUCT
router.get('/:productId', async (req, res) => {
  try {
    const { productId } = req.params;
    const product = await Product.findOne({ productId });
    if (!product) {
      return res.status(404).json({ error: 'Product not found' });
    }
    res.status(200).json({ success: true, product });
  } catch (error) {
    console.error('Error fetching product:', error);
    res.status(500).json({ error: 'Failed to fetch product' });
  }
});

// 4. UPDATE PRODUCT (OR TOGGLE STOCK/AVAILABILITY)
router.patch('/:productId', async (req, res) => {
  try {
    const { productId } = req.params;
    const updateData = { ...req.body };

    // Re-calculate discount if prices are updated
    if (updateData.price !== undefined || updateData.originalPrice !== undefined) {
      const existing = await Product.findOne({ productId });
      if (existing) {
        const p = updateData.price !== undefined ? Number(updateData.price) : existing.price;
        const op = updateData.originalPrice !== undefined ? Number(updateData.originalPrice) : existing.originalPrice;
        if (op > p && op > 0) {
          updateData.discountPercentage = `${Math.round(((op - p) / op) * 100)}% OFF`;
        } else {
          updateData.discountPercentage = '';
        }
      }
    }

    const updated = await Product.findOneAndUpdate(
      { productId },
      { $set: updateData },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ error: 'Product not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Product updated successfully!',
      product: updated,
    });
  } catch (error) {
    console.error('Error updating product:', error);
    res.status(500).json({ error: 'Failed to update product', details: error.message });
  }
});

// 5. DELETE PRODUCT
router.delete('/:productId', async (req, res) => {
  try {
    const { productId } = req.params;
    const deleted = await Product.findOneAndDelete({ productId });
    if (!deleted) {
      return res.status(404).json({ error: 'Product not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Product removed from store catalog',
    });
  } catch (error) {
    console.error('Error deleting product:', error);
    res.status(500).json({ error: 'Failed to delete product' });
  }
});

module.exports = router;
