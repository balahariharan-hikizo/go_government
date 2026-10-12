const http = require('http');
const fs = require('fs');
const path = require('path');

const BASE_URL = 'http://127.0.0.1:5000';

function request(method, pathUrl, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(pathUrl, BASE_URL);
    const options = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method: method,
      headers: { ...headers },
    };

    let postData = null;
    if (body && !headers['Content-Type']?.includes('multipart/form-data')) {
      postData = JSON.stringify(body);
      options.headers['Content-Type'] = 'application/json';
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

function uploadFile(pathUrl, filePath, fieldName = 'image') {
  return new Promise((resolve, reject) => {
    const boundary = '----WebKitFormBoundary' + Math.random().toString(36).substring(2);
    const url = new URL(pathUrl, BASE_URL);
    const filename = path.basename(filePath);
    const fileData = fs.readFileSync(filePath);

    let header = `--${boundary}\r\n`;
    header += `Content-Disposition: form-data; name="${fieldName}"; filename="${filename}"\r\n`;
    header += `Content-Type: image/jpeg\r\n\r\n`;

    const footer = `\r\n--${boundary}--\r\n`;

    const payload = Buffer.concat([
      Buffer.from(header, 'utf8'),
      fileData,
      Buffer.from(footer, 'utf8'),
    ]);

    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname,
        method: 'POST',
        headers: {
          'Content-Type': `multipart/form-data; boundary=${boundary}`,
          'Content-Length': payload.length,
        },
      },
      (res) => {
        let responseBody = '';
        res.on('data', (chunk) => (responseBody += chunk));
        res.on('end', () => {
          let json = null;
          try {
            json = JSON.parse(responseBody);
          } catch (_) {}
          resolve({ statusCode: res.statusCode, body: json || responseBody });
        });
      }
    );

    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function runTests() {
  console.log('==============================================');
  console.log('  TESTING ALL NODE.JS BACKEND APIS LIVE');
  console.log('==============================================\n');

  const testPhone = '9876543210';
  let testUserId = 'CTZ_TEST_' + Date.now();
  let generatedOtp = '';
  let uploadedComplaintImg = '';
  let uploadedProfileImg = '';
  let testComplaintId = 'CMP' + Date.now().toString().substring(6);

  // 1. Health Check
  try {
    const res = await request('GET', '/api/health');
    console.log('[1] GET /api/health -> Status:', res.statusCode, res.body);
  } catch (e) {
    console.error('[1] GET /api/health FAILED:', e.message);
  }

  // 2. Auth: Send OTP
  try {
    const res = await request('POST', '/api/auth/send-otp', { phone: testPhone });
    console.log('[2] POST /api/auth/send-otp -> Status:', res.statusCode, res.body);
    generatedOtp = res.body?.otp;
  } catch (e) {
    console.error('[2] POST /api/auth/send-otp FAILED:', e.message);
  }

  // 3. Auth: Verify OTP
  try {
    const res = await request('POST', '/api/auth/verify-otp', { phone: testPhone, otp: generatedOtp });
    console.log('[3] POST /api/auth/verify-otp -> Status:', res.statusCode, res.body);
    if (res.body?.userId) testUserId = res.body.userId;
    else if (res.body?.user?.userId) testUserId = res.body.user.userId;
  } catch (e) {
    console.error('[3] POST /api/auth/verify-otp FAILED:', e.message);
  }

  // 4. File Upload (Complaint)
  const sampleImagePath = path.join(__dirname, '..', 'assets', 'images', 'report1.png');
  try {
    if (fs.existsSync(sampleImagePath)) {
      const res = await uploadFile('/api/upload', sampleImagePath, 'image');
      console.log('[4] POST /api/upload -> Status:', res.statusCode, res.body);
      uploadedComplaintImg = res.body?.imageUrl;
    } else {
      console.log('[4] POST /api/upload -> Sample file not found, skipping multipart test');
    }
  } catch (e) {
    console.error('[4] POST /api/upload FAILED:', e.message);
  }

  // 5. File Upload (Profile)
  try {
    if (fs.existsSync(sampleImagePath)) {
      const res = await uploadFile('/api/upload/profile', sampleImagePath, 'image');
      console.log('[5] POST /api/upload/profile -> Status:', res.statusCode, res.body);
      uploadedProfileImg = res.body?.imageUrl;
    }
  } catch (e) {
    console.error('[5] POST /api/upload/profile FAILED:', e.message);
  }

  // 6. Auth: Update Profile
  try {
    const res = await request('POST', '/api/auth/profile', {
      userId: testUserId,
      userName: 'Test Citizen',
      email: 'citizen@test.com',
      profileImage: uploadedProfileImg || '',
    });
    console.log('[6] POST /api/auth/profile -> Status:', res.statusCode, res.body);
  } catch (e) {
    console.error('[6] POST /api/auth/profile FAILED:', e.message);
  }

  // 7. Auth: Get Profile
  try {
    const res = await request('GET', `/api/auth/profile/${testUserId}`);
    console.log('[7] GET /api/auth/profile/:userId -> Status:', res.statusCode, res.body);
  } catch (e) {
    console.error('[7] GET /api/auth/profile/:userId FAILED:', e.message);
  }

  // 8. Complaints: Create Complaint
  try {
    const complaintData = {
      complaintId: testComplaintId,
      userId: testUserId,
      userName: 'Test Citizen',
      userAddress: 'Anna Nagar, Chennai, Tamil Nadu',
      category: 'Pothole & Road Damage',
      description: 'Big pothole on 2nd main road causing traffic delays.',
      status: 'Under Review',
      statusColor: 0xFFFF5252,
      imagePath: uploadedComplaintImg || 'https://via.placeholder.com/300',
      date: 'Today, 6:40 PM',
      likesCount: 0,
      isLiked: false,
      comments: [],
    };
    const res = await request('POST', '/api/complaints', complaintData);
    console.log('[8] POST /api/complaints -> Status:', res.statusCode, res.body);
  } catch (e) {
    console.error('[8] POST /api/complaints FAILED:', e.message);
  }

  // 9. Complaints: Get All Complaints
  try {
    const res = await request('GET', '/api/complaints');
    console.log('[9] GET /api/complaints -> Status:', res.statusCode, 'Count:', res.body?.length);
  } catch (e) {
    console.error('[9] GET /api/complaints FAILED:', e.message);
  }

  // 10. Complaints: Get User Specific Complaints
  try {
    const res = await request('GET', `/api/complaints/user/${testUserId}`);
    console.log('[10] GET /api/complaints/user/:userId -> Status:', res.statusCode, 'Count:', res.body?.length);
  } catch (e) {
    console.error('[10] GET /api/complaints/user/:userId FAILED:', e.message);
  }

  // 11. Complaints: Toggle Like
  try {
    const res = await request('POST', `/api/complaints/${testComplaintId}/like`, {
      citizenId: testUserId,
      isCurrentlyLiked: false,
    });
    console.log('[11] POST /api/complaints/:id/like -> Status:', res.statusCode, res.body);
  } catch (e) {
    console.error('[11] POST /api/complaints/:id/like FAILED:', e.message);
  }

  // 12. Complaints: Add Comment
  try {
    const res = await request('POST', `/api/complaints/${testComplaintId}/comment`, {
      citizenId: testUserId,
      userName: 'Civic Volunteer',
      comment: 'Reported this to municipal ward office.',
    });
    console.log('[12] POST /api/complaints/:id/comment -> Status:', res.statusCode, res.body);
  } catch (e) {
    console.error('[12] POST /api/complaints/:id/comment FAILED:', e.message);
  }

  console.log('\n==============================================');
  console.log('  ALL ENDPOINT TESTS COMPLETED');
  console.log('==============================================');
}

runTests();
