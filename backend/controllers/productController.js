const mongoose = require('mongoose');
const Product = require('../models/Product');
const Store = require('../models/Store');
const Category = require('../models/Category');
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
      categoryId: incomingCategoryId,
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

    const targetTitle = (req.body.title || req.body.name || '').toString().trim();
    const targetStock = req.body.stock !== undefined ? Number(req.body.stock) : (req.body.stockQuantity !== undefined ? Number(req.body.stockQuantity) : 0);

    const targetImage = image || (Array.isArray(images) && images.length > 0 ? images[0] : '');

    if (!storeId || !targetTitle || price === undefined || !targetImage) {
      return res.status(400).json({
        success: false, error: 'Missing required fields: storeId, title, price, and at least one product photo are mandatory',
     R });
    }

    const trimmedCatId = (incomingCategoryId || '').trim();
    const trimmedCatName = (category || '').trim();

    // Single parallel DB trip: validate store, lookup category doc, and generate sequence ID simultaneously
    const [store, catDoc, productId] = await Promise.all([
      Store.findOne({ storeId }).select('storeId category').lean(),
      trimmedCatId
        ? Category.findOne({ categoryId: trimmedCatId, isDeleted: { $ne: true } }).select('categoryId name ancestors').lean()
        : (trimmedCatName
            ? Category.findOne({
                storeId: { $in: [storeId, 'global'] },
                name: { $regex: new RegExp(`^${trimmedCatName}$`, 'i') },
                isDeleted: { $ne: true },
              }).select('categoryId name ancestors').lean()
            : null),
      getNextSequence('productId', 'PROD_', 5),
    ]);

    if (!store) {
      return res.status(404).json({ success: false, error: `Store with ID ${storeId} not found` });
    }

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
        const vUnit = v.unit || v.weight || '1 Units';
        const vStock = v.stock !== undefined ? Number(v.stock) : (v.stockQuantity !== undefined ? Number(v.stockQuantity) : targetStock);
        return {
          variantId: `${productId}_V${idx + 1}`,
          unit: vUnit,
          price: vPrice,
          originalPrice: vOrig,
          discountPercentage: calculateDiscount(vPrice, vOrig),
          stock: vStock,
          isAvailable: v.isAvailable !== undefined ? Boolean(v.isAvailable) : true,
          image: v.image || '',
        };
      });
    }

    // Category resolution from concurrent lookup
    let finalCategoryName = store.category || 'general';
    let finalCategoryId = '';
    let finalCategoryPath = [];

    if (catDoc) {
      finalCategoryName = catDoc.name;
      finalCategoryId = catDoc.categoryId;
      finalCategoryPath = [...(catDoc.ancestors || []), catDoc.categoryId];
    } else if (trimmedCatName) {
      finalCategoryName = trimmedCatName;
    }

    const newProduct = new Product({
      productId,
      storeId,
      title: targetTitle,
      category: finalCategoryName,
      categoryId: finalCategoryId,
      categoryPath: finalCategoryPath,
      unit: unit || (formattedVariants.length > 0 ? formattedVariants[0].unit : '1 Units'),
      price: numericPrice,
      originalPrice: numericOrig,
      discountPercentage: discountStr,
      stock: targetStock,
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
    res.status(500).json({ success: false, error: 'Failed to add product', details: error.message });
  }
};

// 2. GET ALL PRODUCTS FOR A STORE (Supports Pagination, hasMore, Category, CategoryId, Search)
exports.getProductsByStore = async (req, res) => {
  try {
    const { storeId } = req.params;
    const { category, categoryId, search } = req.query;

    const query = { storeId, isDeleted: { $ne: true } };

    // Support filtering by categoryId (matches exact leaf categoryId OR any child in categoryPath)
    if (categoryId && categoryId !== 'all') {
      query.$or = [
        { categoryId },
        { categoryPath: categoryId },
      ];
    } else {
      // Check if store has configured categories in Category master
      const allStoreCategories = await Category.find({
        storeId: { $in: [storeId, 'global'] },
        isDeleted: { $ne: true },
      }).select('name categoryId isActive').lean();

      if (allStoreCategories.length > 0) {
        const inactiveCats = allStoreCategories.filter((c) => c.isActive === false);
        const inactiveNames = inactiveCats.map((c) => new RegExp(`^${c.name.trim()}$`, 'i'));
        const inactiveIds = inactiveCats.map((c) => c.categoryId);

        if (category && category !== 'all') {
          const isRequestedInactive = inactiveCats.some(
            (c) => c.name.trim().toLowerCase() === category.trim().toLowerCase()
          );
          if (isRequestedInactive) {
            query._id = null; // Requested category is inactive, return empty
          } else {
            // Find all subcategories under this category name to include their products too!
            const matchedCat = allStoreCategories.find(
              (c) => c.name.trim().toLowerCase() === category.trim().toLowerCase()
            );
            if (matchedCat) {
              query.$or = [
                { category: new RegExp(`^${category}$`, 'i') },
                { categoryId: matchedCat.categoryId },
                { categoryPath: matchedCat.categoryId },
              ];
            } else {
              query.category = new RegExp(`^${category}$`, 'i');
            }
          }
        } else if (inactiveNames.length > 0) {
          // Exclude products that belong to explicitly disabled/inactive categories
          query.category = { $nin: inactiveNames };
          if (inactiveIds.length > 0) {
            query.categoryId = { $nin: inactiveIds };
            query.categoryPath = { $nin: inactiveIds };
          }
        }
      } else if (category && category !== 'all') {
        query.category = new RegExp(`^${category}$`, 'i');
      }
    }

    if (search && search.trim()) {
      query.$or = [
        { title: { $regex: search.trim(), $options: 'i' } },
        { brand: { $regex: search.trim(), $options: 'i' } },
      ];
    }

    let queryBuilder = Product.find(query).sort({ createdAt: -1 });

    const hasPagination = req.query.page !== undefined || req.query.limit !== undefined;
    const page = Math.max(1, parseInt(req.query.page, 10) || 1);
    const limit = req.query.limit !== undefined ? Math.max(1, parseInt(req.query.limit, 10)) : 0;

    if (hasPagination && limit > 0) {
      const skip = (page - 1) * limit;
      queryBuilder = queryBuilder.skip(skip).limit(limit);
    }

    // Single parallel DB trip: total count and product list fetched simultaneously with .lean()
    const [total, products] = await Promise.all([
      Product.countDocuments(query),
      queryBuilder.lean(),
    ]);
    const effectiveLimit = limit > 0 ? limit : (total || 1);
    const totalPages = limit > 0 ? Math.ceil(total / limit) : 1;
    const hasMore = limit > 0 ? page * limit < total : false;

    res.status(200).json({
      success: true,
      productCount: products.length,
      totalProducts: total,
      page: hasPagination ? page : 1,
      totalPages: hasPagination ? totalPages : 1,
      hasMore: hasPagination ? hasMore : false,
      products,
    });
  } catch (error) {
    console.error('Error fetching store products:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch store products' });
  }
};

// 3. GET SINGLE PRODUCT
exports.getProductById = async (req, res) => {
  try {
    const { productId } = req.params;
    const product = await Product.findOne({
      $or: [
        { productId },
        { _id: productId.match(/^[0-9a-fA-F]{24}$/) ? productId : null },
      ],
    });
    if (!product) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }
    res.status(200).json({ success: true, product });
  } catch (error) {
    console.error('Error fetching product:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch product' });
  }
};

// 4. UPDATE PRODUCT (OR TOGGLE STOCK/AVAILABILITY)
exports.updateProduct = async (req, res) => {
  try {
    const { productId } = req.params;
    const isObjectId = mongoose.Types.ObjectId.isValid(productId);
    const query = isObjectId ? { $or: [{ productId }, { _id: productId }] } : { productId };

    const updateData = { ...req.body };

    if (updateData.name && !updateData.title) {
      updateData.title = updateData.name;
    }
    if (updateData.stockQuantity !== undefined && updateData.stock === undefined) {
      updateData.stock = Number(updateData.stockQuantity);
    }

    // Discount calculation if prices provided
    if (updateData.price !== undefined && updateData.originalPrice !== undefined) {
      updateData.discountPercentage = calculateDiscount(updateData.price, updateData.originalPrice);
    }

    // Category and path synchronization if category changed
    if (updateData.categoryId || updateData.category) {
      let catDoc = null;
      if (updateData.categoryId) {
        catDoc = await Category.findOne({ categoryId: updateData.categoryId.trim(), isDeleted: { $ne: true } });
      }
      if (!catDoc && updateData.category) {
        catDoc = await Category.findOne({
          name: { $regex: new RegExp(`^${updateData.category.trim()}$`, 'i') },
          isDeleted: { $ne: true },
        });
      }
      if (catDoc) {
        updateData.categoryId = catDoc.categoryId;
        updateData.category = catDoc.name;
        updateData.categoryPath = [...(catDoc.ancestors || []), catDoc.categoryId];
      }
    }

    // Synchronize images if provided
    if (Array.isArray(updateData.images)) {
      updateData.images = updateData.images.map((img) => img.toString().trim()).filter(Boolean);
      if (updateData.images.length > 0 && !updateData.image) {
        updateData.image = updateData.images[0];
      }
    } else if (updateData.image) {
      updateData.images = [updateData.image];
    }

    // Reformat variants if provided
    if (Array.isArray(updateData.variants)) {
      updateData.hasVariants = updateData.variants.length > 0;
      updateData.variants = updateData.variants.map((v, idx) => {
        const vPrice = Number(v.price || updateData.price || 0);
        const vOrig = v.originalPrice !== undefined ? Number(v.originalPrice) : 0;
        const vUnit = v.unit || v.weight || '1 Units';
        const vStock = v.stock !== undefined ? Number(v.stock) : (v.stockQuantity !== undefined ? Number(v.stockQuantity) : 10);
        return {
          variantId: (v.variantId && v.variantId.includes('_V'))
            ? v.variantId
            : `${productId}_V${idx + 1}`,
          unit: vUnit,
          price: vPrice,
          originalPrice: vOrig,
          discountPercentage: calculateDiscount(vPrice, vOrig),
          stock: vStock,
          isAvailable: v.isAvailable !== undefined ? Boolean(v.isAvailable) : true,
          image: v.image || '',
        };
      });
    } else if (updateData.stock !== undefined) {
      // If stock is adjusted directly (via 1-tap quick adjuster) without sending variants array,
      // sync the primary variant's stock so variants array stays in 100% sync
      const existing = await Product.findOne(query).select('hasVariants variants').lean();
      if (existing && existing.hasVariants && Array.isArray(existing.variants) && existing.variants.length > 0) {
        updateData['variants.0.stock'] = updateData.stock;
        if (updateData.isAvailable !== undefined) {
          updateData['variants.0.isAvailable'] = updateData.isAvailable;
        }
      }
    }

    // Single Atomic DB Call: updates and returns the updated product
    const updated = await Product.findOneAndUpdate(
      query,
      { $set: updateData },
      { returnDocument: 'after', runValidators: true }
    );

    if (!updated) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Product updated successfully!',
      product: updated,
    });
  } catch (error) {
    console.error('Error updating product:', error);
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ success: false, error: 'Failed to update product', details: error.message });
  }
};

// 5. DELETE PRODUCT
exports.deleteProduct = async (req, res) => {
  try {
    const { productId } = req.params;
    const isObjectId = mongoose.Types.ObjectId.isValid(productId);
    const query = isObjectId ? { $or: [{ productId }, { _id: productId }] } : { productId };

    const deleted = await Product.findOneAndUpdate(
      query,
      { $set: { isDeleted: true, isAvailable: false, deletedAt: new Date() } },
      { returnDocument: 'after' }
    );
    if (!deleted) {
      return res.status(404).json({ success: false, error: 'Product not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Product removed from store catalog',
      productId: deleted.productId,
    });
  } catch (error) {
    console.error('Error deleting product:', error);
    res.status(500).json({ success: false, error: 'Failed to delete product' });
  }
};
