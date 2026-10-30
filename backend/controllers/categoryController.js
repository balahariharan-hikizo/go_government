const mongoose = require('mongoose');
const Category = require('../models/Category');
const Product = require('../models/Product');
const { getNextSequence } = require('../utils/sequenceGenerator');

// 1. CREATE CATEGORY (Supports infinite nested sub-categories)
exports.createCategory = async (req, res) => {
  try {
    const { storeId, name, description, icon, image, displayOrder, parentCategoryId } = req.body;

    if (!storeId || !name || !name.trim()) {
      return res.status(400).json({
        success: false,
        error: 'storeId and name are required',
      });
    }

    const trimmedName = name.trim();
    const cleanParentId = (parentCategoryId || '').trim();

    // Single parallel DB trip: check duplicate, fetch parent (if sub-category), and generate next sequence
    const [existing, parent, categoryId] = await Promise.all([
      Category.findOne({
        storeId,
        parentCategoryId: cleanParentId,
        name: { $regex: new RegExp(`^${trimmedName}$`, 'i') },
        isDeleted: { $ne: true },
      }).select('categoryId name').lean(),
      cleanParentId
        ? Category.findOne({ categoryId: cleanParentId, isDeleted: { $ne: true } }).select('categoryId level ancestors').lean()
        : null,
      getNextSequence('categoryId', 'CAT_', 5),
    ]);

    if (existing) {
      return res.status(400).json({
        success: false,
        error: `Category '${trimmedName}' already exists under this section`,
      });
    }

    // Determine level and ancestors from parent
    let level = 0;
    let ancestors = [];

    if (cleanParentId) {
      if (!parent) {
        return res.status(404).json({
          success: false,
          error: 'Parent category not found',
        });
      }

      level = (parent.level || 0) + 1;
      ancestors = [...(parent.ancestors || []), parent.categoryId];
    }

    const newCategory = new Category({
      categoryId,
      storeId,
      parentCategoryId: cleanParentId,
      level,
      ancestors,
      name: trimmedName,
      description: description ? description.trim() : '',
      icon: icon || '',
      image: image || '',
      displayOrder: displayOrder !== undefined ? Number(displayOrder) : 0,
      isActive: req.body.isActive !== undefined ? Boolean(req.body.isActive) : true,
      isDeleted: false,
    });

    await newCategory.save();

    console.log(`🏷️ [Category Created] ${trimmedName} (${categoryId}) Level: ${level} Parent: ${cleanParentId || 'ROOT'} for store ${storeId}`);

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

// 2. GET ALL CATEGORIES FOR A STORE (Single parallel DB trip, Lean & in-memory aggregation)
exports.getCategoriesByStore = async (req, res) => {
  try {
    const { storeId } = req.params;
    const { parentCategoryId, level } = req.query;

    if (!storeId) {
      return res.status(400).json({ success: false, error: 'storeId is required' });
    }

    const activeFilter = (req.query.activeOnly === 'true' || req.query.isActive === 'true')
      ? { isActive: true }
      : {};

    // Single parallel DB trip: fetch all categories for store AND aggregate product counts simultaneously
    const [allCategories, productCounts] = await Promise.all([
      Category.find({
        storeId: { $in: [storeId, 'global'] },
        isDeleted: { $ne: true },
        ...activeFilter,
      })
        .sort({ displayOrder: 1, createdAt: 1 })
        .lean(),

      Product.aggregate([
        {
          $match: {
            storeId,
            isDeleted: { $ne: true },
          },
        },
        {
          $group: {
            _id: {
              catName: { $toLower: '$category' },
              catId: '$categoryId',
            },
            count: { $sum: 1 },
          },
        },
      ]),
    ]);

    // Fast O(1) product count lookups
    const countMap = Object.create(null);
    for (let i = 0; i < productCounts.length; i++) {
      const item = productCounts[i];
      if (item._id.catName) countMap[item._id.catName] = (countMap[item._id.catName] || 0) + item.count;
      if (item._id.catId) countMap[item._id.catId] = (countMap[item._id.catId] || 0) + item.count;
    }

    // Direct in-memory subcategory count mapping (zero extra DB calls)
    const subCategoryCountMap = Object.create(null);
    for (let i = 0; i < allCategories.length; i++) {
      const parentId = allCategories[i].parentCategoryId;
      if (parentId) {
        subCategoryCountMap[parentId] = (subCategoryCountMap[parentId] || 0) + 1;
      }
    }

    // In-memory level/parentCategoryId filtering if requested
    let resultCategories = allCategories;
    if (parentCategoryId !== undefined) {
      resultCategories = resultCategories.filter((c) => (c.parentCategoryId || '') === parentCategoryId);
    }
    if (level !== undefined && !isNaN(Number(level))) {
      const targetLevel = Number(level);
      resultCategories = resultCategories.filter((c) => (c.level || 0) === targetLevel);
    }

    const categoriesWithCount = new Array(resultCategories.length);
    for (let i = 0; i < resultCategories.length; i++) {
      const cat = resultCategories[i];
      const catKey = (cat.name || '').toLowerCase();
      const subCount = subCategoryCountMap[cat.categoryId] || 0;

      categoriesWithCount[i] = {
        ...cat,
        productCount: countMap[cat.categoryId] || countMap[catKey] || 0,
        subCategoryCount: subCount,
        hasChildren: subCount > 0,
      };
    }

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

// 5. SOFT DELETE CATEGORY (Single atomic DB update)
exports.deleteCategory = async (req, res) => {
  try {
    const { categoryId } = req.params;

    const deleted = await Category.findOneAndUpdate(
      { categoryId, isDeleted: { $ne: true } },
      {
        $set: {
          isDeleted: true,
          isActive: false,
          deletedAt: new Date(),
        },
      },
      { returnDocument: 'after' }
    ).lean();

    if (!deleted) {
      return res.status(404).json({ success: false, error: 'Category not found' });
    }

    console.log(`🗑️ [Category Soft-Deleted] ${deleted.name} (${categoryId})`);

    res.status(200).json({
      success: true,
      message: `Category '${deleted.name}' deleted successfully (soft delete)`,
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

