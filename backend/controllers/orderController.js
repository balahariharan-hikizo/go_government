const Order = require('../models/Order');
const Store = require('../models/Store');
const User = require('../models/User');
const Rider = require('../models/Rider');
const Product = require('../models/Product');
const WalletTransaction = require('../models/WalletTransaction');
const fcmService = require('../services/fcmService');
const { getNextSequence } = require('../utils/sequenceGenerator');

// 1. CREATE NEW ORDER (Citizen Placement)
exports.createOrder = async (req, res) => {
  try {
    const {
      userId,
      storeId,
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
      resolvedStoreDetails.latitude = resolvedStoreDetails.latitude || 12.9716;
      resolvedStoreDetails.longitude = resolvedStoreDetails.longitude || 77.5946;
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

    const newOrder = new Order({
      orderId,
      userId,
      storeId,
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

    // Decrement stock atomically
    for (const item of items) {
      const pId = item.productId || item.id;
      const qty = Number(item.quantity || item.qty || 1);
      if (pId && qty > 0) {
        await Product.updateOne(
          { productId: pId },
          { $inc: { stock: -qty } }
        ).catch((err) => console.warn(`⚠️ [Inventory] Could not decrement stock for product ${pId}:`, err.message));
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

    // Real-time Socket.io Notification to Merchant
    const io = req.app.get('io');
    if (io) {
      const orderPayload = newOrder.toObject ? newOrder.toObject() : newOrder;
      io.emit('order:new', orderPayload);
      io.emit(`store:${storeId}:new_order`, orderPayload);
      io.to(`store:${storeId}`).emit('order:new', orderPayload);
      console.log(`📡 [Socket.io] Emitted order:new for order ${orderId}`);
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
    return res.status(200).json({ success: true, data: orders });
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

    return res.status(200).json({ success: true, data: orders });
  } catch (error) {
    console.error('Error fetching user orders:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch user orders', error: error.message });
  }
};

// 5. GET STORE ORDERS (Merchant Dashboard Metrics)
exports.getStoreOrders = async (req, res) => {
  try {
    const { storeId } = req.params;
    const orders = await Order.find({ storeId }).sort({ createdAt: -1 });

    let totalSubsidyDisbursed = 0;
    let pendingSubsidyPayout = 0;
    let totalGrossSales = 0;
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
      }
    }

    return res.status(200).json({
      success: true,
      data: orders,
      summary: {
        totalOrders: orders.length,
        activeOrdersCount,
        totalSubsidyDisbursed: Math.round(totalSubsidyDisbursed),
        pendingSubsidyPayout: Math.round(pendingSubsidyPayout),
        totalGrossSales: Math.round(totalGrossSales),
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
      status: 'ready_for_pickup',
      $or: [
        { 'deliveryAgent.riderId': '' },
        { 'deliveryAgent.riderId': { $exists: false } },
        { 'deliveryAgent.riderId': null },
      ],
    }).sort({ createdAt: -1 });

    return res.status(200).json({ success: true, data: orders });
  } catch (error) {
    console.error('Error fetching available orders:', error);
    return res.status(500).json({ success: false, message: 'Failed to fetch available deliveries', error: error.message });
  }
};

// 7. GET RIDER DELIVERIES
exports.getRiderDeliveries = async (req, res) => {
  try {
    const { riderId } = req.params;
    const orders = await Order.find({ 'deliveryAgent.riderId': riderId }).sort({ createdAt: -1 });
    return res.status(200).json({ success: true, data: orders });
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

// 9. RIDER ACCEPTS DELIVERY TASK (Concurrency & Race Protected)
exports.acceptOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const { riderId, name, phone, vehicleNumber, rating = 4.9 } = req.body;

    if (!riderId || !name) {
      return res.status(400).json({ success: false, message: 'riderId and name are required' });
    }

    const existing = await Order.findOne({ orderId });
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    // Already accepted check
    if (existing.deliveryAgent && existing.deliveryAgent.riderId) {
      if (existing.deliveryAgent.riderId === riderId) {
        return res.status(200).json({
          success: true,
          message: 'Delivery already accepted by you',
          data: existing,
        });
      } else {
        return res.status(409).json({
          success: false,
          code: 'ALREADY_ACCEPTED',
          message: 'This delivery task has already been accepted by another delivery partner.',
          assignedTo: existing.deliveryAgent.name || 'Another rider',
        });
      }
    }

    // Atomic assignment
    const order = await Order.findOneAndUpdate(
      {
        orderId,
        $or: [
          { 'deliveryAgent.riderId': '' },
          { 'deliveryAgent.riderId': { $exists: false } },
          { 'deliveryAgent.riderId': null },
        ],
      },
      {
        $set: {
          'deliveryAgent.riderId': riderId,
          'deliveryAgent.name': name,
          'deliveryAgent.phone': phone || '',
          'deliveryAgent.vehicleNumber': vehicleNumber || '',
          'deliveryAgent.rating': Number(rating) || 4.9,
          status: 'accepted',
        },
      },
      { returnDocument: 'after' }
    );

    if (!order) {
      const contested = await Order.findOne({ orderId });
      return res.status(409).json({
        success: false,
        code: 'ALREADY_ACCEPTED',
        message: 'This delivery task has already been accepted by another delivery partner.',
        assignedTo: contested?.deliveryAgent?.name || 'Another rider',
      });
    }

    console.log(`🚴 [Rider Assigned] Rider ${name} (${riderId}) accepted order ${orderId}`);

    // Mark rider as BUSY in registry & DB
    const riderRegistry = req.app.get('riderRegistry');
    if (riderRegistry && riderRegistry.has(riderId)) {
      riderRegistry.get(riderId).isBusy = true;
    }
    await Rider.updateOne({ riderId }, { $set: { isBusy: true } }).catch(() => {});

    // Real-time socket alerts
    const io = req.app.get('io');
    if (io) {
      const orderPayload = order.toObject ? order.toObject() : order;
      io.emit(`order:${orderId}:status_update`, orderPayload);
      io.emit('order:status_update', orderPayload);
      io.emit(`store:${order.storeId}:order_update`, orderPayload);
      io.to(`store:${order.storeId}`).emit('order:status_update', orderPayload);
      io.emit('order:assigned', orderPayload);
      io.to('riders').emit('order:assigned', orderPayload);
    }

    // Push Notification to Citizen
    User.findOne({ $or: [{ userId: order.userId }, { phone: order.userId }] })
      .select('fcmToken')
      .then((citizen) => {
        if (citizen && citizen.fcmToken) {
          fcmService.sendToCitizenOrderStatus(
            citizen.fcmToken,
            '🛵 Delivery Partner Assigned!',
            `${name} has accepted your order #${orderId} and is heading to the store.`,
            orderId
          );
        }
      })
      .catch((err) => console.error('Error sending citizen FCM:', err.message));

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

    const validStatuses = ['placed', 'preparing', 'ready_for_pickup', 'accepted', 'out_for_delivery', 'delivered', 'cancelled'];
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
      // 1. Rider Payout (₹40 base or deliveryCharge)
      const riderId = existing.deliveryAgent?.riderId;
      if (riderId) {
        const customerCharge = Number(existing.deliveryCharge) || 0;
        const riderFee = Math.max(40, customerCharge);

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
            paymentMethod: 'Rider Payout',
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

      // 2. Store Settlement
      if (existing.storeId) {
        const grandTotal = Number(existing.grandTotal) || 0;
        const deliveryCharge = Number(existing.deliveryCharge) || 0;
        const storeAmount = Math.max(0, grandTotal - deliveryCharge);

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
      { returnDocument: 'after' }
    );

    if (!order) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    console.log(`🔄 [Order Status Updated] Order ${orderId} -> ${status}`);

    const io = req.app.get('io');
    if (io) {
      const orderPayload = order.toObject ? order.toObject() : order;
      io.emit(`order:${orderId}:status_update`, orderPayload);
      io.emit('order:status_update', orderPayload);
      io.emit(`store:${order.storeId}:order_update`, orderPayload);
      io.to(`store:${order.storeId}`).emit('order:status_update', orderPayload);

      if (status === 'ready_for_pickup') {
        io.emit('order:available', orderPayload);
        io.to('riders').emit('order:available', orderPayload);

        const dispatchOrder = req.app.get('dispatchOrder');
        const storeLat = order.storeDetails?.latitude || 0;
        const storeLng = order.storeDetails?.longitude || 0;
        if (dispatchOrder && (storeLat !== 0 || storeLng !== 0)) {
          dispatchOrder(io, orderPayload, storeLat, storeLng, 1, []);
        } else {
          io.emit('order:dispatch', { ...orderPayload, dispatchRound: 3, countdownSecs: 30 });
          io.to('riders').emit('order:dispatch', { ...orderPayload, dispatchRound: 3, countdownSecs: 30 });
        }
      }

      if (status === 'accepted') {
        const dispatchTimers = req.app.get('dispatchTimers');
        if (dispatchTimers && dispatchTimers.has(orderId)) {
          clearTimeout(dispatchTimers.get(orderId).timer);
          dispatchTimers.delete(orderId);
        }
        io.to(`store:${order.storeId}`).emit('order:status_update', orderPayload);
        io.to('riders').emit('order:dispatch_cancelled', { orderId });
      }

      if (status === 'delivered') {
        const riderId = order.deliveryAgent?.riderId;
        if (riderId) {
          const riderRegistry = req.app.get('riderRegistry');
          if (riderRegistry && riderRegistry.has(riderId)) {
            riderRegistry.get(riderId).isBusy = false;
          }
          await Rider.updateOne({ riderId }, { $set: { isBusy: false } }).catch(() => {});
        }
      }
    }

    // Send FCM Push on status updates
    if (['out_for_delivery', 'delivered', 'cancelled'].includes(status)) {
      User.findOne({ $or: [{ userId: order.userId }, { phone: order.userId }] })
        .select('fcmToken')
        .then((citizen) => {
          if (citizen && citizen.fcmToken) {
            if (status === 'out_for_delivery') {
              fcmService.sendToCitizenOrderStatus(
                citizen.fcmToken,
                '🚚 Out for Delivery!',
                `Your order #${orderId} is on the way to your delivery address.`,
                orderId
              );
            } else if (status === 'delivered') {
              fcmService.sendToCitizenOrderStatus(
                citizen.fcmToken,
                '🎉 Order Delivered!',
                `Your order #${orderId} has been successfully delivered. Thank you!`,
                orderId
              );
            } else if (status === 'cancelled') {
              fcmService.sendToCitizenOrderStatus(
                citizen.fcmToken,
                '❌ Order Cancelled',
                `Your order #${orderId} has been cancelled.`,
                orderId
              );
            }
          }
        })
        .catch((err) => console.error('Error sending citizen FCM status:', err.message));
    }

    return res.status(200).json({
      success: true,
      message: `Order status updated to ${status}`,
      data: order,
    });
  } catch (error) {
    console.error('Error updating order status:', error);
    return res.status(500).json({ success: false, message: 'Failed to update order status', error: error.message });
  }
};

// 11. DELETE ORDER
exports.deleteOrder = async (req, res) => {
  try {
    const { orderId } = req.params;
    const deleted = await Order.findOneAndDelete({ orderId });
    if (!deleted) {
      return res.status(404).json({ success: false, message: 'Order not found' });
    }

    // Free rider if assigned
    const riderId = deleted.deliveryAgent?.riderId;
    if (riderId) {
      const riderRegistry = req.app.get('riderRegistry');
      if (riderRegistry && riderRegistry.has(riderId)) {
        riderRegistry.get(riderId).isBusy = false;
      }
      await Rider.updateOne({ riderId }, { $set: { isBusy: false } }).catch(() => {});
    }

    // Clear dispatch timer
    const dispatchTimers = req.app.get('dispatchTimers');
    if (dispatchTimers && dispatchTimers.has(orderId)) {
      clearTimeout(dispatchTimers.get(orderId).timer);
      dispatchTimers.delete(orderId);
    }

    const io = req.app.get('io');
    if (io) {
      io.emit('order:deleted', { orderId });
      io.emit(`order:${orderId}:deleted`, { orderId });
      io.to(`store:${deleted.storeId}`).emit('order:deleted', { orderId });
      io.to('riders').emit('order:dispatch_cancelled', { orderId });
    }

    return res.status(200).json({
      success: true,
      message: `Order #${orderId} deleted successfully`,
      data: deleted,
    });
  } catch (error) {
    console.error('Error deleting order:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete order', error: error.message });
  }
};
