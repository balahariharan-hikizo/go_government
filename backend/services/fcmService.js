const { initializeApp, cert } = require('firebase-admin/app');
const { getMessaging } = require('firebase-admin/messaging');
const path = require('path');
const fs = require('fs');

let fcmMessaging = null;

try {
  const configDir = path.join(__dirname, '../config');
  let serviceAccountPath = path.join(configDir, 'gogovernment-firebase-adminsdk-fbsvc-3ae59d0f4b.json');

  if (!fs.existsSync(serviceAccountPath) && fs.existsSync(configDir)) {
    const foundFile = fs.readdirSync(configDir).find(f => f.includes('firebase-adminsdk') && f.endsWith('.json'));
    if (foundFile) {
      serviceAccountPath = path.join(configDir, foundFile);
    }
  }

  if (fs.existsSync(serviceAccountPath)) {
    const serviceAccount = require(serviceAccountPath);
    const app = initializeApp({
      credential: cert(serviceAccount),
    });
    fcmMessaging = getMessaging(app);
    console.log(`🔥 [FCM] Firebase Admin SDK successfully initialized (${path.basename(serviceAccountPath)})`);
  } else {
    console.warn(`⚠️ [FCM] Service account file not found in: ${configDir}`);
  }
} catch (error) {
  console.error('❌ [FCM] Error initializing Firebase Admin SDK:', error.message);
}

/**
 * Send a notification or data push to a specific FCM device token.
 */
async function sendToToken(fcmToken, { title, body, data = {}, sound = 'default', channelId = 'default', priority = 'high', isDataOnly = false }) {
  if (!fcmMessaging) {
    console.warn('⚠️ [FCM] Skipping push notification — Firebase Admin not initialized');
    return null;
  }

  if (!fcmToken || typeof fcmToken !== 'string' || fcmToken.trim().length === 0) {
    return null;
  }

  try {
    // FCM data values MUST all be strings
    const stringifiedData = {};
    for (const [key, value] of Object.entries(data)) {
      stringifiedData[key] = value !== undefined && value !== null ? String(value) : '';
    }
    if (title) stringifiedData.title = String(title);
    if (body) stringifiedData.body = String(body);

    const message = {
      token: fcmToken.trim(),
      data: stringifiedData,
      android: {
        priority: priority === 'high' ? 'high' : 'normal',
      },
    };

    if (!isDataOnly) {
      message.android.notification = {
        channelId: channelId,
        sound: sound,
        priority: 'max',
        defaultVibrateTimings: true,
        defaultSound: sound === 'default',
      };
      if (title || body) {
        message.notification = {
          title: title || '',
          body: body || '',
        };
      }
    }

    const response = await fcmMessaging.send(message);
    console.log(`🚀 [FCM] Successfully sent push notification: ${response}`);
    return response;
  } catch (error) {
    // Handle invalid / unregistered token gracefully
    if (
      error.code === 'messaging/registration-token-not-registered' ||
      error.code === 'messaging/invalid-registration-token'
    ) {
      console.warn(`⚠️ [FCM] Stale/invalid token encountered: ${fcmToken.slice(0, 15)}...`);
    } else {
      console.error('❌ [FCM] Error sending message:', error.message);
    }
    return null;
  }
}

/**
 * Send high-priority alert to a Rider for an incoming delivery dispatch.
 */
async function sendToRiderOrderAlert(fcmToken, orderPayload) {
  const isReverse = Boolean(orderPayload.isReversePickup || orderPayload.status === 'return_pickup_pending');

  const rawStoreName =
    orderPayload.storeName ||
    (orderPayload.storeDetails && orderPayload.storeDetails.name) ||
    'Store';

  const rawCustomerAddress =
    orderPayload.dropAddress ||
    (orderPayload.deliveryAddress && orderPayload.deliveryAddress.address) ||
    'Customer Location';

  const pickupLocation = isReverse ? rawCustomerAddress : rawStoreName;
  const dropLocation = isReverse ? rawStoreName : rawCustomerAddress;

  const customerFee = Number(
    orderPayload.deliveryFee !== undefined && orderPayload.deliveryFee !== null
      ? orderPayload.deliveryFee
      : orderPayload.deliveryCharge !== undefined && orderPayload.deliveryCharge !== null
      ? orderPayload.deliveryCharge
      : orderPayload.estimatedPayout || 0
  );
  // Guarantee minimum ₹35 delivery payout to rider on all orders (sponsored or customer paid)
  const fee = customerFee > 0 ? Math.max(customerFee, 35) : 35;

  const title = isReverse ? '🚨 Return Pickup Request Available!' : '🚨 New Delivery Order Available!';
  const body = `Earn ₹${fee} · Pick up from ${pickupLocation} to ${dropLocation}`;

  return sendToToken(fcmToken, {
    title,
    body,
    channelId: 'rider_order_alerts_v2',
    sound: 'alert',
    priority: 'high',
    data: {
      type: 'order_dispatch',
      orderId: orderPayload.orderId || '',
      storeName: pickupLocation,
      dropAddress: dropLocation,
      fee: String(fee),
      countdownSecs: String(orderPayload.countdownSecs || 30),
      isReversePickup: isReverse ? 'true' : 'false',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
  });
}

/**
 * Send notification to Store Owner when a new order is created.
 */
async function sendToStoreNewOrder(fcmToken, order) {
  return sendToToken(fcmToken, {
    title: '🔔 New Order Received!',
    body: `Order #${order.orderId} received (Total: ₹${order.grandTotal}). Tap to view.`,
    channelId: 'store_order_alerts',
    sound: 'default',
    priority: 'high',
    isDataOnly: true,
    data: {
      type: 'new_order',
      orderId: order.orderId || '',
      grandTotal: String(order.grandTotal || ''),
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
  });
}

/**
 * Send notification to Citizen when their order status updates.
 */
async function sendToCitizenOrderStatus(fcmToken, title, body, orderId) {
  return sendToToken(fcmToken, {
    title: title,
    body: body,
    channelId: 'citizen_order_updates',
    sound: 'default',
    priority: 'high',
    data: {
      type: 'order_status_update',
      orderId: orderId || '',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
  });
}

/**
 * Send push notification to Store Owner when a citizen requests return.
 */
async function sendToStoreReturnAlert(fcmToken, order) {
  const reason = order.returnDetails?.reason || 'Customer Return Request';
  return sendToToken(fcmToken, {
    title: '⚠️ Citizen Return Requested!',
    body: `Customer requested return for Order #${order.orderId}. Reason: ${reason}. Tap to review.`,
    channelId: 'store_order_alerts',
    sound: 'default',
    priority: 'high',
    isDataOnly: true,
    data: {
      type: 'return_requested',
      orderId: order.orderId || '',
      reason: reason,
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
  });
}

/**
 * Send push notification to Store Owner when order status or rider assignment updates.
 */
async function sendToStoreOrderStatus(fcmToken, title, body, orderId) {
  return sendToToken(fcmToken, {
    title,
    body,
    channelId: 'store_order_alerts',
    sound: 'default',
    priority: 'high',
    data: {
      type: 'order_assigned',
      orderId: orderId || '',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
  });
}

/**
 * Send push notification when a new chat message arrives between Citizen and Rider.
 */
async function sendChatMessageAlert(fcmToken, { title, body, orderId, senderRole }) {
  return sendToToken(fcmToken, {
    title,
    body,
    channelId: 'chat_alerts',
    sound: 'default',
    priority: 'high',
    data: {
      type: 'chat_message',
      orderId: orderId || '',
      senderRole: senderRole || '',
      click_action: 'FLUTTER_NOTIFICATION_CLICK',
    },
  });
}
  
module.exports = {
  isReady: () => fcmMessaging !== null,
  sendToToken,
  sendToRiderOrderAlert,
  sendToStoreNewOrder,
  sendToStoreReturnAlert,
  sendToStoreOrderStatus,
  sendToCitizenOrderStatus,
  sendChatMessageAlert,
};
