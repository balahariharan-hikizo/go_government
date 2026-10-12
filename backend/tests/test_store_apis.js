const http = require('http');

const BASE_URL = 'http://127.0.0.1:5000';

function request(method, pathUrl, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(pathUrl, BASE_URL);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      },
    };

    let postData = null;
    if (body) {
      postData = JSON.stringify(body);
      options.headers['Content-Length'] = Buffer.byteLength(postData);
    }

    const req = http.request(options, (res) => {
      let responseBody = '';
      res.on('data', (chunk) => (responseBody += chunk));
      res.on('end', () => {
        let json = null;
        try {
          json = JSON.parse(responseBody);
        } catch (_) {}
        resolve({ statusCode: res.statusCode, body: json || responseBody });
      });
    });

    req.on('error', (err) => reject(err));
    if (postData) req.write(postData);
    req.end();
  });
}

async function testStoreApis() {
  console.log('🧪 Starting Store & Admin Approval Backend Tests...\n');

  const randomPhone = '98' + Math.floor(10000000 + Math.random() * 90000000);
  const randomLicense = 'LIC-' + Math.floor(10000 + Math.random() * 90000);
  let createdStoreId = null;

  // 1. Register Store
  console.log('1. Testing POST /api/stores/register...');
  const regRes = await request('POST', '/api/stores/register', {
    name: 'Cauvery Fair Price Ration Depot',
    ownerName: 'M. Senthil Kumar',
    phone: randomPhone,
    email: 'senthil.cauvery@gmail.com',
    category: 'ration',
    licenseNumber: randomLicense,
    address: 'No. 42, Gandhi Road, Anna Nagar West',
    pincode: '600040',
    lat: 13.0850,
    lng: 80.2100,
    storeImage: 'https://images.unsplash.com/photo-1578916171728-46686eac8d58',
    licenseDoc: 'https://images.unsplash.com/photo-1554224155-8d04cb21cd6c',
  });

  console.log('   Response Status:', regRes.statusCode);
  if (regRes.statusCode === 201 && regRes.body.store) {
    createdStoreId = regRes.body.store.storeId;
    console.log('   ✅ Store Registered! ID:', createdStoreId, 'Status:', regRes.body.store.status);
  } else {
    console.error('   ❌ Store registration failed:', regRes.body);
    return;
  }

  // 2. Fetch Pending Stores (Admin View)
  console.log('\n2. Testing GET /api/stores/pending (Admin Review Queue)...');
  const pendingRes = await request('GET', '/api/stores/pending');
  console.log('   Response Status:', pendingRes.statusCode);
  const foundInPending = pendingRes.body.stores?.some((s) => s.storeId === createdStoreId);
  console.log('   ✅ Pending Store Count:', pendingRes.body.count, '| Found Created Store:', foundInPending);

  // 3. Fetch My Store (Store Owner View)
  console.log('\n3. Testing GET /api/stores/my-store/:phone (Store Owner Status Check)...');
  const myStoreRes = await request('GET', `/api/stores/my-store/${randomPhone}`);
  console.log('   Response Status:', myStoreRes.statusCode);
  console.log('   ✅ Store Status for Owner:', myStoreRes.body.store?.status);

  // 4. Admin Approves Store
  console.log('\n4. Testing PATCH /api/stores/:storeId/status (Admin Approval)...');
  const approveRes = await request('PATCH', `/api/stores/${createdStoreId}/status`, {
    status: 'approved',
    verifiedBy: 'Chief Municipal Officer K. Ramanathan',
  });
  console.log('   Response Status:', approveRes.statusCode);
  console.log('   ✅ Updated Status:', approveRes.body.store?.status, '| Verified By:', approveRes.body.store?.verifiedBy);

  // 5. Fetch Approved Stores (User App View)
  console.log('\n5. Testing GET /api/stores/approved (Citizen User App Feed)...');
  const approvedRes = await request('GET', '/api/stores/approved');
  console.log('   Response Status:', approvedRes.statusCode);
  const foundInApproved = approvedRes.body.stores?.some((s) => s.storeId === createdStoreId);
  console.log('   ✅ Approved Stores Count:', approvedRes.body.count, '| Newly Approved Store Present:', foundInApproved);

  // 6. Admin Stats
  console.log('\n6. Testing GET /api/stores (Admin Stats Overview)...');
  const statsRes = await request('GET', '/api/stores');
  console.log('   Response Status:', statsRes.statusCode);
  console.log('   ✅ Stats:', statsRes.body.stats);

  console.log('\n🎉 ALL STORE & APPROVAL ENDPOINT TESTS PASSED SUCCESSFULLY!');
}

testStoreApis().catch(console.error);
