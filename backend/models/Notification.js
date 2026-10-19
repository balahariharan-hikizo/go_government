const mongoose = require('mongoose');

const notificationSchema = new mongoose.Schema(
  {
    notificationId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    userId: {
      type: String,
      required: true,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
    },
    message: {
      type: String,
      required: true,
      trim: true,
    },
    type: {
      type: String,
      enum: ['complaint', 'order', 'wallet', 'general'],
      default: 'general',
      index: true,
    },
    referenceId: {
      type: String,
      default: '',
    },
    metadata: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
    isRead: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

// Auto-generate notificationId if not provided
notificationSchema.pre('validate', function () {
  if (!this.notificationId) {
    this.notificationId = `NOTIF_${Date.now()}_${Math.floor(100 + Math.random() * 900)}`;
  }
});

module.exports = mongoose.model('Notification', notificationSchema);
