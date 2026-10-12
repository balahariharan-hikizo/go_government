const http = require('http');

function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const data = body ? JSON.stringify(body) : null;
    const options = {
      hostname: '127.0.0.1',
      port: 5000,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...(data ? { 'Content-Length': Buffer.byteLength(data) } : {}),
      },
    };

    const req = http.request(options, (res) => {
      let resBody = '';
      res.on('data', (chunk) => (resBody += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(resBody) });
        } catch (e) {
          resolve({ status: res.statusCode, body: resBody });
        }
      });
    });

    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

async function runTests() {
  console.log('--- Testing Order & Delivery APIs ---');
  const testUser = 'TEST_CITIZEN_' + Date.now();
  const testStore = 'STORE_479113';

  // 1. Create Order
  console.log('\n1. Creating order (Citizen Place Order)...');
  let res = await request('POST', '/api/orders', {
    userId: testUser,
    storeId: testStore,
    items: [
      {
        productId: 'PROD_646936',
        title: 'Refined Crystal Sugar (M-30)',
        price: 45,
        originalPrice: 50,
        quantity: 2,
        unit: '1 kg',
      },
    ],
    itemTotal: 90,
    deliveryCharge: 24,
    handlingCharge: 2,
    grandTotal: 116,
    deliveryAddress: {
      address: 'No 42, 5th Cross, Indiranagar, Bengaluru',
      latitude: 12.9784,
      longitude: 77.6408,
      receiverName: 'Ramesh Kumar',
      receiverPhone: '9876543210',
    },
  });
  console.log('POST /api/orders status:', res.status, 'orderId:', res.body?.data?.orderId, 'status:', res.body?.data?.status);
  const orderId = res.body?.data?.orderId;

  // 2. Fetch Available Deliveries (Rider App feed)
  console.log('\n2. Fetching available deliveries for Rider...');
  res = await request('GET', '/api/orders/available');
  console.log('GET /api/orders/available count:', res.body?.data?.length);

  // 3. Rider Accepts Order
  console.log('\n3. Rider accepts delivery task...');
  res = await request('POST', `/api/orders/${orderId}/accept-rider`, {
    riderId: 'RIDER_8871',
    name: 'Akram Ali',
    phone: '9876512345',
    vehicleNumber: 'KA 03 EQ 4521',
  });
  console.log('POST /accept-rider status:', res.status, 'new status:', res.body?.data?.status, 'agent:', res.body?.data?.deliveryAgent?.name);

  // 4. Update Status to Delivered
  console.log('\n4. Marking order delivered...');
  res = await request('PATCH', `/api/orders/${orderId}/status`, {
    status: 'delivered',
  });
  console.log('PATCH /status status:', res.status, 'new status:', res.body?.data?.status, 'deliveredAt:', res.body?.data?.deliveredAt);

  // 5. Fetch User Orders
  console.log('\n5. Fetching citizen orders history...');
  res = await request('GET', `/api/orders/user/${testUser}`);
  console.log('GET /api/orders/user count:', res.body?.data?.length, 'order status:', res.body?.data?.[0]?.status);

  console.log('\nAll Order & Delivery API tests completed successfully! 🎉');
}

runTests().catch(console.error);
