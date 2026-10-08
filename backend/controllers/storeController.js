const Store = require('../models/Store');
const { getNextSequence } = require('../utils/sequenceGenerator');

// In-memory cache for new store merchant registration OTPs: phone -> { otp, otpExpires }
const pendingRegistrationOtps = new Map();

// 1. STORE AUTH: SEND OTP
exports.sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    const cleanPhone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const otpExpires = new Date(Date.now() + 5 * 60 * 1000); // 5 min validity

    // Check if store already exists with this phone
    let store = await Store.findOne({ phone: cleanPhone });

    if (!store) {
      // Store does NOT exist yet - store OTP in memory map for new registration
      pendingRegistrationOtps.set(cleanPhone, { otp, otpExpires });

      console.log(`🏪 [Store OTP for New Registration] Sent to ${cleanPhone}: ${otp}`);

      return res.status(200).json({
        success: true,
        isRegistered: false,
        message: `OTP sent successfully to ${cleanPhone}. Please verify to complete store registration.`,
        phone: cleanPhone,
        otp: otp, // Returned for testing
      });
    }

    store.otp = otp;
    store.otpExpires = otpExpires;
    await store.save();

    console.log(`🏪 [Store OTP] Sent to ${cleanPhone}: ${otp}`);

    res.status(200).json({
      success: true,
      isRegistered: true,
      message: `OTP sent successfully to Store ${cleanPhone}`,
      otp: otp, // Returned for testing
      status: store.status,
    });
  } catch (error) {
    console.error('Error sending Store OTP:', error);
    res.status(500).json({ error: 'Failed to send OTP', details: error.message });
  }
};

// 2. STORE AUTH: VERIFY OTP
exports.verifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ error: 'Phone and OTP are required' });
    }

    const cleanPhone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    const store = await Store.findOne({ phone: cleanPhone });

    if (!store) {
      // Check pending registration OTP map
      const pendingRecord = pendingRegistrationOtps.get(cleanPhone);
      if (!pendingRecord) {
        return res.status(404).json({ error: 'No verification request found for this phone. Please request OTP first.' });
      }

      if (pendingRecord.otpExpires && new Date() > pendingRecord.otpExpires) {
        pendingRegistrationOtps.delete(cleanPhone);
        return res.status(400).json({ error: 'OTP has expired. Please request a new one.' });
      }

      if (pendingRecord.otp !== otp.toString().trim()) {
        return res.status(400).json({ error: 'Invalid OTP code. Please enter the correct OTP.' });
      }

      // OTP verified successfully! Clear from pending map
      pendingRegistrationOtps.delete(cleanPhone);

      console.log(`✅ [Store Registration Phone Verified] ${cleanPhone}`);

      return res.status(200).json({
        success: true,
        message: 'Phone verified successfully! Please complete store registration.',
        storeId: '',
        phone: cleanPhone,
        status: 'not_registered',
        isNewUser: true,
        role: 'store_owner',
        store: null,
      });
    }

    if (store.otpExpires && new Date() > store.otpExpires) {
      return res.status(400).json({ error: 'OTP has expired. Please request a new one.' });
    }

    if (store.otp !== otp.toString().trim()) {
      return res.status(400).json({ error: 'Invalid OTP code. Please enter the correct OTP.' });
    }

    // Clear OTP
    store.otp = '';
    await store.save();

    res.status(200).json({
      success: true,
      message: `Welcome back, ${store.name}!`,
      storeId: store.storeId,
      userId: store.storeId,
      status: store.status, // 'pending', 'approved', 'rejected'
      isNewUser: false,
      role: 'store_owner',
      store: store,
      user: {
        userId: store.storeId,
        userName: store.name,
        ownerName: store.ownerName,
        phone: store.phone,
        role: 'store_owner',
      },
    });
  } catch (error) {
    console.error('Error verifying Store OTP:', error);
    res.status(500).json({ error: 'Failed to verify OTP', details: error.message });
  }
};

// 3. REGISTER A NEW STORE (Status defaults to 'pending')
exports.registerStore = async (req, res) => {
  try {
    const {
      name,
      ownerName,
      phone,
      email,
      category,
      address,
      pincode,
      lat,
      lng,
      storeImage,
      timings,
      bankDetails,
      licenseNumber,
      licenseDoc,
    } = req.body;

    if (!name || !ownerName || !phone || !address) {
      return res.status(400).json({
        error: 'Missing required fields: name, ownerName, phone, address are mandatory',
      });
    }

    if (!bankDetails || !bankDetails.bankName || !bankDetails.accountNumber || !bankDetails.ifscCode) {
      return res.status(400).json({
        error: 'Bank details required: bankName, accountNumber, and ifscCode are mandatory',
      });
    }

    const cleanPhone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    const existingStore = await Store.findOne({ phone: cleanPhone });

    if (existingStore) {
      if (existingStore.status === 'rejected') {
        // Re-submit
        existingStore.name = name;
        existingStore.ownerName = ownerName;
        existingStore.email = email || existingStore.email;
        existingStore.category = category || existingStore.category;
        existingStore.address = address;
        existingStore.pincode = pincode || existingStore.pincode;
        if (lat !== undefined && lng !== undefined) {
          existingStore.location = { lat: Number(lat), lng: Number(lng) };
        }
        if (storeImage) existingStore.storeImage = storeImage;
        if (bankDetails) existingStore.bankDetails = bankDetails;
        if (licenseNumber) existingStore.licenseNumber = licenseNumber;
        if (licenseDoc) existingStore.licenseDoc = licenseDoc;
        existingStore.status = 'pending';
        existingStore.rejectionReason = '';
        await existingStore.save();

        return res.status(200).json({
          success: true,
          message: 'Store registration re-submitted for review 📝',
          store: existingStore,
        });
      }

      return res.status(409).json({
        error: `A store with this phone number already exists (${existingStore.status})`,
        storeId: existingStore.storeId,
        status: existingStore.status,
      });
    }

    const storeId = await getNextSequence('storeId', 'STORE_', 5);

    const newStore = new Store({
      storeId,
      name,
      ownerName,
      phone: cleanPhone,
      email: email || '',
      role: 'store_owner',
      category: category || 'general',
      licenseNumber: licenseNumber || '',
      address,
      pincode: pincode || '',
      location: {
        lat: lat !== undefined ? Number(lat) : 0,
        lng: lng !== undefined ? Number(lng) : 0,
      },
      storeImage: storeImage || '',
      licenseDoc: licenseDoc || '',
      bankDetails: {
        bankName: bankDetails.bankName || '',
        accountNumber: bankDetails.accountNumber || '',
        ifscCode: (bankDetails.ifscCode || '').toUpperCase(),
        accountHolderName: bankDetails.accountHolderName || ownerName,
      },
      status: 'pending',
      timings: timings || { open: '08:00 AM', close: '09:00 PM' },
    });

    await newStore.save();

    console.log(`🏪 [Store Registered] ${name} (${storeId}) - Owner: ${cleanPhone} - Status: PENDING`);

    res.status(201).json({
      success: true,
      message: 'Store application submitted successfully! Pending municipal admin approval ⏳',
      store: newStore,
    });
  } catch (error) {
    console.error('Error registering store:', error);
    res.status(500).json({ error: 'Failed to register store', details: error.message });
  }
};

// 4. GET MY STORE BY IDENTIFIER (Phone or StoreId)
exports.getMyStore = async (req, res) => {
  try {
    const { identifier } = req.params;
    const clean = identifier.toString().trim().replace(/[^0-9]/g, '').slice(-10);

    const store = await Store.findOne({
      $or: [{ phone: clean || identifier }, { storeId: identifier }],
    });

    if (!store) {
      return res.status(404).json({ success: false, notFound: true, error: 'No store found for this account' });
    }
    res.status(200).json({ success: true, store });
  } catch (error) {
    console.error('Error fetching store by identifier:', error);
    res.status(500).json({ error: 'Failed to fetch store details' });
  }
};

// 5. GET APPROVED STORES (Citizen App)
exports.getApprovedStores = async (req, res) => {
  try {
    const { category, includeOffline, isOnline } = req.query;
    const filter = { status: 'approved' };

    if (isOnline !== undefined) {
      filter.isOnline = isOnline === 'true';
    } else if (includeOffline !== 'true') {
      filter.isOnline = { $ne: false };
    }

    if (category && category !== 'all') {
      filter.category = category;
    }

    const approvedStores = await Store.find(filter).sort({ createdAt: -1 });
    res.status(200).json({
      success: true,
      count: approvedStores.length,
      stores: approvedStores,
    });
  } catch (error) {
    console.error('Error fetching approved stores:', error);
    res.status(500).json({ error: 'Failed to fetch approved stores' });
  }
};

// 6. GET PENDING STORES (Admin App)
exports.getPendingStores = async (req, res) => {
  try {
    const pendingStores = await Store.find({ status: 'pending' }).sort({ createdAt: -1 });
    res.status(200).json({
      success: true,
      count: pendingStores.length,
      stores: pendingStores,
    });
  } catch (error) {
    console.error('Error fetching pending stores:', error);
    res.status(500).json({ error: 'Failed to fetch pending stores' });
  }
};

// 7. GET ALL STORES (Admin Overview)
exports.getAllStores = async (req, res) => {
  try {
    const { status } = req.query;
    const filter = {};
    if (status) filter.status = status;

    const stores = await Store.find(filter).sort({ createdAt: -1 });
    const pendingCount = await Store.countDocuments({ status: 'pending' });
    const approvedCount = await Store.countDocuments({ status: 'approved' });
    const rejectedCount = await Store.countDocuments({ status: 'rejected' });

    res.status(200).json({
      success: true,
      stats: {
        total: pendingCount + approvedCount + rejectedCount,
        pending: pendingCount,
        approved: approvedCount,
        rejected: rejectedCount,
      },
      stores,
    });
  } catch (error) {
    console.error('Error fetching stores:', error);
    res.status(500).json({ error: 'Failed to fetch stores' });
  }
};

// 8. GET STORE BY ID
exports.getStoreById = async (req, res) => {
  try {
    const { storeId } = req.params;
    const store = await Store.findOne({
      $or: [{ storeId: storeId }, { _id: storeId.match(/^[0-9a-fA-F]{24}$/) ? storeId : null }],
    });
    if (!store) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }
    res.status(200).json({ success: true, store });
  } catch (error) {
    console.error('Error fetching store by ID:', error);
    res.status(500).json({ error: 'Failed to fetch store details' });
  }
};

// 9. TOGGLE ONLINE / OFFLINE
exports.toggleOnline = async (req, res) => {
  try {
    const { storeId } = req.params;
    const { isOnline } = req.body;
    const updatedStore = await Store.findOneAndUpdate(
      { storeId },
      { $set: { isOnline: Boolean(isOnline) } },
      { new: true, runValidators: true }
    );
    if (!updatedStore) {
      return res.status(404).json({ error: 'Store not found' });
    }
    console.log(`🏪 [Store Online Toggle] ${updatedStore.name} is now ${updatedStore.isOnline ? 'ONLINE' : 'OFFLINE'}`);
    res.status(200).json({ success: true, store: updatedStore });
  } catch (error) {
    console.error('Error toggling online status:', error);
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ error: 'Failed to update store online status', details: error.message });
  }
};

// 10. ADMIN REVIEW STORE (Approve / Reject)
exports.reviewStore = async (req, res) => {
  try {
    const { storeId } = req.params;
    const { status, rejectionReason, verifiedBy, isOnline } = req.body;

    if (isOnline !== undefined && !status) {
      const updatedStore = await Store.findOneAndUpdate(
        { storeId },
        { $set: { isOnline: Boolean(isOnline) } },
        { new: true, runValidators: true }
      );
      if (!updatedStore) return res.status(404).json({ error: 'Store not found' });
      return res.status(200).json({ success: true, store: updatedStore });
    }

    if (!['approved', 'rejected', 'pending'].includes(status)) {
      return res.status(400).json({
        error: "Invalid status. Must be 'approved', 'rejected', or 'pending'",
      });
    }

    if (status === 'rejected' && !rejectionReason) {
      return res.status(400).json({
        error: 'Please provide a rejectionReason when rejecting a store application',
      });
    }

    const updateFields = {
      status,
      rejectionReason: status === 'rejected' ? rejectionReason : '',
      verifiedAt: status === 'approved' ? new Date() : null,
      verifiedBy: verifiedBy || 'Municipal Authority',
    };

    const updatedStore = await Store.findOneAndUpdate(
      { storeId },
      { $set: updateFields },
      { new: true, runValidators: true }
    );

    if (!updatedStore) {
      return res.status(404).json({ error: 'Store not found' });
    }

    console.log(
      `🏛️ [Admin Action] Store ${updatedStore.name} (${storeId}) status updated to: ${status.toUpperCase()}`
    );

    res.status(200).json({
      success: true,
      message: `Store ${status} successfully! 🎉`,
      store: updatedStore,
    });
  } catch (error) {
    console.error('Error updating store status:', error);
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ error: 'Failed to update store status', details: error.message });
  }
};

// 11. UPDATE STORE PROFILE
exports.updateProfile = async (req, res) => {
  try {
    const storeId = req.params.storeId || req.body.storeId;
    if (!storeId) {
      return res.status(400).json({ success: false, error: 'storeId is required' });
    }
    const allowedUpdates = [
      'name',
      'ownerName',
      'phone',
      'email',
      'address',
      'pincode',
      'category',
      'storeImage',
      'timings',
    ];

    const updates = {};
    if (req.body.storeName && !req.body.name) {
      updates.name = req.body.storeName;
    }
    if ((req.body.openTime || req.body.closeTime) && !req.body.timings) {
      updates.timings = {
        open: req.body.openTime || '08:00 AM',
        close: req.body.closeTime || '09:00 PM',
      };
    }
    for (const key of allowedUpdates) {
      if (req.body[key] !== undefined) {
        updates[key] = req.body[key];
      }
    }

    if (req.body.lat !== undefined && req.body.lng !== undefined) {
      updates.location = { lat: Number(req.body.lat), lng: Number(req.body.lng) };
    }

    const updatedStore = await Store.findOneAndUpdate(
      { storeId },
      { $set: updates },
      { new: true, runValidators: true }
    );

    if (!updatedStore) {
      return res.status(404).json({ success: false, error: 'Store not found' });
    }

    console.log(`🏪 [Store Profile Updated] ${updatedStore.name} (${storeId}) updated successfully`);

    res.status(200).json({
      success: true,
      message: 'Store profile updated successfully! 🎉',
      store: updatedStore,
    });
  } catch (error) {
    console.error('Error updating store profile:', error);
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ success: false, error: error.message, details: error.message });
  }
};

// 12. UPDATE FCM TOKEN
exports.updateFcmToken = async (req, res) => {
  try {
    const { storeId, phone, fcmToken } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ error: 'fcmToken is required' });
    }

    const query = {};
    if (storeId) query.storeId = storeId;
    else if (phone) query.phone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    else return res.status(400).json({ error: 'storeId or phone is required' });

    await Store.findOneAndUpdate(query, { $set: { fcmToken: fcmToken.trim() } }, { new: true, runValidators: true });

    res.status(200).json({ success: true, message: 'Store FCM token updated' });
  } catch (error) {
    console.error('Error updating store FCM token:', error);
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ error: 'Failed to update store FCM token', details: error.message });
  }
};
