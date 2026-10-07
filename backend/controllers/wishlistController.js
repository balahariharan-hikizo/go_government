const Wishlist = require('../models/Wishlist');

// 1. GET User Wishlist
exports.getWishlist = async (req, res) => {
  try {
    const { userId } = req.params;
    if (!userId) {
      return res.status(400).json({ success: false, message: 'userId is required' });
    }

    let wishlist = await Wishlist.findOne({ userId });
    if (!wishlist) {
      wishlist = await Wishlist.create({ userId, items: [] });
    }

    const favoriteIds = wishlist.items.map((item) => item.productId);

    return res.status(200).json({
      success: true,
      data: {
        userId: wishlist.userId,
        items: wishlist.items,
        favoriteIds,
        totalCount: wishlist.items.length,
      },
    });
  } catch (error) {
    console.error('Error fetching wishlist:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch wishlist', error: error.message });
  }
};

// 2. TOGGLE Item in Wishlist (Add if not present, Remove if present)
exports.toggleWishlist = async (req, res) => {
  try {
    const { userId, productId, product = {} } = req.body;
    if (!userId || !productId) {
      return res.status(400).json({ success: false, message: 'userId and productId are required' });
    }

    let wishlist = await Wishlist.findOne({ userId });
    if (!wishlist) {
      wishlist = new Wishlist({ userId, items: [] });
    }

    const itemIndex = wishlist.items.findIndex((item) => item.productId === productId.toString());
    let isFavorite = false;

    if (itemIndex > -1) {
      wishlist.items.splice(itemIndex, 1);
      isFavorite = false;
    } else {
      wishlist.items.push({
        productId: productId.toString(),
        product: { ...product, id: productId },
        addedAt: new Date(),
      });
      isFavorite = true;
    }

    await wishlist.save();
    const favoriteIds = wishlist.items.map((item) => item.productId);

    return res.status(200).json({
      success: true,
      message: isFavorite ? 'Added to wishlist' : 'Removed from wishlist',
      data: {
        isFavorite,
        productId: productId.toString(),
        favoriteIds,
        items: wishlist.items,
        totalCount: wishlist.items.length,
      },
    });
  } catch (error) {
    console.error('Error toggling wishlist:', error);
    return res.status(500).json({ success: false, message: 'Failed to toggle wishlist item', error: error.message });
  }
};

// 3. REMOVE Item from Wishlist
exports.removeItem = async (req, res) => {
  try {
    const { userId, productId } = req.params;
    if (!userId || !productId) {
      return res.status(400).json({ success: false, message: 'userId and productId are required' });
    }

    const wishlist = await Wishlist.findOne({ userId });
    if (!wishlist) {
      return res.status(200).json({
        success: true,
        message: 'Wishlist is already empty',
        data: { userId, items: [], favoriteIds: [], totalCount: 0 },
      });
    }

    wishlist.items = wishlist.items.filter((item) => item.productId !== productId.toString());
    await wishlist.save();

    const favoriteIds = wishlist.items.map((item) => item.productId);

    return res.status(200).json({
      success: true,
      message: 'Item removed from wishlist',
      data: {
        userId: wishlist.userId,
        items: wishlist.items,
        favoriteIds,
        totalCount: wishlist.items.length,
      },
    });
  } catch (error) {
    console.error('Error removing from wishlist:', error);
    return res.status(500).json({ success: false, message: 'Failed to remove from wishlist', error: error.message });
  }
};

// 4. SYNC Full Wishlist (Bulk)
exports.syncWishlist = async (req, res) => {
  try {
    const { userId } = req.params;
    const { items = [] } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, message: 'userId is required' });
    }

    const formattedItems = items.map((it) => ({
      productId: (it.productId || it.id).toString(),
      product: it.product || it,
      addedAt: it.addedAt || new Date(),
    }));

    const wishlist = await Wishlist.findOneAndUpdate(
      { userId },
      { items: formattedItems },
      { upsert: true, new: true }
    );

    const favoriteIds = wishlist.items.map((item) => item.productId);

    return res.status(200).json({
      success: true,
      message: 'Wishlist synced successfully',
      data: {
        userId: wishlist.userId,
        items: wishlist.items,
        favoriteIds,
        totalCount: wishlist.items.length,
      },
    });
  } catch (error) {
    console.error('Error syncing wishlist:', error);
    return res.status(500).json({ success: false, message: 'Failed to sync wishlist', error: error.message });
  }
};
