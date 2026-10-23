const Store = require('../models/Store');
const User = require('../models/User');
const Product = require('../models/Product');
const WalletTransaction = require('../models/WalletTransaction');
const fcmService = require('../services/fcmService');
const { getNextSequence } = require('./sequenceGenerator');
const { adjustProductStock } = require('./inventoryHelper');


/**
 * 1. Server-Side Totals & Discounts Calculation
 */
function calculateOrderTotals(body) {
  const { items = [], itemTotal, deliveryCharge = 0, handlingCharge = 2, couponDiscount = 0, coinsDiscount = 0, grandTotal } = body;

  const computedItemTotal = items.reduce((sum, item) => {
    const price = Number(item.price) || 0;
    const quantity = Number(item.quantity || item.qty || 1);
    return sum + (price * quantity);
  }, 0);

  const finalItemTotal = (itemTotal !== undefined && !isNaN(Number(itemTotal)) && Number(itemTotal) >= 0)
    ? Number(itemTotal)
    : computedItemTotal;

  const numDeliveryCharge = Number(deliveryCharge) || 0;
  const numHandlingCharge = Number(handlingCharge) || 2;
  const numCouponDiscount = Number(couponDiscount) || 0;
  const numCoinsDiscount = Number(coinsDiscount) || 0;

  const computedGrandTotal = Math.max(0, finalItemTotal - numCouponDiscount - numCoinsDiscount) + numDeliveryCharge + numHandlingCharge;
  const finalGrandTotal = (grandTotal !== undefined && !isNaN(Number(grandTotal)))
    ? Number(grandTotal)
    : computedGrandTotal;

  return {
    itemTotal: finalItemTotal,
    deliveryCharge: numDeliveryCharge,
    handlingCharge: numHandlingCharge,
    couponDiscount: numCouponDiscount,
    coinsDiscount: numCoinsDiscount,
    grandTotal: finalGrandTotal,
  };
}

/**
 * 2. Fetch Store Details, GPS Coordinates & Fallback Names
 */
async function resolveStoreCoordinates(storeId, clientDetails) {
  let resolved = clientDetails || {};
  const storeDoc = await Store.findOne({ storeId }).lean();
  if (storeDoc) {
    const realLat = (storeDoc.location && storeDoc.location.lat !== undefined)
      ? Number(storeDoc.location.lat)
      : (storeDoc.latitude || 0.0);
    const realLng = (storeDoc.location && storeDoc.location.lng !== undefined)
      ? Number(storeDoc.location.lng)
      : (storeDoc.longitude || 0.0);

    return {
      storeId: storeDoc.storeId,
      name: (storeDoc.name && storeDoc.name.trim().length > 0)
        ? storeDoc.name.trim()
        : (resolved.name && !['Bangalore Horticulture', 'Apothecary Pharmacy'].includes(resolved.name)
            ? resolved.name
            : 'Store Order'),
      address: (storeDoc.address && storeDoc.address.trim().length > 0) ? storeDoc.address : (resolved.address || ''),
      latitude: realLat,
      longitude: realLng,
      phone: storeDoc.phone || resolved.phone || '',
    };
  }
  return {
    ...resolved,
    latitude: resolved.latitude || 0.0,
    longitude: resolved.longitude || 0.0,
  };
}

/**
 * 3. Handle Wallet Deduction or Non-Wallet Ledger Record
 */
async function processOrderPayment({ userId, orderId, amount, paymentMethod, storeName }) {
  const isWallet = paymentMethod && paymentMethod.toLowerCase().includes('wallet');
  const numGrandTotal = Number(amount);

  const now = new Date();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

  if (isWallet) {
    const updatedUser = await User.findOneAndUpdate(
      {
        $or: [{ userId }, { phone: userId }],
        walletBalance: { $gte: numGrandTotal },
      },
      { $inc: { walletBalance: -numGrandTotal } },
      { returnDocument: 'after' }
    );

    if (!updatedUser) {
      const currentUser = await User.findOne({ $or: [{ userId }, { phone: userId }] }).lean();
      const curBal = currentUser ? currentUser.walletBalance || 0 : 0;
      return {
        success: false,
        errorResponse: {
          success: false,
          code: 'INSUFFICIENT_WALLET_BALANCE',
          message: `Insufficient wallet balance. Total: ₹${numGrandTotal}, Available: ₹${curBal}`,
          walletBalance: curBal,
        },
      };
    }

    const txId = await getNextSequence('walletTxId', 'TXN_PAY_', 5);
    const walletTx = new WalletTransaction({
      transactionId: txId,
      userId: updatedUser.userId,
      amount: -numGrandTotal,
      type: 'debit',
      category: 'order_payment',
      paymentMethod: 'Wallet Account',
      orderId: orderId,
      title: storeName || 'Store Order',
      subtitle: `Paid for order #${orderId} · ${dateStr}`,
      balanceAfter: updatedUser.walletBalance,
      status: 'success',
    });
    await walletTx.save();
    return { success: true };
  }

  // Non-wallet (COD / UPI / etc.)
  const userDoc = await User.findOne({ userId }).select('walletBalance').lean();
  const curWalletBal = userDoc?.walletBalance || 0;

  const txId = await getNextSequence('walletTxId', 'TXN_PAY_', 5);
  const walletTx = new WalletTransaction({
    transactionId: txId,
    userId,
    amount: -numGrandTotal,
    type: 'debit',
    category: 'order_payment',
    paymentMethod: paymentMethod || 'Cash on Delivery',
    orderId,
    title: storeName || 'Store Order',
    subtitle: `Paid for order #${orderId} · ${dateStr}`,
    balanceAfter: curWalletBal,
    status: paymentMethod?.toLowerCase().includes('cash') ? 'pending' : 'success',
  });
  await walletTx.save();
  return { success: true };
}

/**
 * 4. Parallel Product Inventory Decrement
 */
async function decrementProductStock(items) {
  return adjustProductStock(items, 'decrement');
}

/**
 * 5. Real-Time Socket Broadcast, Rider Radial Dispatch & Merchant FCM
 */
function dispatchOrderAlerts(app, order, storeDetails) {
  const storeId = order.storeId;
  const orderId = order.orderId;

  // Real-time Socket.io Notification to Merchant & Immediate Rider Dispatch
  const io = app.get('io');
  if (io) {
    const orderPayload = order.toObject ? order.toObject() : order;
    io.to(`store:${storeId}`).emit(`store:${storeId}:new_order`, orderPayload);
    io.emit(`store:${storeId}:new_order`, orderPayload);
    console.log(`📡 [Socket.io] Emitted single targeted new_order for store: ${storeId} (Order: ${orderId})`);

    // ⚡ Immediate Parallel Rider Dispatch on Order Placement
    const dispatchPayload = {
      ...orderPayload,
      dispatchRound: 1,
      countdownSecs: 30,
    };

    // Broadcast to available & dispatch rooms so rider app immediately triggers _handleIncomingDispatchOrder popup
    io.emit('order:available', orderPayload);
    io.to('riders').emit('order:available', orderPayload);
    io.emit('order:dispatch', dispatchPayload);
    io.to('riders').emit('order:dispatch', dispatchPayload);
    io.to('online_riders').emit('order:dispatch', dispatchPayload);

    const dispatchOrder = app.get('dispatchOrder');
    const storeLat = storeDetails.latitude || 0;
    const storeLng = storeDetails.longitude || 0;
    if (dispatchOrder && (storeLat !== 0 || storeLng !== 0)) {
      dispatchOrder(io, orderPayload, storeLat, storeLng, 1, []);
    } else {
      const payload = { ...orderPayload, dispatchRound: 3, countdownSecs: 30 };
      const registry = app.get('riderRegistry');
      if (registry) {
        for (const [rId, info] of registry.entries()) {
          if (info.isOnline && !info.isBusy && info.socketId) {
            io.to(info.socketId).emit('order:dispatch', payload);
          }
        }
      }
    }
  }

  // Send FCM Push to Store
  Store.findOne({ storeId })
    .select('fcmToken phone')
    .then(async (storeDoc) => {
      let token = storeDoc?.fcmToken;
      if (!token && storeDoc?.phone) {
        const owner = await User.findOne({ phone: storeDoc.phone }).select('fcmToken').lean();
        token = owner?.fcmToken;
      }
      if (token) {
        fcmService.sendToStoreNewOrder(token, order);
      }
    })
    .catch((err) => console.error('Error sending store FCM:', err.message));
}

module.exports = {
  calculateOrderTotals,
  resolveStoreCoordinates,
  processOrderPayment,
  decrementProductStock,
  dispatchOrderAlerts,
};
