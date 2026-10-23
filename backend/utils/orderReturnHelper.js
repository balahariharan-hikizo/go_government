const User = require('../models/User');
const Rider = require('../models/Rider');
const Store = require('../models/Store');
const Product = require('../models/Product');
const WalletTransaction = require('../models/WalletTransaction');
const fcmService = require('../services/fcmService');
const { createNotification } = require('../controllers/notificationController');
const { adjustProductStock } = require('./inventoryHelper');
const { executeWalletTransaction } = require('./walletHelper');


/**
 * 1. Parallel inventory restock for returned order items
 */
async function restockOrderItems(items) {
  return adjustProductStock(items, 'restock');
}


/**
 * 2. Financial settlement on return confirmation:
 *    - Citizen Wallet Refund
 *    - Rider Return Trip Compensation
 *    - Store Product Revenue Clawback (only for citizen reverse returns)
 */
async function settleReturnFinances(order) {
  const deliveryFee = Number(order.deliveryCharge) || 0;
  const isDoorstepReturn = order.returnDetails?.returnType === 'rider_doorstep' || order.returnDetails?.initiatedBy === 'rider';

  // For doorstep return, citizen is refunded product cost (delivery fee retained for rider's trip)
  let refundAmt = Number(order.grandTotal) || 0;
  if (isDoorstepReturn && deliveryFee > 0) {
    refundAmt = Math.max(0, refundAmt - deliveryFee);
  }

  const wasWallet = order.paymentMethod && order.paymentMethod.toLowerCase().includes('wallet');
  const wasPaid = order.paymentStatus === 'paid';
  let refundTxId = '';

  const now = new Date();
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

  // A. Citizen Refund
  if ((wasWallet || wasPaid) && order.paymentStatus !== 'refunded') {
    if (refundAmt > 0) {
      const res = await executeWalletTransaction({
        role: 'user',
        targetId: order.userId,
        amount: refundAmt,
        type: 'credit',
        category: 'order_refund',
        paymentMethod: 'Wallet Refund',
        orderId: order.orderId,
        title: 'Order Return Refund',
        subtitle: `Return refund (items cost) for order #${order.orderId}`,
        txPrefix: 'TXN_REF_',
      });

      if (res.success) {
        refundTxId = res.transactionId;
        order.paymentStatus = 'refunded';
        order.returnDetails.refundAmount = refundAmt;
        order.returnDetails.refundTransactionId = refundTxId;
      }
    }
  }

  // B. Rider Compensation for Return Trip
  const riderId = order.deliveryAgent?.riderId;
  const reverseDeliveryFee = Number(order.returnDetails?.reverseDeliveryFee) || 0;
  let riderPayoutAmt = 0;
  let payoutTitle = '';
  let payoutSubtitle = '';

  if (riderId && isDoorstepReturn && deliveryFee > 0) {
    riderPayoutAmt = deliveryFee;
    payoutTitle = 'Return Trip Payout';
    payoutSubtitle = `Trip delivery payout for return order #${order.orderId}`;
  } else if (riderId && reverseDeliveryFee > 0) {
    riderPayoutAmt = reverseDeliveryFee;
    payoutTitle = 'Reverse Return Trip Payout';
    payoutSubtitle = `Reverse pickup delivery fee for return #${order.orderId}`;
  }

  if (riderId && riderPayoutAmt > 0) {
    const res = await executeWalletTransaction({
      role: 'rider',
      targetId: riderId,
      amount: riderPayoutAmt,
      type: 'credit',
      category: 'delivery_payout',
      paymentMethod: isDoorstepReturn ? 'Return Trip Fee' : 'Reverse Pickup Fee',
      orderId: order.orderId,
      title: payoutTitle,
      subtitle: payoutSubtitle,
      txPrefix: 'TXN_PAYOUT_',
    });

    if (res.success) {
      order.returnDetails.riderPayout = riderPayoutAmt;
    }
  }

  // C. Store Wallet Debit for restocked products (Citizen refunded)
  if (!isDoorstepReturn && order.storeId && refundAmt > 0) {
    const storeProductAmt = Math.max(0, (Number(order.grandTotal) || 0) - deliveryFee);
    if (storeProductAmt > 0) {
      await executeWalletTransaction({
        role: 'store',
        targetId: order.storeId,
        amount: storeProductAmt,
        type: 'debit',
        category: 'order_return',
        paymentMethod: 'Store Wallet',
        orderId: order.orderId,
        title: `Order #${order.orderId} · Return Refund`,
        subtitle: `Items restocked to inventory · Citizen refunded`,
        txPrefix: 'TXN_RET_STORE_',
      });
    }
  }

  return { refundTxId };
}

/**
 * 3. Free up rider busy status in live registry and DB
 */
async function releaseRider(app, riderId) {
  if (!riderId) return;
  const registry = app.get('riderRegistry');
  if (registry && registry.has(riderId)) {
    registry.get(riderId).isBusy = false;
  }
  await Rider.updateOne({ riderId }, { $set: { isBusy: false } });
}

/**
 * 4. Multi-party Socket broadcast, citizen push & in-app notification
 */
function dispatchReturnConfirmedAlerts(app, order, refundTxId) {
  const orderId = order.orderId;
  const riderId = order.deliveryAgent?.riderId;

  const io = app.get('io');
  if (io) {
    const orderPayload = order.toObject ? order.toObject() : order;
    io.emit(`order:${orderId}:status_update`, orderPayload);
    io.emit('order:status_update', orderPayload);
    io.emit('order:status_updated', orderPayload);
    io.to(`store:${order.storeId}`).emit('order:returned', orderPayload);
    if (riderId) io.to(`rider:${riderId}`).emit('order:returned', orderPayload);
  }

  console.log(`✅📦 [Return Confirmed] Store ${order.storeId} verified return for order ${orderId}`);

  // High-Priority Citizen FCM Push on Return Confirmation
  User.findOne({ $or: [{ userId: order.userId }, { phone: order.userId }] })
    .select('fcmToken')
    .lean()
    .then((citizen) => {
      if (citizen?.fcmToken) {
        fcmService.sendToCitizenOrderStatus(
          citizen.fcmToken,
          '📦 Return Received & Refunded',
          `Your return for order #${orderId} was confirmed by the store. ₹${order.returnDetails?.refundAmount || order.grandTotal} has been refunded to your wallet.`,
          orderId
        );
      }
    })
    .catch((err) => console.warn('Citizen return confirm FCM error:', err.message));

  // In-App Notification to Citizen
  if (order.userId) {
    const refundMsg = (order.paymentStatus === 'refunded')
      ? `Refund of ₹${order.grandTotal} has been credited to your wallet.`
      : 'Items have been restocked.';
    createNotification({
      userId: order.userId,
      title: 'Return Completed & Refunded',
      message: `Your returned order #${orderId} has been confirmed by ${order.storeName || 'the store'}. ${refundMsg}`,
      type: 'order',
      referenceId: orderId,
      metadata: { status: order.status, refundAmount: order.returnDetails.refundAmount, refundTxId },
    }).catch((e) => console.warn('Notification error:', e.message));
  }
}

/**
 * 5. Deduct reverse delivery logistics fee (₹35) from store wallet on return approval
 */
async function processStoreReverseFee(storeId, orderId) {
  const reverseFee = 35;
  await executeWalletTransaction({
    role: 'store',
    targetId: storeId,
    amount: reverseFee,
    type: 'debit',
    category: 'return_delivery_fee',
    paymentMethod: 'Store Wallet',
    orderId,
    title: `Order #${orderId} · Return Pickup Fee`,
    subtitle: `Rider logistics charge for reverse return`,
    txPrefix: 'TXN_DEBIT_',
  });
  return reverseFee;
}

/**
 * 6. Dispatch reverse pickup broadcast sockets and rider FCM alerts
 */
function dispatchReversePickupAlerts(app, order) {
  const io = app.get('io');
  if (!io) return;

  const orderId = order.orderId;
  const orderPayload = order.toObject ? order.toObject() : order;

  io.emit('order:available', orderPayload);
  io.to('riders').emit('order:available', orderPayload);

  // Targeted reverse pickup dispatch alert to online, non-busy delivery partners
  const dispatchPayload = {
    ...orderPayload,
    dispatchRound: 3,
    countdownSecs: 30,
    isReversePickup: true,
    deliveryFee: 35,
    deliveryCharge: 35,
  };

  io.to('riders').emit('order:dispatch', dispatchPayload);

  const notifiedTokens = new Set();
  const registry = app.get('riderRegistry');
  if (registry) {
    for (const [rId, info] of registry.entries()) {
      if (info.isOnline && !info.isBusy) {
        if (info.socketId) {
          io.to(info.socketId).emit('order:dispatch', dispatchPayload);
        }
        io.to(`rider:${rId}`).emit('order:dispatch', dispatchPayload);
      }
    }
  }

  // Broadcast FCM wake-up push alert to all online, non-busy riders
  Rider.find({ isOnline: true, isBusy: { $ne: true }, fcmToken: { $ne: '' } })
    .select('fcmToken riderId phone')
    .then(async (riders) => {
      for (const r of riders) {
        if (r.fcmToken && !notifiedTokens.has(r.fcmToken)) {
          notifiedTokens.add(r.fcmToken);
          fcmService.sendToRiderOrderAlert(r.fcmToken, dispatchPayload);
        }
      }

      if (registry) {
        for (const [rId, info] of registry.entries()) {
          if (info.isOnline && !info.isBusy) {
            try {
              const uDoc = await User.findOne({
                $or: [{ userId: rId }, { phone: rId }],
                fcmToken: { $exists: true, $ne: '' },
              }).select('fcmToken');
              if (uDoc?.fcmToken && !notifiedTokens.has(uDoc.fcmToken)) {
                notifiedTokens.add(uDoc.fcmToken);
                fcmService.sendToRiderOrderAlert(uDoc.fcmToken, dispatchPayload);
              }
            } catch (_) {}
          }
        }
      }
      console.log(`📡 [Return Dispatch] Sent wake-up push to ${notifiedTokens.size} online riders for order ${orderId}`);
    })
    .catch((err) => console.error('Error broadcasting return dispatch rider FCM:', err.message));
}

module.exports = {
  restockOrderItems,
  settleReturnFinances,
  releaseRider,
  dispatchReturnConfirmedAlerts,
  processStoreReverseFee,
  dispatchReversePickupAlerts,
};

