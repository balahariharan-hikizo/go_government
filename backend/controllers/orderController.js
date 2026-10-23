const Order = require('../models/Order');
const Store = require('../models/Store');
const User = require('../models/User');
const Rider = require('../models/Rider');
const Product = require('../models/Product');
const WalletTransaction = require('../models/WalletTransaction');
const fcmService = require('../services/fcmService');
const { getNextSequence } = require('../utils/sequenceGenerator');
const { createNotification } = require('./notificationController');
const { sendOrderAssignedAlerts, sendOrderStatusUpdateAlerts } = require('../utils/orderNotificationHelper');
const {
  calculateOrderTotals,
  resolveStoreCoordinates,
  processOrderPayment,
  decrementProductStock,
  dispatchOrderAlerts,
} = require('../utils/orderCreationHelper');
const {
  restockOrderItems,
  settleReturnFinances,
  releaseRider,
  dispatchReturnConfirmedAlerts,
  processStoreReverseFee,
  dispatchReversePickupAlerts,
} = require('../utils/orderReturnHelper');
const {
  handleOrderCancellation,
  handleOrderDeliveredSettlement,
} = require('../utils/orderStatusHelper');


// 1. CREATE NEW ORDER (Citizen Placement)
exports.createOrder = async (req, res) => {
  try {
    const {
      userId,
      storeId,
      storeName,
      items,
      paymentMethod = 'Cash on Delivery',
      deliveryAddress,
      storeDetails,
    } = req.body;

    if (!userId || !storeId || !items || items.length === 0) {
      return res.status(400).json({
        success: false,
        message: 'userId, storeId, and items are required',
      });
    }

    // 1. Server-side totals & parallel store/sequence resolution
    const totals = calculateOrderTotals(req.body);

    const [resolvedStoreDetails, orderId] = await Promise.all([
      resolveStoreCoordinates(storeId, storeDetails),
      getNextSequence('orderId', 'ORD_', 5),
    ]);

    const finalStoreName = (storeName && storeName.trim().length > 0)
      ? storeName.trim()
      : (resolvedStoreDetails.name || 'Store Order');

    // 2. Process wallet / non-wallet payment transaction
    const payment = await processOrderPayment({
      userId,
      orderId,
      amount: totals.grandTotal,
      paymentMethod,
      storeName: finalStoreName,
    });

    if (!payment.success) {
      return res.status(400).json(payment.errorResponse);
    }

    // 3. Persist new order
    const newOrder = new Order({
      orderId,
      userId,
      storeId,
      storeName: finalStoreName,
      items,
      itemTotal: totals.itemTotal,
      deliveryCharge: totals.deliveryCharge,
      handlingCharge: totals.handlingCharge,
      couponDiscount: totals.couponDiscount,
      coinsDiscount: totals.coinsDiscount,
      grandTotal: totals.grandTotal,
      paymentMethod,
      paymentStatus: paymentMethod.toLowerCase().includes('cash') ? 'pending' : 'paid',
      deliveryAddress: deliveryAddress || { address: 'Default Delivery Address' },
      storeDetails: resolvedStoreDetails,
      status: 'placed',
    });

    await newOrder.save();

    // 4. In-App Notification to Citizen
    createNotification({
      userId,
      title: 'Order Placed Successfully',
      message: `Your order #${orderId} has been placed at ${finalStoreName} (₹${totals.grandTotal}).`,
      type: 'order',
      referenceId: orderId,
      metadata: { storeName: finalStoreName, grandTotal: totals.grandTotal },
    }).catch((e) => console.warn('Notification error:', e.message));

    // 5. Parallel stock decrement
    await decrementProductStock(items);

    console.log(`📦 [Order Placed] Order ID: ${orderId} by User: ${userId} for Store: ${storeId}`);

    // 6. Socket broadcast, nearest rider dispatch & store FCM alert
    dispatchOrderAlerts(req.app, newOrder, resolvedStoreDetails);

    return res.status(201).json({
      success: true,
      message: 'Order placed successfully',
      data: newOrder,
      order: newOrder,
    });
  } catch (error) {
    console.error('Error creating order:', error);
    return res.status(500).json({ success: false, message: 'Failed to create order', error: error.message });
  }
};

// 2. GET ALL ORDERS (Admin Monitoring)
exports.getAllOrders = async (req, res) => {
  try {
    const orders = await Order.find({}).sort({ createdAt: -1 });
    return res.status(200).json({ success: true,
      totalOrders: orders.length, data: orders });
  } catch (error) {
    console.error('Error fetching all orders:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch all orders', error: error.message });
  }
};

// 3. GET LIVE RIDER GPS LOCATIONS
exports.getLiveRiderLocations = async (req, res) => {
  try {
    const riderRegistry = req.app.get('riderRegistry') || new Map();

    const dbRiders = await Rider.find({});
    const now = Date.now();
    const ridersMap = new Map();

    for (const r of dbRiders) {
      ridersMap.set(r.riderId, {
        riderId: r.riderId,
        name: r.name || 'Delivery Partner',
        phone: r.phone || '',
        vehicleType: r.vehicleType || 'Motorcycle',
        vehicleNumber: r.vehicleNumber || '',
        latitude: r.currentLocation?.lat || 0,
        longitude: r.currentLocation?.lng || 0,
        isOnline: r.isOnline || false,
        socketId: null,
        lastSeenSecondsAgo: null,
        isActiveGps: false,
      });
    }

    // Merge live in-memory socket registry data
    for (const [rId, info] of riderRegistry.entries()) {
      if (!rId) continue;
      let entry = ridersMap.get(rId);
      if (!entry) {
        for (const candidate of ridersMap.values()) {
          if (candidate.phone && candidate.phone === rId) {
            entry = candidate;
            break;
          }
        }
      }

      if (!entry) {
        entry = {
          riderId: rId,
          name: 'Express Rider (' + rId + ')',
          phone: rId,
          vehicleType: 'Motorcycle',
          vehicleNumber: '',
          latitude: 0,
          longitude: 0,
          isOnline: false,
          socketId: null,
          lastSeenSecondsAgo: null,
          isActiveGps: false,
        };
        ridersMap.set(rId, entry);
      }

      const lastSeenSecs = info.lastSeen ? Math.round((now - info.lastSeen) / 1000) : null;
      const hasPos = info.lat !== undefined && info.lat !== 0 && info.lng !== undefined && info.lng !== 0;
      const isActiveGps = Boolean(info.isOnline && hasPos && (lastSeenSecs === null || lastSeenSecs < 120));

      entry.latitude = info.lat || entry.latitude || 0;
      entry.longitude = info.lng || entry.longitude || 0;
      entry.isOnline = Boolean(info.isOnline);
      entry.socketId = info.socketId || null;
      entry.lastSeenSecondsAgo = lastSeenSecs;
      entry.isActiveGps = isActiveGps;
    }

    const ridersList = Array.from(ridersMap.values());
    return res.status(200).json({
      success: true,
      count: ridersList.length,
      riders: ridersList,
    });
  } catch (error) {
    console.error('Error fetching live rider locations:', error);
    return res.status(500).json({ success: false, error: error.message });
  }
};

// 4. GET CITIZEN ORDERS
exports.getUserOrders = async (req, res) => {
  try {
    const { userId } = req.params;
    let queryUsers = [userId];
    const userDoc = await User.findOne({
      $or: [{ userId }, { phone: userId }],
    }).select('userId phone').lean();
    if (userDoc) {
      if (userDoc.userId && !queryUsers.includes(userDoc.userId)) queryUsers.push(userDoc.userId);
      if (userDoc.phone && !queryUsers.includes(userDoc.phone)) queryUsers.push(userDoc.phone);
    }
    const orders = await Order.find({ userId: { $in: queryUsers } }).sort({ createdAt: -1 });

    return res.status(200).json({ success: true,totalOrders: orders.length,data: orders });
  } catch (error) {
    console.error('Error fetching user orders:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch user orders', error: error.message });
  }
};

// 5. GET STORE ORDERS (Merchant Dashboard Metrics)
exports.getStoreOrders = async (req, res) => {
  try {
    const { storeId } = req.params;
    const [orders, storeDoc] = await Promise.all([
      Order.find({ storeId }).sort({ updatedAt: -1, createdAt: -1 }),
      Store.findOne({ $or: [{ storeId }, { phone: storeId }] }).select('walletBalance name status bankDetails'),
    ]);

    let totalSubsidyDisbursed = 0;
    let pendingSubsidyPayout = 0;
    let deliveredGrossSales = 0;
    let totalDeliveryCharges = 0;
    let netStoreEarnings = 0;
    let activeOrdersCount = 0;
    let deliveredOrdersCount = 0;
    let returnedOrdersCount = 0;
    let cancelledOrdersCount = 0;
    let totalRefundAmount = 0;

    for (const order of orders) {
      if (order.status === 'cancelled') {
        cancelledOrdersCount++;
        continue;
      }

      if (['returned_to_store', 'returning_to_store', 'return_pickup_pending', 'return_pickup_assigned'].includes(order.status)) {
        returnedOrdersCount++;
        totalRefundAmount += (Number(order.returnDetails?.refundAmount) || 0);
      }

      let orderSubsidy = 0;
      if (Array.isArray(order.items)) {
        for (const it of order.items) {
          const orig = it.originalPrice ? Number(it.originalPrice) : 0;
          const pr = it.price ? Number(it.price) : 0;
          const qty = it.quantity ? Number(it.quantity) : 1;
          if (orig > pr) {
            orderSubsidy += (orig - pr) * qty;
          }
        }
      }

      totalSubsidyDisbursed += orderSubsidy;

      if (['placed', 'preparing', 'ready_for_pickup', 'accepted', 'out_for_delivery'].includes(order.status)) {
        activeOrdersCount++;
      }

      if (order.status === 'delivered') {
        deliveredOrdersCount++;
        pendingSubsidyPayout += orderSubsidy;
        const grand = Number(order.grandTotal) || 0;
        const del = Number(order.deliveryCharge) || 0;
        deliveredGrossSales += grand;
        totalDeliveryCharges += del;
        netStoreEarnings += Math.max(0, grand - del);
      }
    }

    return res.status(200).json({
      success: true,
      totalOrders: orders.length,
      data: orders,
      summary: {
        totalOrders: orders.length,
        activeOrdersCount,
        deliveredOrdersCount,
        returnedOrdersCount,
        cancelledOrdersCount,
        walletBalance: storeDoc?.walletBalance ?? 0,
        totalSubsidyDisbursed: Math.round(totalSubsidyDisbursed),
        pendingSubsidyPayout: Math.round(pendingSubsidyPayout),
        deliveredGrossSales: Math.round(deliveredGrossSales),
        totalGrossSales: Math.round(deliveredGrossSales), // Aligned with delivered sales so merchant sees consistent numbers
        totalDeliveryCharges: Math.round(totalDeliveryCharges),
        netStoreEarnings: Math.round(netStoreEarnings),
        totalRefundAmount: Math.round(totalRefundAmount),
      },
    });
  } catch (error) {
    console.error('Error fetching store orders:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch store orders', error: error.message });
  }
};

// 6. GET AVAILABLE DELIVERIES (Rider Pool)
exports.getAvailableDeliveries = async (req, res) => {
  try {
    const orders = await Order.find({
      status: { $in: ['placed', 'preparing', 'ready_for_pickup', 'return_pickup_pending'] },
      $or: [
        { 'deliveryAgent.riderId': '' },
        { 'deliveryAgent.riderId': { $exists: false } },
        { 'deliveryAgent.riderId': null },
      ],
    }).sort({ createdAt: -1 });

    return res.status(200).json({ success: true, count: orders.length, data: orders });
  } catch (error) {
    console.error('Error fetching available orders:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch available deliveries', error: error.message });
  }
};

// 7. GET RIDER DELIVERIES
exports.getRiderDeliveries = async (req, res) => {
  try {
    const { riderId } = req.params;
    let queryRiders = [riderId];
    const riderDoc = await Rider.findOne({
      $or: [{ riderId }, { phone: riderId }],
    }).select('riderId phone').lean();
    if (riderDoc) {
      if (riderDoc.riderId && !queryRiders.includes(riderDoc.riderId)) queryRiders.push(riderDoc.riderId);
      if (riderDoc.phone && !queryRiders.includes(riderDoc.phone)) queryRiders.push(riderDoc.phone);
    }

    const orders = await Order.find({
      'deliveryAgent.riderId': { $in: queryRiders },
      status: { $nin: ['return_requested', 'return_rejected', 'return_pickup_pending'] },
    }).sort({ createdAt: -1 });
    return res.status(200).json({ success: true, count: orders.length, data: orders });
  } catch (error) {
    console.error('Error fetching rider deliveries:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch rider deliveries', error: error.message });
  }
};

// 8. GET SINGLE ORDER DETAILS
exports.getOrderDetails = async (req, res) => {
  try {
    const { orderId } = req.params;
    const order = await Order.findOne({ orderId });

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const orderObj = order.toObject ? order.toObject() : JSON.parse(JSON.stringify(order));
    if (orderObj.storeId) {
      const storeDoc = await Store.findOne({ storeId: orderObj.storeId });
      if (storeDoc && storeDoc.name) {
        if (!orderObj.storeDetails) orderObj.storeDetails = {};
        if (
          !orderObj.storeDetails.name ||
          orderObj.storeDetails.name === 'Bangalore Horticulture' ||
          orderObj.storeDetails.name === 'Apothecary Pharmacy'
        ) {
          orderObj.storeDetails.name = storeDoc.name;
        }
        if (!orderObj.storeDetails.address && storeDoc.address) {
          orderObj.storeDetails.address = storeDoc.address;
        }
        if (!orderObj.storeDetails.phone && storeDoc.phone) {
          orderObj.storeDetails.phone = storeDoc.phone;
        }
      }
    }

    return res.status(200).json({ success: true, data: orderObj });
  } catch (error) {
    console.error('Error fetching order details:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch order', error: error.message });
  }
};

// 8b. GET ORDER CHAT HISTORY
exports.getOrderChat = async (req, res) => {
  try {
    const { orderId } = req.params;
    const order = await Order.findOne({ orderId }).select('chatMessages').lean();
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }
    return res.status(200).json({
      success: true,
      data: order.chatMessages || [],
    });
  } catch (error) {
    console.error('Error fetching order chat history:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch chat history', error: error.message });
  }
};

// 9. RIDER ACCEPTS DELIVERY TASK (Concurrency & Race Protected with Citizen Virtual Populate)
exports.acceptOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { riderId } = req.body;

    if (!riderId) {
      return res.status(400).json({ success: false, message: 'riderId is required' });
    }

    // 1. Fetch official verified rider details from database using riderId
    const rider = await Rider.findOne({ $or: [{ riderId }, { phone: riderId }] });
    if (!rider) {
      return res.status(404).json({ success: false, message: 'Rider not found in system' });
    }

    const assignedRiderId = rider.riderId;
    const assignedName = rider.name || req.body.name || 'Delivery Partner';
    const assignedPhone = rider.phone || req.body.phone || '';
    const assignedVehicle = rider.vehicleNumber || req.body.vehicleNumber || '';
    const assignedRating = Number(rider.rating || req.body.rating) || 4.9;

    const order = await Order.findOneAndUpdate(
      {
        orderId,
        $or: [
          { 'deliveryAgent.riderId': '' },
          { 'deliveryAgent.riderId': { $exists: false } },
          { 'deliveryAgent.riderId': null },
        ],
      },
      [
        {
          $set: {
            'deliveryAgent.riderId': assignedRiderId,
            'deliveryAgent.name': assignedName,
            'deliveryAgent.phone': assignedPhone,
            'deliveryAgent.vehicleNumber': assignedVehicle,
            'deliveryAgent.rating': assignedRating,
            status: {
              $cond: {
                if: { $eq: ['$status', 'return_pickup_pending'] },
                then: 'return_pickup_assigned',
                else: 'accepted',
              },
            },
          },
        },
      ],
      { updatePipeline: true, returnDocument: 'after' }
    ).populate('citizen', 'fcmToken name').populate('store', 'fcmToken name');

    // 3. Conflict / Already Claimed Handling
    if (!order) {
      return res.status(409).json({
        success: false,
        code: 'ALREADY_ACCEPTED',
        message: 'This delivery task has already been accepted or is unavailable.',
      });
    }

    console.log(`🚴 [Rider Assigned] Rider ${assignedName} (${assignedRiderId}) accepted order ${orderId} (${order.status})`);

    // 5. Mark Rider as Busy in Live Registry (RAM) & Database (MongoDB)
    const riderRegistry = req.app.get('riderRegistry');
    if (riderRegistry && riderRegistry.has(assignedRiderId)) {
      riderRegistry.get(assignedRiderId).isBusy = true;
    }
    await Rider.updateOne({ riderId: assignedRiderId }, { $set: { isBusy: true } });

    // 6. Clean Socket Broadcast & Citizen Push Notifications
    sendOrderAssignedAlerts(order, req.app);

    return res.status(200).json({
      success: true,
      message: 'Delivery accepted successfully',
      data: order,
    });
  } catch (error) {
    console.error('Error accepting delivery:', error);
    return res.status(500).json({ success: false, message: 'Failed to accept delivery', error: error.message });
  }
};

// 10. UPDATE ORDER STATUS (State Machine)
exports.updateOrderStatus = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { status } = req.body;

    const validStatuses = ['placed', 'preparing', 'ready_for_pickup', 'accepted', 'out_for_delivery', 'delivered', 'cancelled', 'return_requested', 'return_pickup_pending', 'return_pickup_assigned', 'returning_to_store', 'returned_to_store'];
    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Invalid status. Must be one of: ${validStatuses.join(', ')}`,
      });
    }

    const existing = await Order.findOne({ orderId });
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    // Order cancellation validation
    if (status === 'cancelled') {
      const nonCancellable = ['delivered', 'return_requested', 'return_pickup_pending', 'return_pickup_assigned', 'returning_to_store', 'returned_to_store'];
      if (nonCancellable.includes(existing.status)) {
        return res.status(400).json({
          success: false,
          message: `Cannot cancel an order in '${existing.status}' status. Delivered orders must proceed through the reverse return flow.`,
        });
      }
    }

    const updateFields = { status };
    if (status === 'delivered') {
      updateFields.deliveredAt = new Date();
      updateFields.paymentStatus = 'paid';
    }

    // 1. Order cancellation restock & citizen wallet refund
    if (status === 'cancelled' && existing.status !== 'cancelled') {
      await handleOrderCancellation(existing, updateFields);
    }

    // 2. Order delivered payouts & store net sales settlement
    if (status === 'delivered' && existing.status !== 'delivered') {
      await handleOrderDeliveredSettlement(existing);
    }

    const order = await Order.findOneAndUpdate(
      { orderId },
      { $set: updateFields },
      { returnDocument: 'after', runValidators: true }
    )
      .populate('citizen', 'fcmToken')
      .populate('store', 'fcmToken');

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    console.log(`🔄 [Order Status Updated] Order ${orderId} -> ${status}`);

    // Real-time Sockets, Citizen FCM Push, and In-App Notifications
    sendOrderStatusUpdateAlerts(order, req.app);

    return res.status(200).json({
      success: true,
      message: `Order status updated to ${status}`,
      data: order,
    });
  } catch (error) {
    console.error('Error updating order status:', error);
    const statusCode = error.name === 'ValidationError' ? 400 : 500;
    return res.status(statusCode).json({ success: false, message: 'Failed to update order status', error: error.message });
  }
};

// 10. RIDER DOORSTEP RETURN (Rider marks customer unavailable or doorstep rejection)
exports.initiateRiderReturn = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { riderId, reason, notes, proofImage } = req.body;

    const order = await Order.findOne({ orderId });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    if (!['accepted', 'out_for_delivery'].includes(order.status)) {
      return res.status(400).json({
        success: false,
        message: `Cannot initiate return for order with status '${order.status}'`,
      });
    }

    order.status = 'returning_to_store';
    order.returnDetails = {
      returnType: 'rider_doorstep',
      reason: reason || 'Customer Unavailable / Return to Store',
      notes: notes || '',
      proofImage: proofImage || '',
      initiatedBy: riderId || order.deliveryAgent?.riderId || '',
      requestedAt: new Date(),
      restocked: false,
    };

    await order.save();

    const io = req.app.get('io');
    if (io) {
      const orderPayload = order.toObject ? order.toObject() : order;
      io.emit(`order:${orderId}:status_update`, orderPayload);
      io.emit('order:status_update', orderPayload);
      io.emit('order:status_updated', orderPayload);
      io.to(`store:${order.storeId}`).emit('order:return_initiated', orderPayload);
      if (order.deliveryAgent?.riderId) {
        io.to(`rider:${order.deliveryAgent.riderId}`).emit('order:return_initiated', orderPayload);
      }
    }

    console.log(`📦↩️ [Rider Return Initiated] Order ${orderId} -> returning to store ${order.storeId}. Reason: ${reason}`);

    // High-Priority Push Notification to Citizen
    User.findOne({ $or: [{ userId: order.userId }, { phone: order.userId }] })
      .select('fcmToken')
      .then((citizen) => {
        if (citizen?.fcmToken) {
          fcmService.sendToCitizenOrderStatus(
            citizen.fcmToken,
            '🔄 Package Returning to Store',
            `Delivery for order #${orderId} could not be completed (${reason || 'Doorstep delivery failed'}). Package is returning to the store.`,
            orderId
          );
        }
      })
      .catch((err) => console.warn('Citizen return FCM error:', err.message));

    // In-App Notification to Citizen
    if (order.userId) {
      createNotification({
        userId: order.userId,
        title: 'Order Returning to Store',
        message: `Delivery for order #${orderId} could not be completed (${reason || 'Doorstep delivery failed'}). Package is returning to store.`,
        type: 'order',
        referenceId: orderId,
        metadata: { status: order.status, reason },
      }).catch((e) => console.warn('Notification error:', e.message));
    }

    return res.status(200).json({
      success: true,
      message: 'Return initiated. Please deliver package back to store.',
      data: order,
    });
  } catch (error) {
    console.error('Error initiating rider return:', error);
    return res.status(500).json({ success: false, message: 'Failed to initiate return', error: error.message });
  }
};

// 11. STORE CONFIRM RETURN & RESTOCK (Store receives return from Rider, confirms & refunds)
exports.storeConfirmReturn = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { storeId, condition, notes } = req.body;

    const order = await Order.findOne({ orderId });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const validConfirmStatuses = ['returning_to_store', 'return_pickup_assigned', 'return_requested'];
    if (!validConfirmStatuses.includes(order.status)) {
      return res.status(400).json({
        success: false,
        message: `Order status is '${order.status}', expected one of: ${validConfirmStatuses.join(', ')}`,
      });
    }

    order.status = 'returned_to_store';
    order.returnDetails.receivedAt = new Date();
    order.returnDetails.notes = notes || order.returnDetails.notes || '';

    // 1. Parallel inventory restock
    await restockOrderItems(order.items);
    order.returnDetails.restocked = true;

    // 2. Financial Settlement (Citizen refund, Rider payout, Store clawback)
    const { refundTxId } = await settleReturnFinances(order);

    // 3. Free up rider in registry & database
    const riderId = order.deliveryAgent?.riderId;
    if (riderId) {
      await releaseRider(req.app, riderId);
    }

    await order.save();

    // 4. Multi-party Socket broadcast, citizen push & in-app notification
    dispatchReturnConfirmedAlerts(req.app, order, refundTxId);

    return res.status(200).json({
      success: true,
      message: 'Return confirmed, items restocked, and customer refund processed!',
      data: order,
    });
  } catch (error) {
    console.error('Error confirming store return:', error);
    return res.status(500).json({ success: false, message: 'Failed to confirm return', error: error.message });
  }
};

// 12. CITIZEN REQUEST RETURN (Citizen requests return on delivered order)
exports.citizenRequestReturn = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { userId, reason, notes, proofImage } = req.body;

    const order = await Order.findOne({ orderId });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    if (order.status !== 'delivered') {
      return res.status(400).json({
        success: false,
        message: 'Return can only be requested for delivered orders',
      });
    }

    order.status = 'return_requested';
    const previousRiderId = order.deliveryAgent?.riderId || '';
    order.returnDetails = {
      returnType: 'citizen_request',
      reason: reason || 'Item Defective / Wrong Item',
      notes: notes || '',
      proofImage: proofImage || '',
      initiatedBy: userId || order.userId,
      originalDeliveryRiderId: previousRiderId,
      requestedAt: new Date(),
      restocked: false,
    };
    // Decouple original delivering rider so it never appears in rider active orders before store review
    order.deliveryAgent = {
      riderId: '',
      name: '',
      phone: '',
      vehicleNumber: '',
      rating: 4.9,
    };

    await order.save();

    const io = req.app.get('io');
    if (io) {
      const payload = {
        orderId: order.orderId,
        status: order.status,
        returnDetails: order.returnDetails,
        storeId: order.storeId,
      };
      io.emit(`order:${order.orderId}:status_update`, payload);
      io.to(`store:${order.storeId}`).emit('order:return_requested', payload);
      io.to(`store:${order.storeId}`).emit('order:status_update', payload);
    }

    console.log(`🙋 [Citizen Return Requested] Order ${orderId} by user ${userId}. Reason: ${reason}`);

    // In-App Notification to Citizen
    if (order.userId) {
      createNotification({
        userId: order.userId,
        title: 'Return Request Submitted',
        message: `Your return request for order #${orderId} was submitted to ${order.storeName || 'Store'} for review.`,
        type: 'order',
        referenceId: orderId,
        metadata: { status: order.status, reason },
      }).catch((e) => console.warn('Notification error:', e.message));
    }

    // In-App Notification & Push Alert to STORE
    if (order.storeId) {
      createNotification({
        userId: order.storeId,
        title: '⚠️ Return Request Received',
        message: `Customer requested return for Order #${orderId} (Reason: ${reason || 'Item Defective / Wrong Item'}). Tap to review and take action.`,
        type: 'order',
        referenceId: orderId,
        metadata: { status: order.status, reason: reason || '', notes: notes || '' },
      }).catch((e) => console.warn('Store notification error:', e.message));

      Store.findOne({ storeId: order.storeId }).then((storeDoc) => {
        if (storeDoc && storeDoc.fcmToken) {
          fcmService.sendToStoreReturnAlert(storeDoc.fcmToken, order).catch((e) =>
            console.warn('FCM store return push error:', e.message)
          );
        }
      }).catch((e) => console.warn('Store lookup error:', e.message));
    }

    return res.status(200).json({
      success: true,
      message: 'Return request submitted to store for review.',
      data: order,
    });
  } catch (error) {
    console.error('Error requesting citizen return:', error);
    return res.status(500).json({ success: false, message: 'Failed to submit return request', error: error.message });
  }
};

// 13. STORE REVIEW CITIZEN RETURN (Store Approves or Rejects Citizen Return Request)
exports.storeReviewCitizenReturn = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { storeId, action, rejectionReason } = req.body; // action: 'approve' | 'reject'

    const order = await Order.findOne({ orderId });
    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    if (order.status !== 'return_requested') {
      return res.status(400).json({
        success: false,
        message: `Order status is '${order.status}', expected 'return_requested'`,
      });
    }

    if (action === 'approve') {
      const reverseFee = 35; // Standard reverse delivery logistics fee paid by store to rider
      order.status = 'return_pickup_pending';
      order.returnDetails.reverseDeliveryFee = reverseFee;
      // Reset deliveryAgent so available riders can accept reverse pickup
      order.deliveryAgent = {
        riderId: '',
        name: '',
        phone: '',
        vehicleNumber: '',
        rating: 4.9,
      };

      // 1. Deduct reverse delivery fee from Store Wallet
      await processStoreReverseFee(order.storeId, order.orderId);
    } else {
      order.status = 'return_rejected';
      order.returnDetails.rejectionReason = rejectionReason || 'Store rejected return request';
    }

    await order.save();

    const io = req.app.get('io');
    if (io) {
      const orderPayload = order.toObject ? order.toObject() : order;
      io.emit('order:status_updated', orderPayload);
      io.emit('order:status_update', orderPayload);
      io.emit(`order:${orderId}:status_update`, orderPayload);

      if (action === 'approve') {
        dispatchReversePickupAlerts(req.app, order);
      }
    }

    console.log(`⚖️ [Return Reviewed] Order ${orderId} -> ${action.toUpperCase()}`);

    // In-App Notification to Citizen
    if (order.userId) {
      const isApproved = action === 'approve';
      createNotification({
        userId: order.userId,
        title: isApproved ? 'Return Request Approved · Pickup Scheduled' : 'Return Request Rejected',
        message: isApproved
          ? `Your return request for order #${orderId} was approved! A rider is being assigned to collect the items from your doorstep. Full refund will be finalized once returned.`
          : `Your return request for order #${orderId} was not accepted: ${rejectionReason || 'Store rejected return request'}.`,
        type: 'order',
        referenceId: orderId,
        metadata: { status: order.status, action, rejectionReason },
      }).catch((e) => console.warn('Notification error:', e.message));

      if (isApproved && order.storeId) {
        createNotification({
          userId: order.storeId,
          title: 'Return Approved · Rider Dispatched',
          message: `Return approved for order #${orderId}. ₹35 reverse delivery fee deducted. A delivery partner is being assigned for doorstep collection.`,
          type: 'order',
          referenceId: orderId,
          metadata: { status: order.status, reverseDeliveryFee: 35 },
        }).catch((e) => console.warn('Store notification error:', e.message));
      }
    }

    return res.status(200).json({
      success: true,
      message: action === 'approve' ? 'Return approved! ₹35 reverse pickup fee deducted and rider pickup dispatched.' : 'Return rejected',
      data: order,
    });
  } catch (error) {
    console.error('Error reviewing return:', error);
    return res.status(500).json({ success: false, message: 'Failed to review return', error: error.message });
  }
};
