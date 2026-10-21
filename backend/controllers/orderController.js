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

// 1. CREATE NEW ORDER (Citizen Placement)
exports.createOrder = async (req, res) => {
  try {
    const {
      userId,
      storeId,
      storeName,
      items,
      itemTotal,
      deliveryCharge = 0,
      handlingCharge = 2,
      couponDiscount = 0,
      coinsDiscount = 0,
      grandTotal,
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

    // Server-Side Total Calculations
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

    const orderId = await getNextSequence('orderId', 'ORD_', 5);

    // Fetch Store Details & Coordinates
    let resolvedStoreDetails = storeDetails || {};
    const storeDoc = await Store.findOne({ storeId });
    if (storeDoc) {
      const realLat = (storeDoc.location && storeDoc.location.lat !== undefined)
        ? Number(storeDoc.location.lat)
        : (storeDoc.latitude || 0.0);
      const realLng = (storeDoc.location && storeDoc.location.lng !== undefined)
        ? Number(storeDoc.location.lng)
        : (storeDoc.longitude || 0.0);

      resolvedStoreDetails = {
        storeId: storeDoc.storeId,
        name: (storeDoc.name && storeDoc.name.trim().length > 0)
          ? storeDoc.name.trim()
          : (resolvedStoreDetails.name && !['Bangalore Horticulture', 'Apothecary Pharmacy'].includes(resolvedStoreDetails.name)
              ? resolvedStoreDetails.name
              : 'Store Order'),
        address: (storeDoc.address && storeDoc.address.trim().length > 0) ? storeDoc.address : (resolvedStoreDetails.address || ''),
        latitude: realLat,
        longitude: realLng,
        phone: storeDoc.phone || resolvedStoreDetails.phone || '',
      };
    } else {
      resolvedStoreDetails.latitude = resolvedStoreDetails.latitude || 0.0;
      resolvedStoreDetails.longitude = resolvedStoreDetails.longitude || 0.0;
    }

    const isWallet = paymentMethod && paymentMethod.toLowerCase().includes('wallet');
    const numGrandTotal = Number(finalGrandTotal);

    // Wallet balance deduction if selected
    if (isWallet) {
      const updatedUser = await User.findOneAndUpdate(
        {
          $or: [{ userId }, { phone: userId }],
          walletBalance: { $gte: numGrandTotal },
        },
        { $inc: { walletBalance: -numGrandTotal } },
        { new: true }
      );

      if (!updatedUser) {
        const currentUser = await User.findOne({ $or: [{ userId }, { phone: userId }] });
        const curBal = currentUser ? currentUser.walletBalance || 0 : 0;
        return res.status(400).json({
          success: false,
          code: 'INSUFFICIENT_WALLET_BALANCE',
          message: `Insufficient wallet balance. Total: ₹${numGrandTotal}, Available: ₹${curBal}`,
          walletBalance: curBal,
        });
      }

      // Record wallet debit transaction
      const now = new Date();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

      const walletTx = new WalletTransaction({
        transactionId: await getNextSequence('walletTxId', 'TXN_PAY_', 5),
        userId: updatedUser.userId,
        amount: -numGrandTotal,
        type: 'debit',
        category: 'order_payment',
        paymentMethod: 'Wallet Account',
        orderId: orderId,
        title: resolvedStoreDetails.name || 'Store Order',
        subtitle: `Paid for order #${orderId} · ${dateStr}`,
        balanceAfter: updatedUser.walletBalance,
        status: 'success',
      });
      await walletTx.save();
    }

    const finalStoreName = (storeName && storeName.trim().length > 0)
      ? storeName.trim()
      : (resolvedStoreDetails.name || (storeDoc && storeDoc.name) || 'Store');

    const newOrder = new Order({
      orderId,
      userId,
      storeId,
      storeName: finalStoreName,
      items,
      itemTotal: finalItemTotal,
      deliveryCharge: numDeliveryCharge,
      handlingCharge: numHandlingCharge,
      couponDiscount: numCouponDiscount,
      coinsDiscount: numCoinsDiscount,
      grandTotal: finalGrandTotal,
      paymentMethod,
      paymentStatus: paymentMethod.toLowerCase().includes('cash') ? 'pending' : 'paid',
      deliveryAddress: deliveryAddress || { address: 'Default Delivery Address' },
      storeDetails: resolvedStoreDetails,
      status: 'placed',
    });

    await newOrder.save();

    // Trigger In-App Notification for Citizen
    createNotification({
      userId,
      title: 'Order Placed Successfully',
      message: `Your order #${orderId} has been placed at ${finalStoreName} (₹${finalGrandTotal}).`,
      type: 'order',
      referenceId: orderId,
      metadata: { storeName: finalStoreName, grandTotal: finalGrandTotal },
    }).catch((e) => console.warn('Notification error:', e.message));

    // Decrement stock atomically (both base product and variant)
    for (const item of items) {
      const pId = item.productId || item.id;
      const vId = item.variantId;
      const qty = Number(item.quantity || item.qty || 1);
      if (pId && qty > 0) {
        if (vId) {
          await Product.updateOne(
            { productId: pId, 'variants.variantId': vId },
            { $inc: { 'variants.$.stock': -qty, stock: -qty } }
          ).catch((err) => console.warn(`⚠️ [Inventory] Could not decrement variant stock for ${pId}:${vId}:`, err.message));
        } else {
          await Product.updateOne(
            { productId: pId },
            { $inc: { stock: -qty } }
          ).catch((err) => console.warn(`⚠️ [Inventory] Could not decrement stock for product ${pId}:`, err.message));
        }
      }
    }

    // Record non-wallet ledger entry
    if (!isWallet) {
      const now = new Date();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

      const userDoc = await User.findOne({ userId }).select('walletBalance');
      const curWalletBal = userDoc?.walletBalance || 0;

      const walletTx = new WalletTransaction({
        transactionId: await getNextSequence('walletTxId', 'TXN_PAY_', 5),
        userId,
        amount: -numGrandTotal,
        type: 'debit',
        category: 'order_payment',
        paymentMethod: paymentMethod,
        orderId,
        title: resolvedStoreDetails.name || 'Store Order',
        subtitle: `Paid for order #${orderId} · ${dateStr}`,
        balanceAfter: curWalletBal,
        status: paymentMethod.toLowerCase().includes('cash') ? 'pending' : 'success',
      });
      await walletTx.save();
    }

    console.log(`📦 [Order Placed] Order ID: ${orderId} by User: ${userId} for Store: ${storeId}`);

    // Real-time Socket.io Notification to Merchant & Immediate Rider Dispatch (Option 1)
    const io = req.app.get('io');
    if (io) {
      const orderPayload = newOrder.toObject ? newOrder.toObject() : newOrder;
      io.to(`store:${storeId}`).emit(`store:${storeId}:new_order`, orderPayload);
      io.emit(`store:${storeId}:new_order`, orderPayload);
      console.log(`📡 [Socket.io] Emitted single targeted new_order for store: ${storeId} (Order: ${orderId})`);

      // ⚡ Immediate Parallel Rider Dispatch on Order Placement
      io.emit('order:available', orderPayload);
      io.to('riders').emit('order:available', orderPayload);

      const dispatchOrder = req.app.get('dispatchOrder');
      const storeLat = resolvedStoreDetails.latitude || 0;
      const storeLng = resolvedStoreDetails.longitude || 0;
      if (dispatchOrder && (storeLat !== 0 || storeLng !== 0)) {
        dispatchOrder(io, orderPayload, storeLat, storeLng, 1, []);
      } else {
        const payload = { ...orderPayload, dispatchRound: 3, countdownSecs: 30 };
        const registry = req.app.get('riderRegistry');
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
          const owner = await User.findOne({ phone: storeDoc.phone }).select('fcmToken');
          token = owner?.fcmToken;
        }
        if (token) {
          fcmService.sendToStoreNewOrder(token, newOrder);
        }
      })
      .catch((err) => console.error('Error sending store FCM:', err.message));

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
    });
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
    const orders = await Order.find({ storeId }).sort({ updatedAt: -1, createdAt: -1 });

    let totalSubsidyDisbursed = 0;
    let pendingSubsidyPayout = 0;
    let totalGrossSales = 0;
    let totalDeliveryCharges = 0;
    let netStoreEarnings = 0;
    let activeOrdersCount = 0;

    for (const order of orders) {
      if (order.status === 'cancelled') continue;

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
      totalGrossSales += (order.grandTotal || 0);

      if (['placed', 'preparing', 'ready_for_pickup', 'accepted', 'out_for_delivery'].includes(order.status)) {
        activeOrdersCount++;
      }

      if (order.status === 'delivered') {
        pendingSubsidyPayout += orderSubsidy;
        const grand = Number(order.grandTotal) || 0;
        const del = Number(order.deliveryCharge) || 0;
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
        totalSubsidyDisbursed: Math.round(totalSubsidyDisbursed),
        pendingSubsidyPayout: Math.round(pendingSubsidyPayout),
        totalGrossSales: Math.round(totalGrossSales),
        totalDeliveryCharges: Math.round(totalDeliveryCharges),
        netStoreEarnings: Math.round(netStoreEarnings),
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
    });
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

    // 3. Conflict / Not Found Handling (Only executed if order could not be claimed)
    if (!order) {
      const exists = await Order.exists({ orderId });
      if (!exists) {
        return res.status(404).json({ success: false, message: 'Order not found' });
      }
      return res.status(409).json({
        success: false,
        code: 'ALREADY_ACCEPTED',
        message: 'This delivery task has already been accepted and assigned.',
      });
    }

    console.log(`🚴 [Rider Assigned] Rider ${assignedName} (${assignedRiderId}) accepted order ${orderId} (${order.status})`);

    // 5. Mark Rider as Busy in Registry & DB (Non-blocking)
    req.app.get('riderRegistry')?.get(assignedRiderId) && (req.app.get('riderRegistry').get(assignedRiderId).isBusy = true);
    Rider.updateOne({ riderId: assignedRiderId }, { $set: { isBusy: true } }).catch(() => {});

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

    const updateFields = { status };
    if (status === 'delivered') {
      updateFields.deliveredAt = new Date();
      updateFields.paymentStatus = 'paid';
    }

    const existing = await Order.findOne({ orderId });
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    const now = new Date();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

    // Order cancellation handling
    if (status === 'cancelled') {
      const nonCancellable = ['delivered', 'return_requested', 'return_pickup_pending', 'return_pickup_assigned', 'returning_to_store', 'returned_to_store'];
      if (nonCancellable.includes(existing.status)) {
        return res.status(400).json({
          success: false,
          message: `Cannot cancel an order in '${existing.status}' status. Delivered orders must proceed through the reverse return flow.`,
        });
      }
    }

    if (status === 'cancelled' && existing.status !== 'cancelled') {
      // 1. Restore product inventory
      for (const item of (existing.items || [])) {
        const pId = item.productId || item.id;
        const qty = Number(item.quantity || item.qty || 1);
        if (pId && qty > 0) {
          await Product.updateOne({ productId: pId }, { $inc: { stock: qty } }).catch(() => {});
        }
      }

      // 2. Refund citizen wallet
      const wasWallet = existing.paymentMethod && existing.paymentMethod.toLowerCase().includes('wallet');
      if (wasWallet && existing.paymentStatus === 'paid') {
        const refundAmt = Number(existing.grandTotal) || 0;
        if (refundAmt > 0) {
          const refundedUser = await User.findOneAndUpdate(
            { $or: [{ userId: existing.userId }, { phone: existing.userId }] },
            { $inc: { walletBalance: refundAmt } },
            { new: true }
          );

          if (refundedUser) {
            const refundTx = new WalletTransaction({
              transactionId: await getNextSequence('walletTxId', 'TXN_REF_', 5),
              userId: refundedUser.userId,
              amount: refundAmt,
              type: 'credit',
              category: 'order_refund',
              paymentMethod: 'Wallet Refund',
              orderId: existing.orderId,
              title: 'Order Refund',
              subtitle: `Refund for cancelled order #${existing.orderId} · ${dateStr}`,
              balanceAfter: refundedUser.walletBalance,
              status: 'success',
            });
            await refundTx.save();
            updateFields.paymentStatus = 'refunded';
            console.log(`💳 [Auto Refund] Refunded ₹${refundAmt} to user ${refundedUser.userId}`);
          }
        }
      }
    }

    // Order delivered payouts
    if (status === 'delivered' && existing.status !== 'delivered') {
      const standardDeliveryFee = 35;
      const customerDeliveryCharge = Number(existing.deliveryCharge) || 0;
      // Way 2: If customer got Free Delivery (₹0), rider is guaranteed ₹35 sponsored by store high-value sale
      const riderFee = customerDeliveryCharge > 0 ? customerDeliveryCharge : standardDeliveryFee;

      // 1. Rider Payout (Always guaranteed at least ₹35)
      const riderId = existing.deliveryAgent?.riderId;
      if (riderId && riderFee > 0) {
        const updatedRider = await Rider.findOneAndUpdate(
          { $or: [{ riderId: riderId }, { phone: riderId }] },
          { $inc: { walletBalance: riderFee } },
          { new: true }
        );

        if (updatedRider) {
          const riderTx = new WalletTransaction({
            transactionId: await getNextSequence('walletTxId', 'TXN_RDR_', 5),
            userId: updatedRider.riderId,
            amount: riderFee,
            type: 'credit',
            category: 'rider_payout',
            paymentMethod: customerDeliveryCharge > 0 ? 'Customer Delivery Fee' : 'Store Sponsored Delivery Fee',
            orderId: existing.orderId,
            title: 'Delivery Task Earnings',
            subtitle: `Earned ₹${riderFee} for delivering order #${existing.orderId} · ${dateStr}`,
            balanceAfter: updatedRider.walletBalance,
            status: 'success',
          });
          await riderTx.save();
          console.log(`🚴 [Rider Payout] Credited ₹${riderFee} to rider ${updatedRider.riderId}`);
        }
      }

      // 2. Store Settlement (Way 2: Net of delivery fee if free delivery or customer delivery fee)
      if (existing.storeId) {
        const grandTotal = Number(existing.grandTotal) || 0;
        const deliveryDeduction = customerDeliveryCharge > 0 ? customerDeliveryCharge : standardDeliveryFee;
        const storeAmount = Math.max(0, grandTotal - deliveryDeduction);

        if (storeAmount > 0) {
          const updatedStore = await Store.findOneAndUpdate(
            { storeId: existing.storeId },
            { $inc: { walletBalance: storeAmount } },
            { new: true }
          );

          if (updatedStore) {
            const storeTx = new WalletTransaction({
              transactionId: await getNextSequence('walletTxId', 'TXN_SETTLE_', 5),
              userId: updatedStore.storeId,
              amount: storeAmount,
              type: 'credit',
              category: 'store_settlement',
              paymentMethod: 'Store Settlement',
              orderId: existing.orderId,
              title: updatedStore.name || 'Store Settlement',
              subtitle: `Settlement for order #${existing.orderId} · ${dateStr}`,
              balanceAfter: updatedStore.walletBalance || 0,
              status: 'success',
            });
            await storeTx.save();
            console.log(`🏪 [Store Settlement] Credited ₹${storeAmount} to store ${updatedStore.storeId}`);
          }
        }
      }
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

    // 1. Restock product catalog inventory
    if (Array.isArray(order.items)) {
      for (const item of order.items) {
        const pId = item.productId || item.id;
        const qty = Number(item.quantity || item.qty || 1);
        if (pId && qty > 0) {
          await Product.updateOne({ productId: pId }, { $inc: { stock: qty } }).catch(() => {});
        }
      }
      order.returnDetails.restocked = true;
    }

    // 2. Financial Settlement on Return Confirmation
    const deliveryFee = Number(order.deliveryCharge) || 0;
    const isDoorstepReturn = order.returnDetails?.returnType === 'rider_doorstep' || order.returnDetails?.initiatedBy === 'rider';

    // For doorstep return, citizen is refunded product cost (delivery fee is retained to pay rider for the completed trip)
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

    if ((wasWallet || wasPaid) && order.paymentStatus !== 'refunded') {
      if (refundAmt > 0) {
        const refundedUser = await User.findOneAndUpdate(
          { $or: [{ userId: order.userId }, { phone: order.userId }] },
          { $inc: { walletBalance: refundAmt } },
          { new: true }
        );

        if (refundedUser) {
          refundTxId = await getNextSequence('walletTxId', 'TXN_REF_', 5);
          const refundTx = new WalletTransaction({
            transactionId: refundTxId,
            userId: refundedUser.userId,
            amount: refundAmt,
            type: 'credit',
            category: 'order_refund',
            paymentMethod: 'Wallet Refund',
            orderId: order.orderId,
            title: 'Order Return Refund',
            subtitle: `Return refund (items cost) for order #${order.orderId} · ${dateStr}`,
            balanceAfter: refundedUser.walletBalance,
            status: 'success',
          });
          await refundTx.save();
          order.paymentStatus = 'refunded';
          order.returnDetails.refundAmount = refundAmt;
          order.returnDetails.refundTransactionId = refundTxId;
          console.log(`💳 [Return Auto-Refund] ₹${refundAmt} refunded to user ${refundedUser.userId} (Tx: ${refundTxId})`);
        }
      }
    }

    // 3. Compensate Rider for the Return Trip (Doorstep Return or Reverse Citizen Return)
    const riderId = order.deliveryAgent?.riderId;
    const reverseDeliveryFee = Number(order.returnDetails?.reverseDeliveryFee) || 0;
    let riderPayoutAmt = 0;
    let payoutTitle = '';
    let payoutSubtitle = '';

    if (riderId && isDoorstepReturn && deliveryFee > 0) {
      riderPayoutAmt = deliveryFee;
      payoutTitle = 'Return Trip Payout';
      payoutSubtitle = `Trip delivery payout for return order #${order.orderId} · ${dateStr}`;
    } else if (riderId && reverseDeliveryFee > 0) {
      riderPayoutAmt = reverseDeliveryFee;
      payoutTitle = 'Reverse Return Trip Payout';
      payoutSubtitle = `Reverse pickup delivery fee for return #${order.orderId} · ${dateStr}`;
    }

    if (riderId && riderPayoutAmt > 0) {
      const updatedRider = await Rider.findOneAndUpdate(
        { $or: [{ riderId }, { phone: riderId }] },
        { $inc: { walletBalance: riderPayoutAmt } },
        { new: true }
      );
      if (updatedRider) {
        const riderTxId = await getNextSequence('walletTxId', 'TXN_PAYOUT_', 5);
        const riderTx = new WalletTransaction({
          transactionId: riderTxId,
          userId: updatedRider.riderId || riderId,
          amount: riderPayoutAmt,
          type: 'credit',
          category: 'delivery_payout',
          paymentMethod: isDoorstepReturn ? 'Return Trip Fee' : 'Reverse Pickup Fee',
          orderId: order.orderId,
          title: payoutTitle,
          subtitle: payoutSubtitle,
          balanceAfter: updatedRider.walletBalance,
          status: 'success',
        });
        await riderTx.save();
        order.returnDetails.riderPayout = riderPayoutAmt;
        console.log(`🛵 [Rider Return Payout] Credited ₹${riderPayoutAmt} to rider ${riderId} (Tx: ${riderTxId})`);
      }
    }

    // 4. Free up rider in registry
    if (riderId) {
      const registry = req.app.get('riderRegistry');
      if (registry && registry.has(riderId)) {
        registry.get(riderId).isBusy = false;
      }
    }

    await order.save();

    const io = req.app.get('io');
    if (io) {
      const orderPayload = order.toObject ? order.toObject() : order;
      io.emit(`order:${orderId}:status_update`, orderPayload);
      io.emit('order:status_update', orderPayload);
      io.emit('order:status_updated', orderPayload);
      io.to(`store:${order.storeId}`).emit('order:returned', orderPayload);
      if (riderId) io.to(`rider:${riderId}`).emit('order:returned', orderPayload);
    }

    console.log(`✅📦 [Return Confirmed] Store ${storeId} verified return for order ${orderId}`);

    // High-Priority Citizen FCM Push on Return Confirmation
    User.findOne({ $or: [{ userId: order.userId }, { phone: order.userId }] })
      .select('fcmToken')
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
      const now = new Date();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

      const updatedStore = await Store.findOneAndUpdate(
        { storeId: order.storeId },
        { $inc: { walletBalance: -reverseFee } },
        { new: true }
      );

      if (updatedStore) {
        const storeDebitTx = new WalletTransaction({
          transactionId: await getNextSequence('walletTxId', 'TXN_DEBIT_', 5),
          userId: updatedStore.storeId,
          amount: reverseFee,
          type: 'debit',
          category: 'return_delivery_fee',
          paymentMethod: 'Store Wallet',
          orderId: order.orderId,
          title: 'Reverse Return Pickup Charge',
          subtitle: `Rider pickup charge for return #${order.orderId} · ${dateStr}`,
          balanceAfter: updatedStore.walletBalance,
          status: 'success',
        });
        await storeDebitTx.save();
        console.log(`🏪 [Reverse Return Fee] Debited ₹${reverseFee} from store ${order.storeId}`);
      }
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

        const notifiedTokens = new Set();
        const registry = req.app.get('riderRegistry');
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
        // (Forces Android/iOS to wake screen and bring Rider App to foreground even if idle or backgrounded)
        Rider.find({ isOnline: true, isBusy: { $ne: true }, fcmToken: { $ne: '' } })
          .select('fcmToken riderId phone')
          .then(async (riders) => {
            for (const r of riders) {
              if (r.fcmToken && !notifiedTokens.has(r.fcmToken)) {
                notifiedTokens.add(r.fcmToken);
                fcmService.sendToRiderOrderAlert(r.fcmToken, dispatchPayload);
              }
            }

            // Also check User collection for riders in registry whose FCM token might be on User
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
