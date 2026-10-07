const Counter = require('../models/Counter');

/**
 * Generates an atomic sequential ID with prefix and zero-padding.
 * Example:
 *   await getNextSequence('userId', 'USER_', 5) -> 'USER_00001'
 *   await getNextSequence('storeId', 'STORE_', 5) -> 'STORE_00001'
 *   await getNextSequence('orderId', 'ORD_', 5) -> 'ORD_00001'
 *
 * @param {string} counterName - Sequence identifier (e.g. 'userId', 'storeId')
 * @param {string} prefix - Custom prefix string (e.g. 'USER_', 'ORD_')
 * @param {number} padLength - Number of digits to pad (default: 5)
 * @returns {Promise<string>}
 */
const getNextSequence = async (counterName, prefix = '', padLength = 5) => {
  const counter = await Counter.findOneAndUpdate(
    { _id: counterName },
    { $inc: { seq: 1 } },
    { upsert: true, returnDocument: 'after' }
  );

  return `${prefix}${String(counter.seq).padStart(padLength, '0')}`;
};

module.exports = { getNextSequence };
