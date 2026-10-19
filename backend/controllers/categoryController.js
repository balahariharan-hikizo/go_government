const mongoose = require('mongoose');
const Category = require('../models/Category');
const Product = require('../models/Product');
const { getNextSequence } = require('../utils/sequenceGenerator');

// 1. CREATE CATEGORY
exports.createCategory = async (req, res) => {
  try {
    const { storeId, name, description, icon, image, displayOrder } = req.body;

    if (!storeId || !name || !name.trim()) {
      return res.status(400).json({
        success: false,
        error: 'storeId and name are required',
      });
    }

    const trimmedName = name.trim();

    // Check if category with same name already exists for this store (case-insensitive) and not deleted
    const existing = await Category.findOne({
      storeId,
      name: { $regex: new RegExp(`^${trimmedName}$`, 'i') },
      isDeleted: { $ne: true },
    });

    if (existing) {
      return res.status(400).json({
        success: false,
        error: `Category '${trimmedName}' already exists for this store`,
      });
    }

    const categoryId = await getNextSequence('categoryId', 'CAT_', 5);

    const newCategory = new Category({
      categoryId,
      storeId,
      name: trimmedName,
      description: description ? description.trim() : '',
      icon: icon || '',
      image: image || '',
      displayOrder: displayOrder !== undefined ? Number(displayOrder) : 0,
      isActive: req.body.isActive !== undefined ? Boolean(req.body.isActive) : true,
      isDeleted: false,
    });

    await newCategory.save();

    console.log(`🏷️ [Category Created] ${trimmedName} (${categoryId}) for store ${storeId}`);

    res.status(201).json({
      success: true,
      message: 'Category created successfully! 🎉',
      category: newCategory,
    });
  } catch (error) {
    console.error('Error creating category:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to create category',
      details: error.message,
    });
  }
};

// 2. GET ALL CATEGORIES FOR A STORE (Includes product count per category)
exports.getCategoriesByStore = async (req, res) => {
  try {
    const { storeId } = req.params;

    if (!storeId) {
      return res.status(400).json({ success: false, error: 'storeId is required' });
    }

    // Query non-deleted categories for this store or global
    const filter = {
      storeId: { $in: [storeId, 'global'] },
      isDeleted: { $ne: true },
    };

    if (req.query.activeOnly === 'true' || req.query.isActive === 'true') {
      filter.isActive = true;
    }

    const categories = await Category.find(filter).sort({ displayOrder: 1, createdAt: 1 });

    // Aggregate product counts per category for this store
    const productCounts = await Product.aggregate([
      {
        $match: {
          storeId,
          isDeleted: { $ne: true },
        },
      },
      {
        $group: {
          _id: { $toLower: '$category' },
          count: { $sum: 1 },
        },
      },
    ]);

    const countMap = {};
    for (const item of productCounts) {
      if (item._id) countMap[item._id] = item.count;
    }

    const categoriesWithCount = categories.map((cat) => {
      const json = cat.toJSON();
      const catKey = (cat.name || '').toLowerCase();
      json.productCount = countMap[catKey] || 0;
      return json;
    });

    res.status(200).json({
      success: true,
      count: categoriesWithCount.length,
      categories: categoriesWithCount,
    });
  } catch (error) {
    console.error('Error fetching categories:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to fetch categories',
      details: error.message,
    });
  }
};

// 3. GET SINGLE CATEGORY
exports.getCategoryById = async (req, res) => {
  try {
    const { categoryId } = req.params;
    const category = await Category.findOne({
      categoryId,
      isDeleted: { $ne: true },
    });

    if (!category) {
      return res.status(404).json({ success: false, error: 'Category not found' });
    }

    res.status(200).json({ success: true, category });
  } catch (error) {
    console.error('Error fetching category:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch category', details: error.message });
  }
};

// 4. UPDATE CATEGORY (Syncs product category name if changed)
exports.updateCategory = async (req, res) => {
  try {
    const { categoryId } = req.params;
    const { name, description, icon, image, displayOrder, isActive } = req.body;

    const existing = await Category.findOne({
      categoryId,
      isDeleted: { $ne: true },
    });

    if (!existing) {
      return res.status(404).json({ success: false, error: 'Category not found' });
    }

    const oldName = existing.name;
    const newName = name ? name.trim() : oldName;

    // If name is changing, check duplicate
    if (newName.toLowerCase() !== oldName.toLowerCase()) {
      const duplicate = await Category.findOne({
        storeId: existing.storeId,
        name: { $regex: new RegExp(`^${newName}$`, 'i') },
        categoryId: { $ne: categoryId },
        isDeleted: { $ne: true },
      });
      if (duplicate) {
        return res.status(400).json({
          success: false,
          error: `Another category named '${newName}' already exists`,
        });
      }
    }

    existing.name = newName;
    if (description !== undefined) existing.description = description.trim();
    if (icon !== undefined) existing.icon = icon;
    if (image !== undefined) existing.image = image;
    if (displayOrder !== undefined) existing.displayOrder = Number(displayOrder);
    if (isActive !== undefined) existing.isActive = Boolean(isActive);

    await existing.save();

    // If category name was renamed, update all products in this store
    if (newName.toLowerCase() !== oldName.toLowerCase()) {
      await Product.updateMany(
        {
          storeId: existing.storeId,
          category: { $regex: new RegExp(`^${oldName}$`, 'i') },
        },
        { $set: { category: newName } }
      );
      console.log(`🔄 [Category Renamed] Renamed products from '${oldName}' to '${newName}' for store ${existing.storeId}`);
    }

    res.status(200).json({
      success: true,
      message: 'Category updated successfully! ✨',
      category: existing,
    });
  } catch (error) {
    console.error('Error updating category:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to update category',
      details: error.message,
    });
  }
};

// 5. SOFT DELETE CATEGORY (Soft delete only!)
exports.deleteCategory = async (req, res) => {
  try {
    const { categoryId } = req.params;

    const existing = await Category.findOne({
      categoryId,
      isDeleted: { $ne: true },
    });

    if (!existing) {
      return res.status(404).json({ success: false, error: 'Category not found' });
    }

    // Soft delete
    existing.isDeleted = true;
    existing.isActive = false;
    existing.deletedAt = new Date();
    await existing.save();

    console.log(`🗑️ [Category Soft-Deleted] ${existing.name} (${categoryId})`);

    res.status(200).json({
      success: true,
      message: `Category '${existing.name}' deleted successfully (soft delete)`,
      categoryId,
    });
  } catch (error) {
    console.error('Error soft-deleting category:', error);
    res.status(500).json({
      success: false,
      error: 'Failed to delete category',
      details: error.message,
    });
  }
};

