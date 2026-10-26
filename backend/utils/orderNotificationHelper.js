const fcmService = require('../services/fcmService');
const User = require('../models/User');
const Store = require('../models/Store');
const Rider = require('../models/Rider');
const { createNotification } = require('../controllers/notificationController');

/**
 * Dispatches real-time socket updates and Citizen FCM push asynchronously.
 * Kept in utils for clean separation of concerns and high reusability.
 * 
 * @param {Object} order - The populated Order mongoose document or object
 * @param {Object} app - Express application instance (for accessing socket.io)
 */
function sendOrderAssignedAlerts(order, app) {
  const io = app ? app.get('io') : null;
  const payload = order.toObject ? order.toObject() : order;
  const assignedName = order.deliveryAgent?.name || 'Delivery Partner';
  const orderId = order.orderId;

  // 1. Real-time Socket Broadcasts
  if (io) {
    io.emit(`order:${orderId}:status_update`, payload);
    io.emit('order:status_update', payload);
    io.emit('order:assigned', payload);
    if (order.storeId) {
      io.emit(`store:${order.storeId}:order_update`, payload);
      io.to(`store:${order.storeId}`).emit('order:status_update', payload);
    }
  }

  // 2. High-Priority Push Notification to Citizen
  const isReverse = order.status === 'return_pickup_assigned';
  const citizenTitle = isReverse ? '🔄 Return Pickup Partner Assigned!' : '🛵 Delivery Partner Assigned!';
  const citizenMessage = isReverse
    ? `${assignedName} is assigned to collect your return items from your doorstep for order #${orderId}.`
    : `${assignedName} has accepted your order #${orderId} and is heading to the store.`;

  // Use populated citizen FCM token directly (Zero extra DB query!)
  const citizenToken = order.citizen?.fcmToken;
  if (citizenToken) {
    fcmService.sendToCitizenOrderStatus(citizenToken, citizenTitle, citizenMessage, orderId)
      .catch((err) => console.warn('Citizen FCM send error:', err.message));
  } else if (order.userId) {
    // Fallback if citizen was not populated
    User.findOne({ $or: [{ userId: order.userId }, { phone: order.userId }] })
      .select('fcmToken')
      .lean()
      .then((citizen) => {
        if (citizen?.fcmToken) {
          fcmService.sendToCitizenOrderStatus(citizen.fcmToken, citizenTitle, citizenMessage, orderId);
        }
      })
      .catch((err) => console.warn('Error sending fallback citizen FCM:', err.message));
  }

  // 3. Notification to Store Owner (Using populated store with fallback)
  if (order.storeId) {
    const storeTitle = isReverse ? '🔄 Return Pickup Partner Assigned' : '🛵 Delivery Partner Assigned';
    const storeMsg = isReverse
      ? `${assignedName} has accepted reverse pickup for order #${orderId} and is heading to customer doorstep.`
      : `${assignedName} has accepted order #${orderId} and is heading to your store for pickup.`;

    // High-Priority FCM Push using populated store token or fallback
    const storeToken = order.store?.fcmToken;
    if (storeToken) {
      fcmService.sendToStoreOrderStatus(storeToken, storeTitle, storeMsg, orderId)
        .catch((err) => console.warn('Store FCM send error:', err.message));
    } else {
      Store.findOne({ storeId: order.storeId })
        .select('fcmToken')
        .lean()
        .then((storeDoc) => {
          if (storeDoc?.fcmToken) {
            fcmService.sendToStoreOrderStatus(storeDoc.fcmToken, storeTitle, storeMsg, orderId)
              .catch((err) => console.warn('Store fallback FCM send error:', err.message));
          }
        })
        .catch((err) => console.warn('Error fetching fallback store FCM token:', err.message));
    }

    // In-App Notification history entry for Store Owner
    createNotification({
      userId: order.storeId,
      title: storeTitle,
      message: storeMsg,
      type: 'order',
      referenceId: orderId,
      metadata: { status: order.status, riderId: order.deliveryAgent?.riderId },
    }).catch(() => {});
  }
}

/**
 * Dispatches real-time socket events, FCM push notifications, and In-App notifications
 * when an order status updates. Also frees up the rider when delivered.
 * 
 * @param {Object} order - Populated Order document or object
 * @param {Object} app - Express application instance
 */
function sendOrderStatusUpdateAlerts(order, app) {
  if (!order) return;
  const orderId = order.orderId;
  const status = order.status;
  const io = app ? app.get('io') : null;

  // 1. Socket.io Real-time Updates
  if (io) {
    const orderPayload = order.toObject ? order.toObject() : order;
    io.emit(`order:${orderId}:status_update`, orderPayload);
    io.emit('order:status_update', orderPayload);
    if (order.storeId) {
      io.emit(`store:${order.storeId}:order_update`, orderPayload);
      io.to(`store:${order.storeId}`).emit('order:status_update', orderPayload);
    }

    if (status === 'ready_for_pickup') {
      const hasAssignedRider = Boolean(order.deliveryAgent?.riderId);
      if (!hasAssignedRider) {
        io.emit('order:available', orderPayload);
        io.to('riders').emit('order:available', orderPayload);

        const dispatchOrder = app.get('dispatchOrder');
        const storeLat = order.storeDetails?.latitude || 0;
        const storeLng = order.storeDetails?.longitude || 0;
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
      } else {
        console.log(`📦 [Store Ready] Parcel packed for order ${orderId}. Rider ${order.deliveryAgent.riderId} already assigned.`);
        io.to(`rider:${order.deliveryAgent.riderId}`).emit('order:status_update', orderPayload);
      }
    }

    if (status === 'accepted') {
      const dispatchTimers = app.get('dispatchTimers');
      if (dispatchTimers && dispatchTimers.has(orderId)) {
        clearTimeout(dispatchTimers.get(orderId).timer);
        dispatchTimers.delete(orderId);
      }
      if (order.storeId) {
        io.to(`store:${order.storeId}`).emit('order:status_update', orderPayload);
      }
      io.to('riders').emit('order:dispatch_cancelled', { orderId });
    }

    if (status === 'delivered' || status === 'cancelled') {
      const riderId = order.deliveryAgent?.riderId;
      if (riderId) {
        const riderRegistry = app.get('riderRegistry');
        if (riderRegistry && riderRegistry.has(riderId)) {
          riderRegistry.get(riderId).isBusy = false;
        }
        Rider.updateOne({ riderId }, { $set: { isBusy: false } }).catch(() => {});
      }
    }
  }

  // 2. High-Priority Citizen FCM Push Notifications
  const pushStatuses = ['out_for_delivery', 'delivered', 'cancelled', 'returning_to_store'];
  if (pushStatuses.includes(status)) {
    const fcmMessages = {
      out_for_delivery: {
        title: '🚚 Out for Delivery!',
        body: `Your order #${orderId} is on the way to your delivery address.`,
      },
      delivered: {
        title: '🎉 Order Delivered!',
        body: `Your order #${orderId} has been successfully delivered. Thank you!`,
      },
      cancelled: {
        title: '❌ Order Cancelled',
        body: `Your order #${orderId} has been cancelled.`,
      },
      returning_to_store: {
        title: '🔄 Return Picked Up',
        body: `Your return items for order #${orderId} have been collected by our delivery partner.`,
      },
    };

    const msgConfig = fcmMessages[status];
    if (msgConfig) {
      const citizenToken = order.citizen?.fcmToken;
      if (citizenToken) {
        fcmService.sendToCitizenOrderStatus(citizenToken, msgConfig.title, msgConfig.body, orderId)
          .catch((err) => console.warn('Citizen FCM send error:', err.message));
      } else if (order.userId) {
        User.findOne({ $or: [{ userId: order.userId }, { phone: order.userId }] })
          .select('fcmToken')
          .lean()
          .then((citizen) => {
            if (citizen?.fcmToken) {
              fcmService.sendToCitizenOrderStatus(citizen.fcmToken, msgConfig.title, msgConfig.body, orderId);
            }
          })
          .catch((err) => console.error('Error sending fallback citizen FCM:', err.message));
      }
    }
  }

  // 3. In-App Notification history entry for Citizen
  const inAppStatuses = ['accepted', 'packed', 'ready_for_pickup', 'picked_up', 'out_for_delivery', 'delivered', 'cancelled', 'returning_to_store', 'returned_to_store'];
  if (order.userId && inAppStatuses.includes(status)) {
    const statusTitles = {
      accepted: 'Store Accepted Your Order',
      packed: 'Order Packed',
      ready_for_pickup: 'Order Ready for Pickup',
      picked_up: 'Rider Picked Up Your Order',
      out_for_delivery: '🚚 Order Out for Delivery',
      delivered: '🎉 Order Delivered Successfully',
      cancelled: '❌ Order Cancelled',
      returning_to_store: '🔄 Return Items Collected',
      returned_to_store: '📦 Return Completed at Store',
    };

    createNotification({
      userId: order.userId,
      title: statusTitles[status] || `Order ${status.replace(/_/g, ' ')}`,
      message: status === 'delivered'
        ? `Your order #${orderId} was delivered successfully. Enjoy your items!`
        : `Order #${orderId} from ${order.storeName || 'Store'} is now ${status.replace(/_/g, ' ')}.`,
      type: 'order',
      referenceId: orderId,
      metadata: { status, grandTotal: order.grandTotal },
    }).catch((e) => console.warn('In-App Notification error:', e.message));
  }
}

module.exports = {
  sendOrderAssignedAlerts,
  sendOrderStatusUpdateAlerts,
};
