const express = require('express');
const router = express.Router();
const walletController = require('../controllers/walletController');

// 1. Fetch Wallet & History
router.get('/:userId', walletController.getWalletDetails);

// 2. Financial Transactions
router.post('/topup', walletController.topupWallet);
router.post('/deduct', walletController.deductWallet);
router.post('/refund', walletController.refundWallet);
router.post('/redeem-coins', walletController.redeemCoins);

module.exports = router;
