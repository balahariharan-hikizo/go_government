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

  const bulkOps = items
    .map((item) => {
      const pId = item.productId || item.id;
      const vId = item.variantId;
      const qty = Number(item.quantity || item.qty || 1);
      if (!pId || qty <= 0) return null;

      const delta = multiplier * qty;

      if (vId) {
        // Direct match on 'variants.variantId' enables MongoDB positional operator '$'
        return {
          updateOne: {
            filter: { productId: pId, 'variants.variantId': vId }, update: { $inc: { 'variants.$.stock': delta, stock: delta } },
          },
        };
      }

      return {
        updateOne: {
          filter: { productId: pId }, update: { $inc: { stock: delta } },
        },
      };
    })
    .filter(Boolean);

  if (bulkOps.length > 0) {
    await Product.bulkWrite(bulkOps, { ordered: false })
      .catch((err) => console.warn('⚠️ [Inventory] Bulk stock update error:', err.message));
  }
}

module.exports = {
  adjustProductStock,
};

