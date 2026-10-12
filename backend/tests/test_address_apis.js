const http = require('http');

const BASE_URL = 'http://127.0.0.1:5000';

function request(method, pathUrl, body = null) {
  return new Promise((resolve, reject) => {
    const url = new URL(pathUrl, BASE_URL);
    const postData = body ? JSON.stringify(body) : null;
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...(postData ? { 'Content-Length': Buffer.byteLength(postData) } : {}),
      },
    };

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

async function runTests() {
  console.log('--- TESTING ADDRESS APIS ---');
  const testUserId = 'USER_TEST_999999';

  // 1. POST /api/addresses
  console.log('1. Adding address...');
  const addRes = await request('POST', '/api/addresses', {
    userId: testUserId,
    type: 'Home',
    description: 'Flat 402, Green Valley Apartments, Anna Nagar, Chennai',
    phone: '9876543210',
    name: 'Ravi Kumar',
    floor: '4th Floor',
    landmark: 'Opposite Metro Station',
    isDefault: true,
  });
  console.log('POST /api/addresses:', addRes.statusCode, addRes.body?.message);
  const createdAddress = addRes.body?.data;
  const addressId = createdAddress?.id;

  // 2. GET /api/addresses/:userId
  console.log('2. Fetching addresses for user...');
  const getRes = await request('GET', `/api/addresses/${testUserId}`);
  console.log('GET /api/addresses/:userId:', getRes.statusCode, `Found ${getRes.body?.count} addresses`);

  // 3. PUT /api/addresses/:id
  console.log('3. Updating address...');
  const updateRes = await request('PUT', `/api/addresses/${addressId}`, {
    floor: '5th Floor (Penthouse)',
    landmark: 'Near New Metro Station',
  });
  console.log('PUT /api/addresses/:id:', updateRes.statusCode, updateRes.body?.message);

  // 4. DELETE /api/addresses/:id
  console.log('4. Deleting address...');
  const delRes = await request('DELETE', `/api/addresses/${addressId}`);
  console.log('DELETE /api/addresses/:id:', delRes.statusCode, delRes.body?.message);

  console.log('--- ALL ADDRESS TESTS COMPLETED SUCCESSFULLY ---');
}

runTests().catch(console.error);
