const Product = require('../models/Product');

/**
 * Adjusts product inventory stock in parallel for order placement, cancellation, or returns.
 * Supports both top-level products and specific variant stock adjustments.
 * 
 * @param {Array} items - list of items from the order
 * @param {'decrement'|'restock'} mode - 'decrement' to reduce stock, 'restock' to restore stock
 */
async function adjustProductStock(items, mode = 'decrement') {
  if (!Array.isArray(items) || items.length === 0) return;

  const multiplier = mode === 'decrement' ? -1 : 1;

  const stockUpdates = items.map((item) => {
    const pId = item.productId || item.id;
    const vId = item.variantId;
    const qty = Number(item.quantity || item.qty || 1);
    if (!pId || qty <= 0) return Promise.resolve();

    const delta = multiplier * qty;

    if (vId) {
      // Direct match on 'variants.variantId' enables MongoDB's positional operator '$'
      return Product.updateOne(
        { productId: pId, 'variants.variantId': vId },
        { $inc: { 'variants.$.stock': delta, stock: delta } }
      ).catch((err) => console.warn(`⚠️ [Inventory] Variant stock error (${pId}:${vId}):`, err.message));
    }

    return Product.updateOne(
      { productId: pId },
      { $inc: { stock: delta } }
    ).catch((err) => console.warn(`⚠️ [Inventory] Stock error (${pId}):`, err.message));
  });

  await Promise.all(stockUpdates);
}

module.exports = {
  adjustProductStock,
};
