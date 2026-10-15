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
  const storeName =
    orderPayload.storeName ||
    (orderPayload.storeDetails && orderPayload.storeDetails.name) ||
    'Store';

  const dropAddress =
    orderPayload.dropAddress ||
    (orderPayload.deliveryAddress && orderPayload.deliveryAddress.address) ||
    'Customer Location';

  const customerFee = Number(
    orderPayload.deliveryFee !== undefined && orderPayload.deliveryFee !== null
      ? orderPayload.deliveryFee
      : orderPayload.deliveryCharge !== undefined && orderPayload.deliveryCharge !== null
      ? orderPayload.deliveryCharge
      : orderPayload.estimatedPayout || 0
  );
  const fee = Math.max(40, customerFee);

  return sendToToken(fcmToken, {
    title: '🚨 New Delivery Order Available!',
    body: `Earn ₹${fee} · Pick up from ${storeName} to ${dropAddress}`,
    channelId: 'rider_order_alerts_v2',
    sound: 'alert',
    priority: 'high',
    data: {
      type: 'order_dispatch',
      orderId: orderPayload.orderId || '',
      storeName: storeName,
      dropAddress: dropAddress,
      fee: String(fee),
      countdownSecs: String(orderPayload.countdownSecs || 30),
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

module.exports = {
  isReady: () => fcmMessaging !== null,
  sendToToken,
  sendToRiderOrderAlert,
  sendToStoreNewOrder,
  sendToCitizenOrderStatus,
};
