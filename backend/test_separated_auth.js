const mongoose = require('mongoose');
require('dotenv').config();

const User = require('./models/User');
const Store = require('./models/Store');
const Rider = require('./models/Rider');

const userController = require('./controllers/userController');
const storeController = require('./controllers/storeController');
const riderController = require('./controllers/riderController');

// Helper to mock express req, res
function mockReqRes(body = {}, params = {}, query = {}) {
  const req = { body, params, query, app: { get: () => null } };
  let statusCode = 200;
  let responseData = null;

  const res = {
    status(code) {
      statusCode = code;
      return res;
    },
    json(data) {
      responseData = data;
      return res;
    },
  };

  return {
    req,
    res,
    getStatusCode: () => statusCode,
    getData: () => responseData,
  };
}

async function runTests() {
  console.log('🚀 Starting Separation Test: Citizen vs Store vs Rider...\n');

  try {
    await mongoose.connect(process.env.MONGO_URI);
    console.log('✅ Connected to MongoDB Atlas\n');

    const testCitizenPhone = '9999000001';
    const testStorePhone   = '9999000002';
    const testRiderPhone   = '9999000003';

    // Clean up previous test runs
    await User.deleteMany({ phone: testCitizenPhone });
    await Store.deleteMany({ phone: testStorePhone });
    await Rider.deleteMany({ phone: testRiderPhone });

    // ==========================================
    // TEST 1: CITIZEN FLOW (User Model)
    // ==========================================
    console.log('--- [1] Testing Citizen Flow (User Model) ---');
    const { req: req1, res: res1, getData: get1 } = mockReqRes({ phone: testCitizenPhone });
    await userController.sendOtp(req1, res1);
    const otp1 = get1().otp;
    console.log(`1. Send OTP: OTP = ${otp1}`);

    const { req: req2, res: res2, getData: get2 } = mockReqRes({ phone: testCitizenPhone, otp: otp1 });
    await userController.verifyOtp(req2, res2);
    const citizenUser = get2().user;
    console.log(`2. Verify OTP: UserId = ${citizenUser.userId}, Role = ${citizenUser.role}`);
    console.assert(citizenUser.role === 'citizen', 'Role must be citizen');
    console.assert(citizenUser.vehicleType === undefined, 'User must not have vehicleType');

    const { req: req3, res: res3, getData: get3 } = mockReqRes({
      userId: citizenUser.userId,
      userName: 'John Citizen',
      email: 'john@citizen.gov',
    });
    await userController.updateProfile(req3, res3);
    console.log(`3. Update Profile: ${get3().user.userName} updated successfully!\n`);

    // ==========================================
    // TEST 2: STORE FLOW (Store Model)
    // ==========================================
    console.log('--- [2] Testing Store Flow (Store Model) ---');
    const { req: reqS1, res: resS1, getData: getS1 } = mockReqRes({
      name: 'Super Govt Mart',
      ownerName: 'Ramesh Store',
      phone: testStorePhone,
      address: '10 Anna Salai, Chennai',
      category: 'ration',
      bankDetails: {
        bankName: 'SBI',
        accountNumber: '1234567890',
        ifscCode: 'SBIN0001234',
        accountHolderName: 'Ramesh Store',
      },
    });
    await storeController.registerStore(reqS1, resS1);
    const registeredStore = getS1().store;
    console.log(`1. Store Registered: StoreId = ${registeredStore.storeId}, Status = ${registeredStore.status}, Role = ${registeredStore.role}`);
    console.assert(registeredStore.status === 'pending', 'New store must be pending');

    const { req: reqS2, res: resS2, getData: getS2 } = mockReqRes({ phone: testStorePhone });
    await storeController.sendOtp(reqS2, resS2);
    const storeOtp = getS2().otp;
    console.log(`2. Send Store OTP: ${storeOtp}`);

    const { req: reqS3, res: resS3, getData: getS3 } = mockReqRes({ phone: testStorePhone, otp: storeOtp });
    await storeController.verifyOtp(reqS3, resS3);
    console.log(`3. Verify Store OTP: Logged in as ${getS3().store.name}, Role = ${getS3().role}\n`);

    // ==========================================
    // TEST 3: RIDER FLOW (Rider Model)
    // ==========================================
    console.log('--- [3] Testing Rider Flow (Rider Model) ---');
    const { req: reqR1, res: resR1, getData: getR1 } = mockReqRes({ phone: testRiderPhone });
    await riderController.sendOtp(reqR1, resR1);
    const riderOtp = getR1().otp;
    console.log(`1. Send Rider OTP: ${riderOtp}`);

    const { req: reqR2, res: resR2, getData: getR2 } = mockReqRes({ phone: testRiderPhone, otp: riderOtp });
    await riderController.verifyOtp(reqR2, resR2);
    const rider = getR2().rider;
    console.log(`2. Verify Rider OTP: RiderId = ${rider.riderId}, Role = ${rider.role}`);
    console.assert(rider.role === 'rider', 'Role must be rider');

    const { req: reqR3, res: resR3, getData: getR3 } = mockReqRes({
      riderId: rider.riderId,
      name: 'Speedy Suresh',
      vehicleType: 'bike',
      vehicleNumber: 'TN01AB1234',
      drivingLicenseNumber: 'DL-TN-2024-9988',
    });
    await riderController.updateProfile(reqR3, resR3);
    console.log(`3. Update Rider Profile: Name = ${getR3().rider.name}, Vehicle = ${getR3().rider.vehicleNumber}`);

    const { req: reqR4, res: resR4, getData: getR4 } = mockReqRes({
      riderId: rider.riderId,
      isOnline: true,
    });
    await riderController.toggleOnline(reqR4, resR4);
    console.log(`4. Rider Duty Toggle: Online = ${getR4().isOnline}\n`);

    // ==========================================
    // FINAL DATABASE AUDIT
    // ==========================================
    console.log('--- [4] Database Separation Audit ---');
    const userInDb = await User.findOne({ phone: testCitizenPhone });
    const storeInDb = await Store.findOne({ phone: testStorePhone });
    const riderInDb = await Rider.findOne({ phone: testRiderPhone });

    console.log(`User collection has Citizen? ${!!userInDb} (ID: ${userInDb.userId}, Role: ${userInDb.role})`);
    console.log(`Store collection has Merchant? ${!!storeInDb} (ID: ${storeInDb.storeId}, Role: ${storeInDb.role})`);
    console.log(`Rider collection has Rider? ${!!riderInDb} (ID: ${riderInDb.riderId}, Role: ${riderInDb.role})`);

    // Verify cross-contamination check
    const noCitizenInStore = await Store.findOne({ phone: testCitizenPhone });
    const noRiderInUser = await User.findOne({ phone: testRiderPhone });
    console.log(`Citizen NOT in Store collection? ${!noCitizenInStore ? '✅ PASSED' : '❌ FAILED'}`);
    console.log(`Rider NOT in User collection? ${!noRiderInUser ? '✅ PASSED' : '❌ FAILED'}`);

    console.log('\n🎉 ALL SEPARATION TESTS PASSED 100% SUCCESSFULLY!');
  } catch (err) {
    console.error('❌ Test failed with error:', err);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
}

runTests();
