const User = require('../models/User');
const Rider = require('../models/Rider');
const Store = require('../models/Store');
const WalletTransaction = require('../models/WalletTransaction');
const { getNextSequence } = require('./sequenceGenerator');
const { formatTransactionDate } = require('./commonHelper');

/**
 * Atomically updates wallet balance for a User, Rider, or Store and records a WalletTransaction.
 * 
 * @param {Object} params
 * @param {'user'|'rider'|'store'} [params.role='user']
 * @param {string} params.targetId - userId, riderId, storeId, or phone
 * @param {number} params.amount - amount to credit or debit
 * @param {'credit'|'debit'} params.type - transaction type
 * @param {string} params.category - valid category enum from WalletTransaction
 * @param {string} [params.paymentMethod='Wallet'] - payment method description
 * @param {string} [params.orderId=''] - optional associated orderId
 * @param {string} params.title - transaction title
 * @param {string} [params.subtitle=''] - optional subtitle (defaults to title + date)
 * @param {string} [params.txPrefix='TXN_'] - prefix for transaction sequence generator
 * @param {Object} [params.metadata={}] - additional optional metadata
 * @returns {Promise<{ success: boolean, updatedEntity?: Object, transaction?: Object, balanceAfter?: number, transactionId?: string, reason?: string }>}
 */
async function executeWalletTransaction({
  role = 'user',
  targetId,
  amount,
  type,
  category,
  paymentMethod = 'Wallet',
  orderId = '',
  title,
  subtitle = '',
  txPrefix = 'TXN_',
  metadata = {},
}) {
  if (!targetId || amount === undefined || amount === null || !type || !category) {
    throw new Error('targetId, amount, type, and category are required for wallet transaction');
  }

  const numericAmount = Math.abs(Number(amount));
  if (numericAmount <= 0) {
    return { success: false, reason: 'zero_amount' };
  }

  const balanceDelta = type === 'credit' ? numericAmount : -numericAmount;

  // 1. Resolve model by role
  let Model;
  let idField;
  if (role === 'rider') {
    Model = Rider;
    idField = 'riderId';
  } else if (role === 'store') {
    Model = Store;
    idField = 'storeId';
  } else {
    Model = User;
    idField = 'userId';
  }

  // 2. Atomic balance update
  const updatedEntity = await Model.findOneAndUpdate(
    { $or: [{ [idField]: targetId }, { phone: targetId }] },
    { $inc: { walletBalance: balanceDelta } },
    { returnDocument: 'after' }
  );

  if (!updatedEntity) {
    console.warn(`⚠️ [Wallet] Entity not found for role ${role} with id ${targetId}`);
    return { success: false, reason: 'entity_not_found' };
  }

  const resolvedId = updatedEntity[idField] || targetId;
  const balanceAfter = updatedEntity.walletBalance || 0;

  // 3. Generate sequential transaction ID
  const transactionId = await getNextSequence('walletTxId', txPrefix, 5);

  const dateStr = formatTransactionDate();
  const finalSubtitle = subtitle || `${title} · ${dateStr}`;

  // 4. Record transaction in database
  const transaction = new WalletTransaction({
    transactionId,
    userId: resolvedId,
    amount: type === 'credit' ? numericAmount : -numericAmount,
    type,
    category,
    paymentMethod,
    orderId,
    title,
    subtitle: finalSubtitle,
    balanceAfter,
    status: 'success',
    metadata,
  });

  await transaction.save();

  console.log(`💳 [Wallet Tx] ${type.toUpperCase()} ₹${numericAmount} (${category}) for ${role} ${resolvedId} · Bal: ₹${balanceAfter} · Tx: ${transactionId}`);

  return {
    success: true,
    updatedEntity,
    transaction,
    balanceAfter,
    transactionId,
  };
}

module.exports = {
  executeWalletTransaction,
};
