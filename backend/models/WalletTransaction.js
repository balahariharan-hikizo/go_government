const mongoose = require('mongoose');

const WalletTransactionSchema = new mongoose.Schema(
  {
    transactionId: { type: String, required: true, unique: true },
    userId: { type: String, required: true, index: true },
    amount: { type: Number, required: true }, // positive for credit, negative for debit
    type: { type: String, enum: ['credit', 'debit'], required: true },
    category: {
      type: String,
      enum: ['topup', 'order_payment', 'order_refund', 'reward_redemption', 'civic_reward', 'reward_earned', 'cashback', 'rider_payout', 'store_settlement', 'withdrawal', 'return_delivery_fee', 'return_payout', 'delivery_payout'],
      required: true,
    },
    paymentMethod: { type: String, default: 'Wallet' },
    orderId: { type: String, default: '' },
    title: { type: String, required: true },
    subtitle: { type: String, default: '' },
    balanceAfter: { type: Number, default: 0 },
    status: { type: String, enum: ['success', 'failed', 'pending'], default: 'success' },
    metadata: { type: Object, default: {} },
  },
  {
    timestamps: true,
  }
);

WalletTransactionSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    delete ret._id;
  },
});

module.exports = mongoose.model('WalletTransaction', WalletTransactionSchema);
