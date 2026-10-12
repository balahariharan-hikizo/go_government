const http = require('http');

function request(method, path, body = null) {
  return new Promise((resolve, reject) => {
    const dataString = body ? JSON.stringify(body) : null;
    const options = {
      hostname: '127.0.0.1',
      port: 5000,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...(dataString ? { 'Content-Length': Buffer.byteLength(dataString) } : {}),
      },
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, body: data });
        }
      });
    });

    req.on('error', reject);
    if (dataString) req.write(dataString);
    req.end();
  });
}

async function runTest() {
  console.log('--- Testing Concurrent Rider Acceptance ---');

  // 1. Create a fresh test order
  const orderPayload = {
    userId: 'USER_TEST',
    storeId: 'STORE_479113',
    items: [
      {
        productId: 'PRD_TEST',
        title: 'Fresh Milk',
        name: 'Fresh Milk',
        price: 35,
        quantity: 1,
      },
    ],
    itemTotal: 35,
    deliveryFee: 15,
    taxes: 2,
    tip: 0,
    totalAmount: 52,
    grandTotal: 52,
    deliveryAddress: {
      address: '123 Main St, Downtown',
      street: '123 Main St',
      area: 'Downtown',
      city: 'Metropolis',
      pincode: '560001',
      lat: 12.9716,
      lng: 77.5946,
    },
    paymentMethod: 'COD',
  };

  const createRes = await request('POST', '/api/orders', orderPayload);
  console.log('createRes status:', createRes.status, 'body:', createRes.body);
  const orderId = createRes.body?.order?.orderId || createRes.body?.data?.orderId;
  console.log('Created order:', orderId);

  // 2. Mark order as ready_for_pickup
  await request('PATCH', `/api/orders/${orderId}/status`, {
    status: 'ready_for_pickup',
  });
  console.log('Order marked ready_for_pickup');

  // 3. Fire TWO concurrent accept requests simultaneously!
  console.log('Firing simultaneous accept requests for Rider A and Rider B...');
  const [resA, resB] = await Promise.all([
    request('POST', `/api/orders/${orderId}/accept-rider`, {
      riderId: 'RIDER_ALICE',
      name: 'Alice',
      phone: '+919999999991',
      vehicleNumber: 'KA-01-A-1111',
    }),
    request('POST', `/api/orders/${orderId}/accept-rider`, {
      riderId: 'RIDER_BOB',
      name: 'Bob',
      phone: '+919999999992',
      vehicleNumber: 'KA-01-B-2222',
    }),
  ]);

  console.log('Rider A response status:', resA.status, resA.body.message || resA.body);
  console.log('Rider B response status:', resB.status, resB.body.message || resB.body);

  const statuses = [resA.status, resB.status];
  const has200 = statuses.includes(200);
  const has409 = statuses.includes(409);

  console.log('\n--- VERIFICATION RESULT ---');
  console.log('Exactly one 200 OK:', has200);
  console.log('Second rider got 409 Conflict:', has409);

  if (has200 && has409) {
    console.log('✅ PASS: Concurrency race condition completely resolved!');
  } else {
    console.log('❌ FAIL: Both succeeded or unexpected status');
  }

  process.exit(0);
}

runTest().catch(console.error);
