const mongoose = require('mongoose');

const CartItemSchema = new mongoose.Schema({
  productId: { type: String, required: true },
  variantId: { type: String, default: '' }, // Specific size / weight variant ID if applicable
  unit: { type: String, default: '1 Units' },
  price: { type: Number, default: 0 },
  quantity: { type: Number, required: true, default: 1, min: 1 },
  product: { type: Object, default: {} },
});

const CartSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, unique: true, index: true },
    items: [CartItemSchema],
  },
  {
    timestamps: true,
  }
);

CartSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    delete ret._id;
  },
});

module.exports = mongoose.model('Cart', CartSchema);
