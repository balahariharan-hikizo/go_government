require('dotenv').config();
const http = require('http');
const mongoose = require('mongoose');

const BASE_URL = 'http://127.0.0.1:5000';

function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const normalizedPath = path.startsWith('/api') ? path : `/api${path.startsWith('/') ? '' : '/'}${path}`;
    const url = new URL(normalizedPath, BASE_URL);
    const options = {
      method,
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          const parsed = JSON.parse(data);
          resolve({ status: res.statusCode, body: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function runTests() {
  console.log('🧪 Starting Wallet & Real Payments Flow Tests...\n');
  if (mongoose.connection.readyState === 0) {
    await mongoose.connect(process.env.MONGO_URI);
  }
  const testUser = 'TEST_CITIZEN_' + Date.now().toString().slice(-4);

  // 1. Initial balance check
  console.log('1. Checking initial wallet balance for new user:', testUser);
  const r1 = await request('GET', `/wallet/${testUser}`);
  console.log(`   Status: ${r1.status}, Balance: ₹${r1.body.walletBalance}, Transactions: ${r1.body.transactions.length}`);

  // 2. Top up wallet
  console.log('\n2. Testing POST /wallet/topup (+₹500 via UPI)...');
  const r2 = await request('POST', '/wallet/topup', {
    userId: testUser,
    amount: 500,
    paymentMethod: 'GPay UPI',
    referenceId: 'UPI_REF_987654',
  });
  console.log(`   Status: ${r2.status}, New Balance: ₹${r2.body.walletBalance}`);
  if (r2.body.walletBalance !== 500) throw new Error('Top-up failed to set balance to 500');

  // 3. Purchase using wallet (₹250)
  console.log('\n3. Placing an order of ₹250 paid using "Wallet Account"...');
  const r3 = await request('POST', '/orders', {
    userId: testUser,
    storeId: 'STORE_479113',
    items: [
      { productId: 'PROD_1', title: 'Fresh Milk', price: 50, quantity: 5, unit: '1L' }
    ],
    itemTotal: 250,
    grandTotal: 250,
    paymentMethod: 'Wallet Account',
    deliveryAddress: { address: 'Indiranagar 100ft Rd, Bangalore' },
  });
  const placedOrder = r3.body.order || r3.body.data;
  console.log(`   Status: ${r3.status}, Order ID: ${placedOrder?.orderId}, Payment Status: ${placedOrder?.paymentStatus}`);
  const orderId = placedOrder?.orderId;

  // Check balance after deduction
  const r3Bal = await request('GET', `/wallet/${testUser}`);
  console.log(`   Remaining Balance after ₹250 order: ₹${r3Bal.body.walletBalance}`);
  if (r3Bal.body.walletBalance !== 250) throw new Error('Expected 250 balance after purchase');

  // 4. Overdraft attempt (try to purchase ₹300 with only ₹250 balance)
  console.log('\n4. Testing insufficient balance guard (order ₹300 with balance ₹250)...');
  const r4 = await request('POST', '/orders', {
    userId: testUser,
    storeId: 'STORE_479113',
    items: [
      { productId: 'PROD_2', title: 'Organic Apples', price: 300, quantity: 1, unit: '1kg' }
    ],
    itemTotal: 300,
    grandTotal: 300,
    paymentMethod: 'Wallet Account',
    deliveryAddress: { address: 'Indiranagar 100ft Rd, Bangalore' },
  });
  console.log(`   Status: ${r4.status} (Expected 400), Code: ${r4.body.code}`);
  if (r4.status !== 400 || r4.body.code !== 'INSUFFICIENT_WALLET_BALANCE') {
    throw new Error('Insufficient balance check failed');
  }

  // 5. Cancel order and verify automatic refund
  console.log(`\n5. Cancelling Order #${orderId} and testing automatic wallet refund (+₹250)...`);
  const r5 = await request('PATCH', `/orders/${orderId}/status`, {
    status: 'cancelled',
  });
  console.log(`   Status: ${r5.status}, Order Status: ${r5.body.data?.status}, Payment Status: ${r5.body.data?.paymentStatus}`);

  const r5Bal = await request('GET', `/wallet/${testUser}`);
  console.log(`   Balance after refund: ₹${r5Bal.body.walletBalance}`);
  if (r5Bal.body.walletBalance !== 500) throw new Error('Expected 500 balance after refund');

  // 6. Test Coin Redemption (Give user 250 coins, convert to ₹2)
  console.log('\n6. Testing reward coins redemption (200 coins -> ₹2)...');
  // First seed coins
  const User = require('./models/User');
  await User.findOneAndUpdate({ userId: testUser }, { $set: { coinsBalance: 250 } });

  const r6 = await request('POST', '/wallet/redeem-coins', {
    userId: testUser,
    coins: 200,
  });
  console.log(`   Status: ${r6.status}, New Wallet Balance: ₹${r6.body.walletBalance}, Remaining Coins: ${r6.body.coinsBalance}`);
  if (r6.body.walletBalance !== 502 || r6.body.coinsBalance !== 50) {
    throw new Error('Coin redemption balance calculation incorrect');
  }

  console.log('\n🎉 ALL WALLET & PAYMENT LEDGER TESTS PASSED SUCCESSFULLY! ✅');
  process.exit(0);
}

runTests().catch((err) => {
  console.error('❌ Test failed:', err);
  process.exit(1);
});
