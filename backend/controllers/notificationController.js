const mongoose = require('mongoose');
const Notification = require('../models/Notification');
const Complaint = require('../models/Complaint');
const Order = require('../models/Order');

/**
 * Helper to create a notification in DB.
 */
async function createNotification({ userId, title, message, type = 'general', referenceId = '', metadata = {} }) {
  if (!userId || !title || !message) return null;
  try {
    const notification = await Notification.create({
      userId,
      title,
      message,
      type,
      referenceId,
      metadata,
    });
    return notification;
  } catch (error) {
    console.error('❌ [Notification] Error creating notification:', error.message);
    return null;
  }
}

/**
 * Get all notifications for a specific user.
 * If user has no notifications, smart-backfill from latest complaints/orders.
 */
async function getNotificationsByUser(req, res) {
  try {
    const { userId } = req.params;
    if (!userId) {
      return res.status(400).json({ success: false, message: 'userId is required' });
    }

    let notifications = await Notification.find({ userId })
      .sort({ createdAt: -1 })
      .lean();

    // Smart-backfill for existing users who haven't generated any notifications yet
    if (!notifications || notifications.length === 0) {
      const backfillList = [];

      // 1. Fetch complaints & orders in parallel
      const [userComplaints, userOrders] = await Promise.all([
        Complaint.find({ userId }).sort({ createdAt: -1 }).limit(5).lean(),
        Order.find({ userId }).sort({ createdAt: -1 }).limit(5).lean(),
      ]);

      for (let i = 0; i < userComplaints.length; i++) {
        const comp = userComplaints[i];
        backfillList.push({
          notificationId: `NOTIF_${Date.now()}_C${i}_${Math.floor(100 + Math.random() * 900)}`,
          userId,
          title: comp.status === 'Resolved' ? 'Complaint Resolved' : 'Complaint Registered',
          message: `Your complaint #${comp.complaintId || comp.id} (${comp.category}) is ${comp.status || 'Under Review'}.`,
          type: 'complaint',
          referenceId: comp.complaintId || comp.id,
          createdAt: comp.updatedAt || comp.createdAt || new Date(),
          isRead: false,
        });
      }

      for (let j = 0; j < userOrders.length; j++) {
        const ord = userOrders[j];
        backfillList.push({
          notificationId: `NOTIF_${Date.now()}_O${j}_${Math.floor(100 + Math.random() * 900)}`,
          userId,
          title: `Order ${ord.status ? ord.status.replace(/_/g, ' ').toUpperCase() : 'Placed'}`,
          message: `Order #${ord.orderId} at ${ord.storeDetails?.name || 'Store'} (₹${ord.grandTotal}).`,
          type: 'order',
          referenceId: ord.orderId,
          createdAt: ord.updatedAt || ord.createdAt || new Date(),
          isRead: false,
        });
      }

      // 3. Welcome notification
      backfillList.push({
        notificationId: `NOTIF_${Date.now()}_W_${Math.floor(100 + Math.random() * 900)}`,
        userId,
        title: 'Welcome to GoGovernment',
        message: 'Your citizen services and civic grievance portal is ready.',
        type: 'general',
        referenceId: '',
        createdAt: new Date(Date.now() - 86400000),
        isRead: true,
      });

      if (backfillList.length > 0) {
        await Notification.insertMany(backfillList);
        notifications = await Notification.find({ userId })
          .sort({ createdAt: -1 })
          .lean();
      }
    }

    const unreadCount = notifications.filter(n => !n.isRead).length;

    return res.status(200).json({
      success: true,
      count: notifications.length,
      unreadCount,
      notifications,
    });
  } catch (error) {
    console.error('❌ [Notification] Error fetching notifications:', error);
    return res.status(500).json({ success: false, message: 'Server error fetching notifications' });
  }
}


/**
 * Mark a single notification as read.
 */
async function markAsRead(req, res) {
  try {
    const { id } = req.params;
    const filter = mongoose.Types.ObjectId.isValid(id)
      ? { $or: [{ _id: id }, { notificationId: id }] }
      : { notificationId: id };

    const notification = await Notification.findOneAndUpdate(
      filter,
      { isRead: true },
      { returnDocument: 'after' }
    );

    if (!notification) {
      return res.status(404).json({ success: false, message: 'Notification not found' });
    }

    return res.status(200).json({ success: true, notification });
  } catch (error) {
    console.error('❌ [Notification] Error marking notification as read:', error);
    return res.status(500).json({ success: false, message: 'Server error updating notification' });
  }
}

/**
 * Mark all notifications for a user as read.
 */
async function markAllAsRead(req, res) {
  try {
    const { userId } = req.params;
    await Notification.updateMany({ userId, isRead: false }, { isRead: true });
    return res.status(200).json({ success: true, message: 'All notifications marked as read' });
  } catch (error) {
    console.error('❌ [Notification] Error marking all notifications as read:', error);
    return res.status(500).json({ success: false, message: 'Server error updating notifications' });
  }
}

module.exports = {
  createNotification,
  getNotificationsByUser,
  markAsRead,
  markAllAsRead,
};
