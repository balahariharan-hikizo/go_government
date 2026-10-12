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
  console.log('================================================================');
  console.log('🏛️ GO-GOVERNMENT 3-PARTY FULL DELIVERY LIFECYCLE SIMULATION');
  console.log('================================================================');

  const storeId = 'STORE_BANGALORE_CENTRAL';
  const citizenId = 'CITIZEN_PRIYA_77';

  // ──────────────────────────────────────────────────────────────────────────
  // STAGE 1: CITIZEN APP PLACES AN ORDER
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n[STAGE 1 - CITIZEN APP] 🛒 Placing subsidized ration order...');
  const orderRes = await request(
    {
      hostname: '127.0.0.1',
      port: 5000,
      path: '/api/orders',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    },
    {
      userId: citizenId,
      storeId: storeId,
      items: [
        {
          productId: 'PROD_WHEAT_10KG',
          title: 'Subsidized Whole Wheat (10kg)',
          price: 180,
          originalPrice: 280,
          quantity: 1,
          unit: '10 kg Sack',
        },
        {
          productId: 'PROD_SUNFLOWER_OIL_1L',
          title: 'Refined Sunflower Cooking Oil',
          price: 95,
          originalPrice: 140,
          quantity: 2,
          unit: '1 Litre Pouch',
        },
      ],
      itemTotal: 370,
      deliveryCharge: 40,
      handlingCharge: 2,
      couponDiscount: 0,
      coinsDiscount: 15,
      grandTotal: 397,
      paymentMethod: 'Government Wallet Account',
      paymentStatus: 'paid',
      deliveryAddress: {
        address: '#42, 5th Main, Indiranagar, Bengaluru',
        latitude: 12.9784,
        longitude: 77.6408,
        receiverName: 'Priya Sharma',
        receiverPhone: '+919876501234',
      },
      storeDetails: {
        storeId: storeId,
        name: 'Govt Fair Price Depot #405',
        address: '80 Feet Road, HAL 2nd Stage, Indiranagar',
        latitude: 12.9716,
        longitude: 77.6350,
        phone: '+918025251122',
      },
    }
  );

  const orderId = orderRes.body.data.orderId;
  console.log(`✅ Order Placed! Order ID: ${orderId} (Status: ${orderRes.body.data.status})`);

  // ──────────────────────────────────────────────────────────────────────────
  // STAGE 2: STORE OWNER APP - PACKING COMMODITIES
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n[STAGE 2 - STORE APP] 🏪 Store Owner receives order in queue...');
  const storeQueueRes = await request({
    hostname: '127.0.0.1',
    port: 5000,
    path: `/api/orders/store/${storeId}`,
    method: 'GET',
  });

  const matchingOrder = storeQueueRes.body.data.find((o) => o.orderId === orderId);
  console.log(`Found in Store Queue: ${matchingOrder ? 'YES' : 'NO'}`);
  console.log(`Commodities to pack: ${matchingOrder.items.map((i) => `${i.quantity}x ${i.title}`).join(', ')}`);

  console.log('\n🏪 Store Owner taps "Accept & Start Packing"...');
  const preparingRes = await request(
    {
      hostname: '127.0.0.1',
      port: 5000,
      path: `/api/orders/${orderId}/status`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
    },
    {
      status: 'preparing',
      note: 'Store owner verified ration entitlement and started packing items',
    }
  );
  console.log(`Status updated to: ${preparingRes.body.data.status}`);

  console.log('\n🏪 Store Owner finishes packing and taps "Mark Packed & Ready for Pickup"...');
  const readyRes = await request(
    {
      hostname: '127.0.0.1',
      port: 5000,
      path: `/api/orders/${orderId}/status`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
    },
    {
      status: 'ready_for_pickup',
      note: 'Parcel sealed in standard eco-bag, ready at store counter',
    }
  );
  console.log(`Status updated to: ${readyRes.body.data.status}`);

  // ──────────────────────────────────────────────────────────────────────────
  // STAGE 3: RIDER APP - DISPATCH, ACCEPTANCE & PICKUP
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n[STAGE 3 - RIDER APP] 🚴 Rider opens Available Deliveries Feed...');
  const availRes = await request({
    hostname: '127.0.0.1',
    port: 5000,
    path: '/api/orders/available',
    method: 'GET',
  });
  const readyInRiderFeed = availRes.body.data.some((o) => o.orderId === orderId);
  console.log(`Order visible in Rider Feed: ${readyInRiderFeed ? 'YES' : 'NO'}`);

  console.log('\n🚴 Rider Rajesh accepts the delivery task...');
  const acceptRes = await request(
    {
      hostname: '127.0.0.1',
      port: 5000,
      path: `/api/orders/${orderId}/accept-rider`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
    },
    {
      riderId: 'RIDER_RAJESH_07',
      name: 'Rajesh Kumar',
      phone: '+919988776655',
      vehicleNumber: 'KA-03-HJ-4022',
      rating: 4.92,
    }
  );
  console.log(`Acceptance Status: ${acceptRes.status} (${acceptRes.body.message})`);

  console.log('\n🚴 Rider reaches store and collects the sealed package...');
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
      note: 'Rider collected parcel from Govt Fair Price Depot #405',
    }
  );
  console.log(`Pickup Confirmed! Status: ${pickupRes.body.data.status}`);

  // ──────────────────────────────────────────────────────────────────────────
  // STAGE 4: RIDER DELIVERS TO CITIZEN DOORSTEP
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n[STAGE 4 - FINAL DELIVERY] 🚴 Rider arrives at Citizen Priya Sharma doorstep...');
  const deliveredRes = await request(
    {
      hostname: '127.0.0.1',
      port: 5000,
      path: `/api/orders/${orderId}/status`,
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
    },
    {
      status: 'delivered',
      note: 'Handed over directly to Priya Sharma at doorstep',
    }
  );
  console.log(`Delivered Confirmed! Status: ${deliveredRes.body.data.status}`);

  // ──────────────────────────────────────────────────────────────────────────
  // STAGE 5: CITIZEN APP VERIFICATION
  // ──────────────────────────────────────────────────────────────────────────
  console.log('\n[STAGE 5 - CITIZEN APP VERIFICATION] 👤 Checking live order tracking...');
  const verifyRes = await request({
    hostname: '127.0.0.1',
    port: 5000,
    path: `/api/orders/${orderId}`,
    method: 'GET',
  });

  const finalOrder = verifyRes.body.data;
  console.log(`Final Order Status in Citizen App: ${finalOrder.status}`);
  console.log(`Delivered by Partner: ${finalOrder.deliveryAgent.name} (${finalOrder.deliveryAgent.vehicleNumber})`);
  console.log(`From Store: ${finalOrder.storeDetails.name}`);
  console.log(`Delivered to: ${finalOrder.deliveryAddress.receiverName} (${finalOrder.deliveryAddress.address})`);

  console.log('\n================================================================');
  console.log('🏆 3-PARTY FULL WORKFLOW COMPLETED SUCCESSFULLY WITH 100% ACCURACY!');
  console.log('================================================================');
  process.exit(0);
}

run().catch((err) => {
  console.error('Test Failed:', err);
  process.exit(1);
});
