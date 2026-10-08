const Product = require('../models/Product');
const Store = require('../models/Store');
const { getNextSequence } = require('../utils/sequenceGenerator');

// Helper to compute discount badge string
function calculateDiscount(price, originalPrice) {
  const p = Number(price || 0);
  const op = originalPrice ? Number(originalPrice) : 0;
  if (op > p && op > 0) {
    const val = Math.round(((op - p) / op) * 100);
    return `${val}% OFF`;
  }
  return '';
}

// 1. ADD NEW PRODUCT FOR A STORE
exports.createProduct = async (req, res) => {
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
      images,
      hasVariants,
      variants,
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

    const store = await Store.findOne({ storeId });
    if (!store) {
      return res.status(404).json({ error: `Store with ID ${storeId} not found` });
    }

    const productId = await getNextSequence('productId', 'PROD_', 5);

    const numericPrice = Number(price);
    const numericOrig = originalPrice ? Number(originalPrice) : 0;
    const discountStr = calculateDiscount(numericPrice, numericOrig);

    // Normalize images array
    let imagesList = [];
    if (Array.isArray(images) && images.length > 0) {
      imagesList = images.map((img) => img.toString().trim()).filter(Boolean);
    } else if (image) {
      imagesList = [image.toString().trim()];
    }
    const primaryImage = image || (imagesList.length > 0 ? imagesList[0] : '');

    // Format variants if provided
    let formattedVariants = [];
    let isVariantProduct = Boolean(hasVariants);

    if (Array.isArray(variants) && variants.length > 0) {
      isVariantProduct = true;
      formattedVariants = variants.map((v, idx) => {
        const vPrice = Number(v.price || numericPrice);
        const vOrig = v.originalPrice !== undefined ? Number(v.originalPrice) : 0;
        return {
          variantId: `${productId}_V${idx + 1}`,
          unit: v.unit || '1 Units',
          price: vPrice,
          originalPrice: vOrig,
          discountPercentage: calculateDiscount(vPrice, vOrig),
          stock: v.stock !== undefined ? Number(v.stock) : (stock !== undefined ? Number(stock) : 10),
          isAvailable: v.isAvailable !== undefined ? Boolean(v.isAvailable) : true,
          image: v.image || '',
        };
      });
    }

    const newProduct = new Product({
      productId,
      storeId,
      title,
      category: category || store.category || 'general',
      unit: unit || (formattedVariants.length > 0 ? formattedVariants[0].unit : '1 Units'),
      price: numericPrice,
      originalPrice: numericOrig,
      discountPercentage: discountStr,
      stock: stock !== undefined ? Number(stock) : 10,
      isAvailable: isAvailable !== undefined ? Boolean(isAvailable) : true,
      image: primaryImage,
      images: imagesList,
      hasVariants: isVariantProduct,
      variants: formattedVariants,
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

    console.log(`📦 [Product Added] ${title} (${productId}) - Variants: ${formattedVariants.length}, Images: ${imagesList.length}`);

    res.status(201).json({
      success: true,
      message: 'Product added successfully! 🎉',
      product: newProduct,
    });
  } catch (error) {
    console.error('Error adding product:', error);
    res.status(500).json({ error: 'Failed to add product', details: error.message });
  }
};

// 2. GET ALL PRODUCTS FOR A STORE
exports.getProductsByStore = async (req, res) => {
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
};

// 3. GET SINGLE PRODUCT
exports.getProductById = async (req, res) => {
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
};

// 4. UPDATE PRODUCT (OR TOGGLE STOCK/AVAILABILITY)
exports.updateProduct = async (req, res) => {
  try {
    const { productId } = req.params;
    const updateData = { ...req.body };

    const existing = await Product.findOne({ productId });
    if (!existing) {
      return res.status(404).json({ error: 'Product not found' });
    }

    // Discount re-calculation if price changed
    if (updateData.price !== undefined || updateData.originalPrice !== undefined) {
      const p = updateData.price !== undefined ? Number(updateData.price) : existing.price;
      const op = updateData.originalPrice !== undefined ? Number(updateData.originalPrice) : existing.originalPrice;
      updateData.discountPercentage = calculateDiscount(p, op);
    }

    // Synchronize images
    if (Array.isArray(updateData.images)) {
      updateData.images = updateData.images.map((img) => img.toString().trim()).filter(Boolean);
      if (updateData.images.length > 0 && !updateData.image) {
        updateData.image = updateData.images[0];
      }
    } else if (updateData.image && (!existing.images || existing.images.length === 0)) {
      updateData.images = [updateData.image];
    }

    // Reformat variants if passed
    if (Array.isArray(updateData.variants)) {
      updateData.hasVariants = updateData.variants.length > 0;
      updateData.variants = updateData.variants.map((v, idx) => {
        const vPrice = Number(v.price || updateData.price || existing.price);
        const vOrig = v.originalPrice !== undefined ? Number(v.originalPrice) : 0;
        return {
          variantId: (v.variantId && v.variantId.startsWith(`${productId}_V`))
            ? v.variantId
            : `${productId}_V${idx + 1}`,
          unit: v.unit || '1 Units',
          price: vPrice,
          originalPrice: vOrig,
          discountPercentage: calculateDiscount(vPrice, vOrig),
          stock: v.stock !== undefined ? Number(v.stock) : 10,
          isAvailable: v.isAvailable !== undefined ? Boolean(v.isAvailable) : true,
          image: v.image || '',
        };
      });
    }

    const updated = await Product.findOneAndUpdate(
      { productId },
      { $set: updateData },
      { new: true, runValidators: true }
    );

    res.status(200).json({
      success: true,
      message: 'Product updated successfully!',
      product: updated,
    });
  } catch (error) {
    console.error('Error updating product:', error);
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ error: 'Failed to update product', details: error.message });
  }
};

// 5. DELETE PRODUCT
exports.deleteProduct = async (req, res) => {
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
};
