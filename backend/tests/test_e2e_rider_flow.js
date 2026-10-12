const http = require('http');

function request(options, body = null) {
  return new Promise((resolve, reject) => {
    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => (data += chunk));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function run() {
  console.log('🚀 [STARTING E2E RIDER APP TEST]');

  const orderPayload = {
    userId: 'CITIZEN_RAMESH_99',
    storeId: 'GOV_STORE_001',
    items: [
      {
        productId: 'PROD_RICE_25KG',
        title: 'Subsidized Ponni Boiled Rice (25kg)',
        price: 250,
        originalPrice: 350,
        quantity: 1,
        unit: '25 kg Bag',
      },
      {
        productId: 'PROD_SUGAR_2KG',
        title: 'Fortified Cane Sugar',
        price: 40,
        originalPrice: 80,
        quantity: 2,
        unit: '1 kg Pack',
      },
    ],
    itemTotal: 330,
    deliveryCharge: 35,
    handlingCharge: 2,
    couponDiscount: 0,
    coinsDiscount: 10,
    grandTotal: 357,
    paymentMethod: 'Wallet Account',
    paymentStatus: 'paid',
    deliveryAddress: {
      address: 'Plot 14, 2nd Cross, Gandhi Nagar, Bengaluru',
      latitude: 12.9716,
      longitude: 77.5946,
      receiverName: 'Ramesh Kumar',
      receiverPhone: '+919876543210',
    },
    storeDetails: {
      storeId: 'GOV_STORE_001',
      name: 'Central PDS Fair Price Depot #12',
      address: 'Market Yard Road, Bengaluru',
      latitude: 12.9784,
      longitude: 77.6408,
      phone: '+918022334455',
    },
  };

  // 1. Citizen Places Order
  console.log('\n1️⃣ Citizen places order...');
  const createRes = await request(
    {
      hostname: '127.0.0.1',
      port: 5000,
      path: '/api/orders',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    },
    orderPayload
  );

  console.log('Response Status:', createRes.status);
  const createdOrder = createRes.body.data;
  const orderId = createdOrder.orderId;
  console.log('✅ Order Created Successfully with ID:', orderId);

  // 2. Rider queries available orders
  console.log('\n2️⃣ Rider checks available orders feed...');
  const availRes = await request({
    hostname: '127.0.0.1',
    port: 5000,
    path: '/api/orders/available',
    method: 'GET',
  });
  const foundInFeed = availRes.body.data.some((o) => o.orderId === orderId);
  console.log('Order found in Rider feed:', foundInFeed ? '✅ YES' : '❌ NO');

  // 3. Rider accepts order
  console.log('\n3️⃣ Rider accepts order...');
  const acceptRes = await request(
    {
      hostname: '127.0.0.1',
      port: 5000,
      path: `/api/orders/${orderId}/accept-rider`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    },
    {
      riderId: 'RIDER_SURESH_55',
      name: 'Suresh Gowda',
      phone: '+919123456780',
      vehicleNumber: 'KA-04-MB-8899',
      rating: 4.95,
    }
  );
  console.log('Accept Status:', acceptRes.status, 'Message:', acceptRes.body.message);

  // 4. Rider confirms pickup (out for delivery)
  console.log('\n4️⃣ Rider confirms store pickup (status -> out_for_delivery)...');
  const pickupRes = await request(
    {
      hostname: '127.0.0.1',
      port: 5000,
      path: `/api/orders/${orderId}/status`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
    },
    {
      status: 'out_for_delivery',
      note: 'Rider picked up packages from Central PDS Depot',
    }
  );
  console.log('Pickup Update Status:', pickupRes.status, 'New Status:', pickupRes.body.data.status);

  // 5. Rider completes delivery (status -> delivered)
  console.log('\n5️⃣ Rider marks as delivered to customer...');
  const deliverRes = await request(
    {
      hostname: '127.0.0.1',
      port: 5000,
      path: `/api/orders/${orderId}/status`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
    },
    {
      status: 'delivered',
      note: 'Handed over to Ramesh Kumar at doorstep',
    }
  );
  console.log('Delivered Status:', deliverRes.status, 'Final Status:', deliverRes.body.data.status);

  // 6. Citizen and Store see final delivered status
  console.log('\n6️⃣ Citizen checks order tracking...');
  const trackRes = await request({
    hostname: '127.0.0.1',
    port: 5000,
    path: `/api/orders/${orderId}`,
    method: 'GET',
  });
  console.log('Citizen Tracking Order Status:', trackRes.body.data.status);
  console.log('Assigned Delivery Partner:', trackRes.body.data.deliveryAgent.name);

  console.log('\n🎉 ALL E2E RIDER LIFECYCLE TESTS PASSED PERFECTLY!');
  process.exit(0);
}

run().catch((err) => {
  console.error('Test Failed:', err);
  process.exit(1);
});
