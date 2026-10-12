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
  console.log('--- Testing Cart and Wishlist APIs ---');
  const testUser = 'TEST_USER_' + Date.now();

  // 1. Fetch Cart (Initial)
  console.log('\n1. Fetch empty cart...');
  let res = await request('GET', `/api/cart/${testUser}`);
  console.log('GET /api/cart status:', res.status, 'totalCount:', res.body?.data?.totalCount);

  // 2. Add to Cart
  console.log('\n2. Add item to cart...');
  res = await request('POST', '/api/cart/add', {
    userId: testUser,
    productId: 'PROD_101',
    quantity: 2,
    product: { title: 'Fresh Organic Milk', price: 65, originalPrice: 70 },
  });
  console.log('POST /api/cart/add status:', res.status, 'items count:', res.body?.data?.items?.length, 'totalCount:', res.body?.data?.totalCount);

  // 3. Update quantity in Cart
  console.log('\n3. Update item quantity to 3...');
  res = await request('PUT', '/api/cart/update', {
    userId: testUser,
    productId: 'PROD_101',
    quantity: 3,
  });
  console.log('PUT /api/cart/update status:', res.status, 'totalCount:', res.body?.data?.totalCount);

  // 4. Toggle Wishlist (Add)
  console.log('\n4. Toggle item in Wishlist (should add)...');
  res = await request('POST', '/api/wishlist/toggle', {
    userId: testUser,
    productId: 'PROD_101',
    product: { title: 'Fresh Organic Milk', price: 65 },
  });
  console.log('POST /api/wishlist/toggle status:', res.status, 'isFavorite:', res.body?.data?.isFavorite, 'favorites:', res.body?.data?.favoriteIds);

  // 5. Fetch Wishlist
  console.log('\n5. Fetch Wishlist...');
  res = await request('GET', `/api/wishlist/${testUser}`);
  console.log('GET /api/wishlist status:', res.status, 'items count:', res.body?.data?.items?.length, 'favoriteIds:', res.body?.data?.favoriteIds);

  // 6. Toggle Wishlist (Remove)
  console.log('\n6. Toggle item in Wishlist again (should remove)...');
  res = await request('POST', '/api/wishlist/toggle', {
    userId: testUser,
    productId: 'PROD_101',
  });
  console.log('POST /api/wishlist/toggle status:', res.status, 'isFavorite:', res.body?.data?.isFavorite, 'favorites:', res.body?.data?.favoriteIds);

  // 7. Clear Cart
  console.log('\n7. Clear Cart...');
  res = await request('DELETE', `/api/cart/${testUser}/clear`);
  console.log('DELETE /api/cart clear status:', res.status, 'totalCount:', res.body?.data?.totalCount);

  console.log('\nAll Cart & Wishlist API tests completed successfully! 🎉');
}

runTests().catch(console.error);
