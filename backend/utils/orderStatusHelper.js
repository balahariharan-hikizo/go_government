const { formatTransactionDate } = require('./commonHelper');
const { adjustProductStock } = require('./inventoryHelper');
const { executeWalletTransaction } = require('./walletHelper');

/**
 * 1. Restores catalog stock and refunds citizen wallet if order was prepaid
 */
async function handleOrderCancellation(existingOrder, updateFields) {
  // Parallel inventory restock
  await adjustProductStock(existingOrder.items, 'restock');

  // Refund citizen wallet
  const wasWallet = existingOrder.paymentMethod && existingOrder.paymentMethod.toLowerCase().includes('wallet');
  if (wasWallet && existingOrder.paymentStatus === 'paid') {
    const refundAmt = Number(existingOrder.grandTotal) || 0;
    if (refundAmt > 0) {
      const res = await executeWalletTransaction({
        role: 'user',
        targetId: existingOrder.userId,
        amount: refundAmt,
        type: 'credit',
        category: 'order_refund',
        paymentMethod: 'Wallet Refund',
        orderId: existingOrder.orderId,
        title: 'Order Refund',
        subtitle: `Refund for cancelled order #${existingOrder.orderId} · ${formatTransactionDate()}`,
        txPrefix: 'TXN_REF_',
      });

      if (res.success) {
        updateFields.paymentStatus = 'refunded';
      }
    }
  }
}

/**
 * 2. Settles rider delivery fee payout and store net sales on delivery completion
 */
async function handleOrderDeliveredSettlement(existingOrder) {
  const standardDeliveryFee = 35;
  const customerDeliveryCharge = Number(existingOrder.deliveryCharge) || 0;
  // If customer had free delivery, rider is guaranteed ₹35 sponsored by store sale
  const riderFee = customerDeliveryCharge > 0 ? customerDeliveryCharge : standardDeliveryFee;

  // 1. Rider Payout
  const riderId = existingOrder.deliveryAgent?.riderId;
  if (riderId && riderFee > 0) {
    await executeWalletTransaction({
      role: 'rider',
      targetId: riderId,
      amount: riderFee,
      type: 'credit',
      category: 'rider_payout',
      paymentMethod: customerDeliveryCharge > 0 ? 'Customer Delivery Fee' : 'Store Sponsored Delivery Fee',
      orderId: existingOrder.orderId,
      title: 'Delivery Task Earnings',
      subtitle: `Earned ₹${riderFee} for delivering order #${existingOrder.orderId}`,
      txPrefix: 'TXN_RDR_',
    });
  }

  // 2. Store Sales Settlement (Net of delivery fee)
  if (existingOrder.storeId) {
    const grandTotal = Number(existingOrder.grandTotal) || 0;
    const deliveryDeduction = customerDeliveryCharge > 0 ? customerDeliveryCharge : standardDeliveryFee;
    const storeAmount = Math.max(0, grandTotal - deliveryDeduction);

    if (storeAmount > 0) {
      await executeWalletTransaction({
        role: 'store',
        targetId: existingOrder.storeId,
        amount: storeAmount,
        type: 'credit',
        category: 'store_settlement',
        paymentMethod: 'Store Settlement',
        orderId: existingOrder.orderId,
        title: `Order #${existingOrder.orderId} · Sales Credit`,
        subtitle: `Product sales credited to store wallet`,
        txPrefix: 'TXN_SETTLE_',
      });
    }
  }
}

module.exports = {
  handleOrderCancellation,
  handleOrderDeliveredSettlement,
};
