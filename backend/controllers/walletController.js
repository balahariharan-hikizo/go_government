const User = require('../models/User');
const Rider = require('../models/Rider');
const Store = require('../models/Store');
const WalletTransaction = require('../models/WalletTransaction');
const { getNextSequence } = require('../utils/sequenceGenerator');

// 1. GET WALLET DETAILS & LEDGER HISTORY
exports.getWalletDetails = async (req, res) => {
  try {
    const { userId } = req.params;

    // Check User, Rider, or Store
    let account = await User.findOne({ $or: [{ userId }, { phone: userId }] });
    let role = 'citizen';
    let balance = account?.walletBalance || 0;
    let coins = account?.coinsBalance || 0;

    if (!account) {
      account = await Rider.findOne({ $or: [{ riderId: userId }, { phone: userId }] });
      if (account) {
        role = 'rider';
        balance = account.walletBalance || 0;
      }
    }

    if (!account) {
      account = await Store.findOne({ $or: [{ storeId: userId }, { phone: userId }] });
      if (account) {
        role = 'store_owner';
        balance = account.walletBalance || 0;
      }
    }

    const accountId = account?.userId || account?.riderId || account?.storeId || userId;

    const transactions = await WalletTransaction.find({
      $or: [{ userId }, { userId: accountId }],
    })
      .sort({ createdAt: -1 })
      .limit(50);

    res.status(200).json({
      success: true,
      userId: accountId,
      role,
      walletBalance: balance,
      coinsBalance: coins,
      transactions,
    });
  } catch (error) {
    console.error('Error fetching wallet details:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch wallet details' });
  }
};

// 2. TOP UP WALLET
exports.topupWallet = async (req, res) => {
  try {
    const { userId, amount, paymentMethod, referenceId } = req.body;
    const numAmount = Number(amount);

    if (!userId || isNaN(numAmount) || numAmount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Valid userId and positive amount are required',
      });
    }

    const resolvedMethod = paymentMethod || 'UPI';

    const updatedUser = await User.findOneAndUpdate(
      { $or: [{ userId }, { phone: userId }] },
      { $inc: { walletBalance: numAmount } },
      { new: true, upsert: true }
    );

    const txId = await getNextSequence('walletTxId', 'TXN_TOP_', 5);
    const now = new Date();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

    const transaction = new WalletTransaction({
      transactionId: txId,
      userId: updatedUser.userId,
      amount: numAmount,
      type: 'credit',
      category: 'topup',
      paymentMethod: resolvedMethod,
      title: 'Wallet Top-up',
      subtitle: `Added via ${resolvedMethod} · ${dateStr}`,
      balanceAfter: updatedUser.walletBalance,
      status: 'success',
      metadata: {
        referenceId: referenceId || `REF_${Date.now()}`,
      },
    });

    await transaction.save();

    console.log(`💳 [Wallet Top-up] ${updatedUser.userId} credited +₹${numAmount} via ${resolvedMethod}`);

    res.status(200).json({
      success: true,
      message: `Successfully topped up ₹${numAmount} to wallet`,
      walletBalance: updatedUser.walletBalance,
      coinsBalance: updatedUser.coinsBalance || 0,
      transaction,
    });
  } catch (error) {
    console.error('Error topping up wallet:', error);
    res.status(500).json({ success: false, error: 'Failed to process wallet top-up' });
  }
};

// 3. ATOMICALLY DEDUCT WALLET FOR ORDER PAYMENT
exports.deductWallet = async (req, res) => {
  try {
    const { userId, amount, orderId, title, subtitle } = req.body;
    const numAmount = Number(amount);

    if (!userId || isNaN(numAmount) || numAmount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Valid userId and positive amount are required',
      });
    }

    const updatedUser = await User.findOneAndUpdate(
      {
        $or: [{ userId }, { phone: userId }],
        walletBalance: { $gte: numAmount },
      },
      { $inc: { walletBalance: -numAmount } },
      { new: true }
    );

    if (!updatedUser) {
      const currentUser = await User.findOne({ $or: [{ userId }, { phone: userId }] });
      const currentBal = currentUser ? currentUser.walletBalance : 0;
      return res.status(400).json({
        success: false,
        code: 'INSUFFICIENT_BALANCE',
        error: `Insufficient wallet balance. Required: ₹${numAmount}, Current: ₹${currentBal}`,
        walletBalance: currentBal,
      });
    }

    const txId = await getNextSequence('walletTxId', 'TXN_PAY_', 5);
    const now = new Date();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

    const transaction = new WalletTransaction({
      transactionId: txId,
      userId: updatedUser.userId,
      amount: -numAmount,
      type: 'debit',
      category: 'order_payment',
      paymentMethod: 'Wallet Account',
      orderId: orderId || '',
      title: title || 'Order Payment',
      subtitle: subtitle || `Paid for order ${orderId ? '#' + orderId : ''} · ${dateStr}`,
      balanceAfter: updatedUser.walletBalance,
      status: 'success',
    });

    await transaction.save();

    console.log(`💳 [Wallet Deduct] ${updatedUser.userId} deducted -₹${numAmount}`);

    res.status(200).json({
      success: true,
      message: `Deducted ₹${numAmount} from wallet for order payment`,
      walletBalance: updatedUser.walletBalance,
      transaction,
    });
  } catch (error) {
    console.error('Error deducting from wallet:', error);
    res.status(500).json({ success: false, error: 'Failed to process wallet payment' });
  }
};

// 4. REFUND CANCELLED ORDER TO WALLET
exports.refundWallet = async (req, res) => {
  try {
    const { userId, amount, orderId, reason } = req.body;
    const numAmount = Number(amount);

    if (!userId || isNaN(numAmount) || numAmount <= 0) {
      return res.status(400).json({
        success: false,
        error: 'Valid userId and positive amount are required',
      });
    }

    const updatedUser = await User.findOneAndUpdate(
      { $or: [{ userId }, { phone: userId }] },
      { $inc: { walletBalance: numAmount } },
      { new: true, upsert: true }
    );

    const txId = await getNextSequence('walletTxId', 'TXN_REF_', 5);
    const now = new Date();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

    const transaction = new WalletTransaction({
      transactionId: txId,
      userId: updatedUser.userId,
      amount: numAmount,
      type: 'credit',
      category: 'order_refund',
      paymentMethod: 'Wallet Refund',
      orderId: orderId || '',
      title: 'Order Refund',
      subtitle: `Refund for cancelled order ${orderId ? '#' + orderId : ''} · ${dateStr}`,
      balanceAfter: updatedUser.walletBalance,
      status: 'success',
      metadata: { reason: reason || 'Order cancelled before packing' },
    });

    await transaction.save();

    console.log(`💳 [Wallet Refund] ${updatedUser.userId} refunded +₹${numAmount}`);

    res.status(200).json({
      success: true,
      message: `Successfully refunded ₹${numAmount} to wallet`,
      walletBalance: updatedUser.walletBalance,
      transaction,
    });
  } catch (error) {
    console.error('Error processing wallet refund:', error);
    res.status(500).json({ success: false, error: 'Failed to process wallet refund' });
  }
};

// 5. REDEEM REWARD COINS TO WALLET CASH (100 coins = ₹1)
exports.redeemCoins = async (req, res) => {
  try {
    const { userId, coins } = req.body;
    const numCoins = Number(coins);

    if (!userId || isNaN(numCoins) || numCoins < 100) {
      return res.status(400).json({
        success: false,
        error: 'Minimum 100 reward coins required to redeem (100 coins = ₹1)',
      });
    }

    const cashAmount = Math.floor(numCoins / 100);
    const actualCoinsToDeduct = cashAmount * 100;

    const updatedUser = await User.findOneAndUpdate(
      {
        $or: [{ userId }, { phone: userId }],
        coinsBalance: { $gte: actualCoinsToDeduct },
      },
      {
        $inc: {
          coinsBalance: -actualCoinsToDeduct,
          walletBalance: cashAmount,
        },
      },
      { new: true }
    );

    if (!updatedUser) {
      return res.status(400).json({
        success: false,
        error: 'Insufficient reward coins to redeem',
      });
    }

    const txId = await getNextSequence('walletTxId', 'TXN_COIN_', 5);
    const now = new Date();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const dateStr = `${months[now.getMonth()]} ${now.getDate()} · ${now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;

    const transaction = new WalletTransaction({
      transactionId: txId,
      userId: updatedUser.userId,
      amount: cashAmount,
      type: 'credit',
      category: 'reward_redemption',
      paymentMethod: 'Reward Coins',
      title: 'Coins Redeemed',
      subtitle: `${actualCoinsToDeduct} coins converted to cash · ${dateStr}`,
      balanceAfter: updatedUser.walletBalance,
      status: 'success',
      metadata: { coinsRedeemed: actualCoinsToDeduct },
    });

    await transaction.save();

    console.log(`🪙 [Coins Redeemed] ${updatedUser.userId} converted ${actualCoinsToDeduct} coins to ₹${cashAmount}`);

    res.status(200).json({
      success: true,
      message: `Successfully converted ${actualCoinsToDeduct} coins into ₹${cashAmount} wallet cash`,
      walletBalance: updatedUser.walletBalance,
      coinsBalance: updatedUser.coinsBalance,
      transaction,
    });
  } catch (error) {
    console.error('Error redeeming coins:', error);
    res.status(500).json({ success: false, error: 'Failed to redeem coins' });
  }
};
