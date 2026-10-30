const Product = require('../models/Product');

/**
 * Adjusts product inventory stock atomically in a single DB call using bulkWrite.
 * Supports both top-level products and specific variant stock adjustments simultaneously.
 * 
 * @param {Array} items - list of items from the order
 * @param {'decrement'|'restock'} mode - 'decrement' to reduce stock, 'restock' to restore stock
 */
async function adjustProductStock(items, mode = 'decrement') {
  if (!Array.isArray(items) || items.length === 0) return;

  const multiplier = mode === 'decrement' ? -1 : 1;
  const bulkOps = [];

  for (let i = 0; i < items.length; i++) {
    const item = items[i];
    let pId = (item.productId || item.id || '').toString().trim();
    let vId = (item.variantId || '').toString().trim();
    const qty = Number(item.quantity || item.qty || 1);
    if (qty <= 0) continue;

    if (pId.includes(':')) {
      const parts = pId.split(':');
      pId = parts[0].trim();
      if (!vId && parts[1]) vId = parts[1].trim();
    }

    const delta = multiplier * qty;

    // Filter construction: support productId, and fallback to title match if pId was a dummy timestamp
    let filter;
    if (pId && !pId.startsWith('prod_') && !pId.startsWith('reorder_')) {
      filter = vId ? { productId: pId, 'variants.variantId': vId } : { productId: pId };
    } else if (item.title) {
      filter = vId
        ? { title: item.title, 'variants.variantId': vId }
        : { title: item.title };
    } else {
      continue;
    }

    if (vId) {
      bulkOps.push({
        updateOne: {
          filter,
          update: { $inc: { 'variants.$.stock': delta, stock: delta } },
        },
      });
    } else {
      bulkOps.push({
        updateOne: {
          filter,
          update: { $inc: { stock: delta } },
        },
      });
    }
  }

  if (bulkOps.length > 0) {
    await Product.bulkWrite(bulkOps, { ordered: false })
      .catch((err) => console.warn('⚠️ [Inventory] Bulk stock update error:', err.message));
  }
}

module.exports = {
  adjustProductStock,
};

