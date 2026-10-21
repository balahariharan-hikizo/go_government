const mongoose = require('mongoose');

const OrderItemSchema = new mongoose.Schema({
  productId: { type: String, required: true },
  variantId: { type: String, default: '' },
  title: { type: String, required: true },
  price: { type: Number, required: true },
  originalPrice: { type: Number, default: 0 },
  quantity: { type: Number, required: true, default: 1 },
  image: { type: String, default: '' },
  unit: { type: String, default: '1 Units' },
});

const OrderSchema = new mongoose.Schema(
  {
    orderId: { type: String, required: true, unique: true, index: true },
    userId: { type: String, required: true, index: true },
    storeId: { type: String, required: true, index: true },
    storeName: { type: String, required: true },
    
    items: [OrderItemSchema],
    
    itemTotal: { type: Number, required: true },
    deliveryCharge: { type: Number, default: 0 },
    handlingCharge: { type: Number, default: 2 },
    couponDiscount: { type: Number, default: 0 },
    coinsDiscount: { type: Number, default: 0 },
    grandTotal: { type: Number, required: true },
    
    paymentMethod: { type: String, default: 'Cash on Delivery' },
    paymentStatus: { type: String, enum: ['pending', 'paid', 'failed', 'refunded'], default: 'paid' },
    
    deliveryAddress: {
      address: { type: String, required: true },
      latitude: { type: Number, default: 12.9716 },
      longitude: { type: Number, default: 77.5946 },
      receiverName: { type: String, default: '' },
      receiverPhone: { type: String, default: '' },
    },
    
    storeDetails: {
      storeId: { type: String, default: '' },
      name: { type: String, default: 'Store' },
      address: { type: String, default: '' },
      latitude: { type: Number, default: 12.9716 },
      longitude: { type: Number, default: 77.5946 },
      phone: { type: String, default: '' },
    },
    
    status: {
      type: String,
      enum: [
        'placed',
        'preparing',
        'ready_for_pickup',
        'accepted',
        'out_for_delivery',
        'delivered',
        'cancelled',
        'returning_to_store',
        'returned_to_store',
        'return_requested',
        'return_approved',
        'return_pickup_pending',
        'return_pickup_assigned',
        'return_rejected',
        'returned',
      ],
      default: 'placed',
      index: true,
    },
    
    deliveryAgent: {
      riderId: { type: String, default: '' },
      name: { type: String, default: '' },
      phone: { type: String, default: '' },
      vehicleNumber: { type: String, default: '' },
      rating: { type: Number, default: 4.9 },
    },
    
    estimatedDeliveryTime: { type: String, default: '25-30 mins' },
    deliveredAt: { type: Date },

    // Two-Way Return Flow Metadata
    returnDetails: {
      returnType: {
        type: String,
        enum: ['rider_doorstep', 'citizen_request', 'none'],
        default: 'none',
      },
      reason: { type: String, default: '' },
      notes: { type: String, default: '' },
      proofImage: { type: String, default: '' },
      initiatedBy: { type: String, default: '' },
      requestedAt: { type: Date, default: null },
      receivedAt: { type: Date, default: null },
      refundAmount: { type: Number, default: 0 },
      refundTransactionId: { type: String, default: '' },
      riderPayout: { type: Number, default: 0 },
      reverseDeliveryFee: { type: Number, default: 0 },
      rejectionReason: { type: String, default: '' },
      restocked: { type: Boolean, default: false },
    },
  },
  {
    timestamps: true,
  }
);

OrderSchema.virtual('citizen', {
  ref: 'User',
  localField: 'userId',
  foreignField: 'userId',
  justOne: true,
});

OrderSchema.virtual('store', {
  ref: 'Store',
  localField: 'storeId',
  foreignField: 'storeId',
  justOne: true,
});

OrderSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    delete ret._id;
  },
});

OrderSchema.set('toObject', {
  virtuals: true,
});


module.exports = mongoose.model('Order', OrderSchema);
