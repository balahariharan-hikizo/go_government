const fcmService = require('../services/fcmService');
const User = require('../models/User');
const Rider = require('../models/Rider');
const Order = require('../models/Order');

// ─── Rider GPS Registry (in-memory, no DB overhead) ──────────────────────────
// { riderId: { lat, lng, socketId, isOnline, lastSeen } }
const riderRegistry = new Map();

// Active dispatch timers: { orderId → { timer, round, dispatchedIds } }
const dispatchTimers = new Map();

// Haversine distance formula (returns km)
function haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLng = ((lng2 - lng1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

/**
 * Find nearest online riders to a given store location.
 * @param {number} storeLat
 * @param {number} storeLng
 * @param {number} radiusKm  - max radius
 * @param {number} limit     - max riders to return
 * @param {string[]} excludeIds - riderIds already dispatched in earlier rounds
 */
function findNearestRiders(storeLat, storeLng, radiusKm, limit, excludeIds = []) {
  const candidates = [];
  const now = Date.now();
  for (const [riderId, info] of riderRegistry.entries()) {
    if (!info.isOnline || !info.socketId) continue;
    // Skip riders who already have an active delivery
    if (info.isBusy) continue;
    // Must have active non-zero GPS signal pinged within last 2 minutes (120,000 ms)
    if (info.lat === 0 && info.lng === 0) continue;
    if (info.lastSeen && now - info.lastSeen > 120000) continue;
    if (excludeIds.includes(riderId)) continue;
    const dist = haversineKm(storeLat, storeLng, info.lat, info.lng);
    if (dist <= radiusKm) {
      candidates.push({ riderId, socketId: info.socketId, dist });
    }
  }
  candidates.sort((a, b) => a.dist - b.dist);
  return candidates.slice(0, limit);
}

/**
 * Dispatch an order to nearby riders, with automatic escalation.
 * Round 1: 3 nearest within 2km  (30s timeout)
 * Round 2: 3 nearest within 6km  (30s timeout, excluding round-1 riders)
 * Round 3: broadcast to all online riders
 */
function dispatchOrder(io, orderPayload, storeLat, storeLng, round = 1, prevDispatchedIds = []) {
  const orderId = orderPayload.orderId;

  // Clear any existing timer for this order
  if (dispatchTimers.has(orderId)) {
    clearTimeout(dispatchTimers.get(orderId).timer);
  }

  let targets = [];
  if (round === 1) {
    targets = findNearestRiders(storeLat, storeLng, 2, 3, prevDispatchedIds);
  } else if (round === 2) {
    targets = findNearestRiders(storeLat, storeLng, 6, 3, prevDispatchedIds);
  }

  const dispatchedIds = [...prevDispatchedIds, ...targets.map((t) => t.riderId)];

  if (round <= 2 && targets.length > 0) {
    // Targeted dispatch — only selected riders
    for (const target of targets) {
      const targetPayload = {
        ...orderPayload,
        dispatchRound: round,
        dispatchDistKm: Math.round(target.dist * 10) / 10,
        countdownSecs: 30,
      };
      io.to(target.socketId).emit('order:dispatch', targetPayload);
      if (target.riderId) {
        io.to(`rider:${target.riderId}`).emit('order:dispatch', targetPayload);

        // Send FCM Wake-up Push (wakes sleeping/closed Rider App)
        Rider.findOne({ $or: [{ riderId: target.riderId }, { phone: target.riderId }] })
          .select('fcmToken')
          .then(async (riderDoc) => {
            const token = riderDoc?.fcmToken || (await User.findOne({ $or: [{ userId: target.riderId }, { phone: target.riderId }] }).select('fcmToken'))?.fcmToken;
            if (token) {
              fcmService.sendToRiderOrderAlert(token, targetPayload);
            }
          })
          .catch((err) => console.error('Error fetching rider FCM token:', err.message));
      }
    }
    console.log(
      `📡 [Dispatch R${round}] Order ${orderId} → ${targets.length} riders within ${round === 1 ? 2 : 6}km`
    );

    // Schedule escalation after 30 seconds
    const timer = setTimeout(() => {
      // Re-check if order is still unaccepted
      Order.findOne({ orderId }).then((order) => {
        const isClaimed = Boolean(order?.deliveryAgent?.riderId && order.deliveryAgent.riderId.trim().length > 0);
        if (!order || isClaimed || ['accepted', 'out_for_delivery', 'delivered', 'cancelled'].includes(order.status)) {
          console.log(`✅ [Dispatch] Order ${orderId} already claimed or inactive — no escalation needed`);
          dispatchTimers.delete(orderId);
          return;
        }
        const nextRound = round + 1;
        console.log(`⏱️ [Dispatch] No accept in 30s for order ${orderId} — escalating to round ${nextRound}`);
        dispatchOrder(io, orderPayload, storeLat, storeLng, nextRound, dispatchedIds);
      });
    }, 30000);

    dispatchTimers.set(orderId, { timer, round, dispatchedIds });
  } else {
    // Round 3 (or no riders nearby within 2km/6km) — broadcast ONLY to IDLE online riders
    const payload = {
      ...orderPayload,
      dispatchRound: 3,
      dispatchDistKm: null,
      countdownSecs: 30,
    };
    
    // Broadcast via socket ONLY to active, online and non-busy riders
    for (const [riderId, info] of riderRegistry.entries()) {
      if (info.isOnline && !info.isBusy && info.socketId) {
        io.to(info.socketId).emit('order:dispatch', payload);
      }
    }
    console.log(`📡 [Dispatch R3] Order ${orderId} → broadcast to idle online riders only`);

    // Broadcast FCM alert ONLY to riders who are actively ON DUTY (isOnline: true) AND NOT BUSY
    Rider.find({ isOnline: true, isBusy: { $ne: true }, fcmToken: { $ne: '' } })
      .select('fcmToken')
      .then((riders) => {
        for (const r of riders) {
          if (r.fcmToken) {
            fcmService.sendToRiderOrderAlert(r.fcmToken, payload);
          }
        }
      })
      .catch((err) => console.error('Error broadcasting rider FCM:', err.message));

    dispatchTimers.delete(orderId);
  }
}

/**
 * Initialize Socket.io connection handlers and expose dispatch engines
 * @param {Object} io - Socket.io Server instance
 * @param {Object} app - Express application instance
 */
function initSockets(io, app) {
  // Expose dispatch helpers so routes/controllers can call them via req.app.get(...)
  app.set('riderRegistry', riderRegistry);
  app.set('dispatchOrder', dispatchOrder);
  app.set('dispatchTimers', dispatchTimers);

  io.on('connection', (socket) => {
    console.log(`⚡ [Socket.io] Client connected: ${socket.id}`);

    // Store merchant joins store room for targeted alerts
    socket.on('join:store', (storeId) => {
      if (storeId) {
        socket.join(`store:${storeId}`);
        console.log(`🏪 [Socket.io] Socket ${socket.id} joined store room: store:${storeId}`);
      }
    });

    // Rider joins general riders dispatch room + registers in GPS registry
    socket.on('join:rider', async (riderId) => {
      socket.join('riders');
      if (riderId) socket.join(`rider:${riderId}`);
      socket.data.riderId = riderId;

      // Check rider's actual duty status from DB
      let isDutyOnline = false;
      let storedLat = 0;
      let storedLng = 0;
      if (riderId) {
        try {
          const rDoc = await Rider.findOne({ $or: [{ riderId }, { phone: riderId }] }).select('isOnline currentLocation');
          isDutyOnline = Boolean(rDoc?.isOnline);
          storedLat = rDoc?.currentLocation?.lat || 0;
          storedLng = rDoc?.currentLocation?.lng || 0;
        } catch (_) {}
      }

      if (isDutyOnline) {
        socket.join('online_riders');
      } else {
        socket.leave('online_riders');
      }

      // Register rider in GPS registry
      if (riderId && !riderRegistry.has(riderId)) {
        riderRegistry.set(riderId, {
          lat: storedLat, lng: storedLng, socketId: socket.id, isOnline: isDutyOnline, isBusy: false, lastSeen: Date.now(),
        });
      } else if (riderId) {
        const info = riderRegistry.get(riderId);
        if (info.disconnectTimer) {
          clearTimeout(info.disconnectTimer);
          info.disconnectTimer = null;
        }
        info.socketId = socket.id;
        info.isOnline = isDutyOnline;
        info.lastSeen = Date.now();
      }
      console.log(`🚴 [Socket.io] Socket ${socket.id} joined riders room (Rider: ${riderId}, isOnline: ${isDutyOnline})`);
    });

    // Rider GPS ping — updates in-memory registry (every 20-30s while online)
    socket.on('rider:location_ping', async (data) => {
      const { riderId, lat, lng, isOnline, bgPing } = data || {};
      if (!riderId) return;

      socket.data.riderId = riderId;
      socket.join('riders');
      socket.join(`rider:${riderId}`);

      const existing = riderRegistry.get(riderId) || {};

      if (existing.disconnectTimer) {
        clearTimeout(existing.disconnectTimer);
        existing.disconnectTimer = null;
      }

      // Explicit offline ping
      if (isOnline === false) {
        socket.leave('online_riders');
        riderRegistry.set(riderId, {
          ...existing,
          lat: 0,
          lng: 0,
          socketId: socket.id,
          isOnline: false,
          lastSeen: Date.now(),
        });
        console.log(`🛑 [Socket.io] Rider ${riderId} pinged OFFLINE (cleared GPS)`);
        return;
      }

      socket.join('online_riders');

      // Never overwrite valid existing coordinates with (0, 0)
      const hasZeroCoords = (lat === 0 || lat === null || lat === undefined) &&
                            (lng === 0 || lng === null || lng === undefined);

      riderRegistry.set(riderId, {
        ...existing,
        lat: (hasZeroCoords && existing.lat) ? existing.lat : (lat ?? existing.lat ?? 0),
        lng: (hasZeroCoords && existing.lng) ? existing.lng : (lng ?? existing.lng ?? 0),
        socketId: socket.id,
        isOnline: true,
        lastSeen: Date.now(),
      });
      // Ensure rider role is updated in DB
      try {
        await User.updateOne(
          { $or: [{ userId: riderId }, { phone: riderId }] },
          { $set: { role: 'rider' } }
        );
      } catch (_) {}
    });

    // Rider explicit logout event – also clear DB flag
    socket.on('rider:logout', async (data) => {
      const { riderId } = data || {};
      if (riderId && riderRegistry.has(riderId)) {
        const existing = riderRegistry.get(riderId);
        if (existing.disconnectTimer) clearTimeout(existing.disconnectTimer);
        // Update in-memory registry
        riderRegistry.set(riderId, {
          ...existing,
          lat: 0,
          lng: 0,
          isOnline: false,
          lastSeen: Date.now(),
        });
        // Persist offline status in MongoDB
        try {
          await Rider.updateOne(
            { $or: [{ riderId }, { phone: riderId }] },
            { $set: { isOnline: false } }
          );
        } catch (e) {
          console.error('Failed to set rider offline in DB on logout:', e.message);
        }
        console.log(`🚪 [Socket.io] Rider ${riderId} logged out & marked OFFLINE in registry & DB`);
      }
    });

    // Relay chat messages between citizen and rider
    socket.on('chat:send', async (message) => {
      if (message && message.orderId) {
        const msgId = message.id || `msg_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
        const senderRole = message.senderRole || 'citizen';
        const msgText = message.text || '';
        const msgTime = message.time || '';
        
        console.log(`💬 [Socket.io] Chat relay for order ${message.orderId} from ${senderRole} (id: ${msgId})`);

        // 1. Persist to MongoDB Order.chatMessages
        try {
          await Order.updateOne(
            { orderId: message.orderId },
            {
              $push: {
                chatMessages: {
                  id: msgId,
                  senderRole,
                  senderName: message.senderName || '',
                  text: msgText,
                  time: msgTime,
                  createdAt: new Date(),
                },
              },
            }
          );
        } catch (dbErr) {
          console.error('Failed to save chat message to Order:', dbErr.message);
        }

        // 2. Real-time socket broadcast to both participants (with unique msgId)
        const broadcastPayload = {
          ...message,
          id: msgId,
        };
        io.emit(`chat:${message.orderId}`, broadcastPayload);

        // 3. Background push notification fallback if recipient is minimized/locked
        try {
          const order = await Order.findOne({ orderId: message.orderId })
            .select('userId deliveryAgent deliveryAddress')
            .populate('citizen', 'fcmToken name')
            .lean();

          if (order) {
            let senderName = message.senderName;
            if (senderRole === 'citizen') {
              if (!senderName || senderName.toLowerCase() === 'citizen') {
                senderName = order.deliveryAddress?.receiverName || order.citizen?.name || 'Citizen';
              }
            } else if (senderRole === 'rider') {
              if (!senderName || senderName.toLowerCase() === 'delivery partner') {
                senderName = order.deliveryAgent?.name || 'Delivery Partner';
              }
            }

            const title = `💬 Message from ${senderName}`;
            const body = msgText || 'New message';

            if (senderRole === 'citizen') {
              // Message from Citizen -> notify Rider
              const riderId = order.deliveryAgent?.riderId;
              if (riderId) {
                const riderDoc = await Rider.findOne({ $or: [{ riderId }, { phone: riderId }] }).select('fcmToken').lean();
                if (riderDoc?.fcmToken) {
                  fcmService.sendChatMessageAlert(riderDoc.fcmToken, { title, body, orderId: message.orderId, senderRole });
                }
              }
            } else if (senderRole === 'rider') {
              // Message from Rider -> notify Citizen
              const citizenToken = order.citizen?.fcmToken;
              if (citizenToken) {
                fcmService.sendChatMessageAlert(citizenToken, { title, body, orderId: message.orderId, senderRole });
              } else if (order.userId) {
                const userDoc = await User.findOne({ $or: [{ userId: order.userId }, { phone: order.userId }] }).select('fcmToken').lean();
                if (userDoc?.fcmToken) {
                  fcmService.sendChatMessageAlert(userDoc.fcmToken, { title, body, orderId: message.orderId, senderRole });
                }
              }
            }
          }
        } catch (e) {
          console.warn('Chat notification error:', e.message);
        }
      }
    });

    // Relay rider live GPS coordinates to citizen
    socket.on('rider:location', (data) => {
      if (data && data.orderId) {
        io.emit(`order:${data.orderId}:rider_location`, data);
      }
    });

    socket.on('disconnect', () => {
      const riderId = socket.data.riderId;
      if (riderId && riderRegistry.has(riderId)) {
        const info = riderRegistry.get(riderId);
        // Give a 60-second grace period:
        // When rider minimizes the app or uses another app (Google Maps/WhatsApp),
        // the UI socket might disconnect before the background socket reconnects or pings.
        if (info.socketId === socket.id) {
          if (info.disconnectTimer) clearTimeout(info.disconnectTimer);
          info.disconnectTimer = setTimeout(async () => {
            if (info.socketId === socket.id) {
              info.isOnline = false;
              // Persist offline status in MongoDB
              try {
                await Rider.updateOne(
                  { $or: [{ riderId }, { phone: riderId }] },
                  { $set: { isOnline: false } }
                );
              } catch (e) {
                console.error('Failed to set rider offline in DB on disconnect:', e.message);
              }
              console.log(`🔴 [Socket.io] Rider ${riderId} marked OFFLINE after 60s disconnect grace period`);
            }
          }, 60000);
          console.log(`⏳ [Socket.io] Socket ${socket.id} disconnected for rider ${riderId} — starting 60s grace period (keeping ONLINE)`);
        } else {
          console.log(`⚡ [Socket.io] Stale socket ${socket.id} disconnected for rider ${riderId} — active socket still connected, keeping ONLINE`);
        }
      }
      console.log(`⚡ [Socket.io] Client disconnected: ${socket.id}`);
    });
  });
}

module.exports = {
  initSockets,
  riderRegistry,
  dispatchTimers,
  dispatchOrder,
  findNearestRiders,
  haversineKm,
};
