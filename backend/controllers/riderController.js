const Rider = require('../models/Rider');
const { getNextSequence } = require('../utils/sequenceGenerator');
const { sanitizePhone, generateOtp } = require('../utils/commonHelper');

// 1. SEND RIDER OTP
exports.sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ success: false, error: 'Phone number is required' });
    }

    const cleanPhone = sanitizePhone(phone);
    const { otp, otpExpires } = generateOtp(5);


    // Fast path: existing rider (95%+ traffic) - Single atomic DB call
    let rider = await Rider.findOneAndUpdate(
      { phone: cleanPhone },
      { $set: { otp, otpExpires } },
      { returnDocument: 'after' }
    );

    if (!rider) {
      const riderId = await getNextSequence('riderId', 'RDR_', 5);
      rider = await Rider.create({
        phone: cleanPhone,
        riderId,
        role: 'rider',
        otp,
        otpExpires,
      });
    }

    console.log(`🛵 [Rider OTP] Sent to ${cleanPhone}: ${otp}`);

    res.status(200).json({
      success: true,
      message: `OTP sent successfully to Rider ${cleanPhone}`,
      otp: otp, // Returned for testing
    });
  } catch (error) {
    console.error('Error sending Rider OTP:', error);
    res.status(500).json({ success: false, error: 'Failed to send OTP', details: error.message });
  }
};

// 2. VERIFY RIDER OTP
exports.verifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ success: false, error: 'Phone and OTP are required' });
    }

    const cleanPhone = sanitizePhone(phone);
    const cleanOtp = otp.toString().trim();

    // Single atomic query: verify and clear OTP in 1 DB call
    const rider = await Rider.findOneAndUpdate(
      {
        phone: cleanPhone,
        otp: cleanOtp,
        otpExpires: { $gte: new Date() },
      },
      { $set: { otp: '' } },
      { returnDocument: 'after' }
    );

    if (!rider) {
      return res.status(400).json({ success: false, error: 'Invalid or expired OTP code. Please enter the correct OTP.' });
    }

    const hasProfile = Boolean(rider.name && rider.name.trim().length > 0 && rider.vehicleNumber && rider.vehicleNumber.trim().length > 0);
    const isNewRider = !hasProfile;

    res.status(200).json({
      success: true,
      message: isNewRider ? 'Welcome new Rider! Please complete your vehicle profile.' : 'Welcome back Rider!',
      isNewRider: isNewRider,
      isNewUser: isNewRider,
      riderId: rider.riderId,
      userId: rider.riderId,
      role: 'rider',
      rider: rider,
      user: {
        userId: rider.riderId,
        userName: rider.name,
        phone: rider.phone,
        role: 'rider',
        vehicleType: rider.vehicleType,
        vehicleNumber: rider.vehicleNumber,
        profileImage: rider.profileImage,
      },
    });
  } catch (error) {
    console.error('Error verifying Rider OTP:', error);
    res.status(500).json({ success: false, error: 'Failed to verify OTP', details: error.message });
  }
};

// 3. GET RIDER PROFILE
exports.getProfile = async (req, res) => {
  try {
    const id = req.params.riderId;
    const rider = await Rider.findOne({ $or: [{ riderId: id }, { phone: id }] });
    if (!rider) {
      return res.status(404).json({ success: false, error: 'Rider not found' });
    }
    const riderData = rider.toObject ? rider.toObject() : rider;
    res.status(200).json({
      success: true,
      rider: riderData,
      ...riderData,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Failed to fetch Rider profile', details: error.message });
  }
};

// 4. UPDATE RIDER PROFILE (Vehicle, License, Name)
const normalizeVehicleType = (type) => {
  if (!type) return undefined;
  const lower = type.toString().trim().toLowerCase();
  if (lower.includes('motorcycle') || lower.includes('bike')) return 'bike';
  if (lower.includes('scooter')) return 'scooter';
  if (lower.includes('ev') || lower.includes('electric')) return 'ev';
  if (lower.includes('cycle') || lower.includes('bicycle')) return 'cycle';
  if (['bike', 'scooter', 'ev', 'cycle', 'other'].includes(lower)) return lower;
  return 'other';
};

exports.updateProfile = async (req, res) => {
  try {
    const targetRiderId = req.body.riderId || req.body.userId;
    const targetName = req.body.name || req.body.userName;
    const { 
      email, 
      profileImage, 
      vehicleType, 
      vehicleNumber, 
      drivingLicenseNumber, 
      drivingLicenseDoc 
    } = req.body;

    if (!targetRiderId) {
      return res.status(400).json({ success: false, error: 'riderId or userId is required' });
    }

    const cleanVehicleType = normalizeVehicleType(vehicleType);

    const updatedRider = await Rider.findOneAndUpdate(
      { riderId: targetRiderId },
      {
        $set: {
          ...(targetName && { name: targetName.trim() }),
          ...(email && { email: email.trim().toLowerCase() }),
          ...(profileImage && { profileImage }),
          ...(cleanVehicleType && { vehicleType: cleanVehicleType }),
          ...(vehicleNumber && { vehicleNumber: vehicleNumber.trim() }),
          ...(drivingLicenseNumber && { drivingLicenseNumber: drivingLicenseNumber.trim() }),
          ...(drivingLicenseDoc && { drivingLicenseDoc }),
        },
      },
      { returnDocument: 'after', runValidators: true }
    );

    if (!updatedRider) {
      return res.status(404).json({ success: false, error: 'Rider not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Rider profile updated successfully',
      rider: updatedRider,
    });
  } catch (error) {
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ success: false, error: 'Failed to update Rider profile', details: error.message });
  }
};

// 5. TOGGLE ONLINE / OFFLINE STATUS
exports.toggleOnline = async (req, res) => {
  try {
    const { riderId, isOnline } = req.body;

    if (!riderId || isOnline === undefined) {
      return res.status(400).json({ success: false, error: 'riderId and isOnline (boolean) are required' });
    }

    const rider = await Rider.findOneAndUpdate(
      { riderId },
      { $set: { isOnline: Boolean(isOnline) } },
      { returnDocument: 'after', runValidators: true }
    );

    if (!rider) {
      return res.status(404).json({ success: false, error: 'Rider not found' });
    }

    // Sync in-memory riderRegistry for live monitoring & dispatching
    const riderRegistry = req.app.get('riderRegistry');
    if (riderRegistry) {
      const existing = riderRegistry.get(riderId) || {};
      riderRegistry.set(riderId, {
        ...existing,
        isOnline: Boolean(isOnline),
        lastSeen: Date.now(),
      });
    }

    const io = req.app.get('io');
    if (io) {
      const existing = riderRegistry ? riderRegistry.get(riderId) : null;
      if (existing?.socketId) {
        const s = io.sockets.sockets.get(existing.socketId);
        if (s) {
          if (Boolean(isOnline)) {
            s.join('online_riders');
          } else {
            s.leave('online_riders');
          }
        }
      }
      io.emit('rider_status_changed', {
        riderId: rider.riderId,
        isOnline: rider.isOnline,
        currentLocation: rider.currentLocation,
      });
      io.emit('riders_changed', { riderId: rider.riderId, isOnline: rider.isOnline });
    }

    res.status(200).json({
      success: true,
      message: `Rider is now ${rider.isOnline ? 'ONLINE' : 'OFFLINE'}`,
      isOnline: rider.isOnline,
    });
  } catch (error) {
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ success: false, error: 'Failed to update status', details: error.message });
  }
};

// 6. UPDATE LIVE GPS LOCATION
exports.updateLocation = async (req, res) => {
  try {
    const { riderId, lat, lng, isOnline } = req.body;

    if (!riderId || lat === undefined || lng === undefined) {
      return res.status(400).json({ success: false, error: 'riderId, lat, and lng are required' });
    }

    const updateFields = {
      'currentLocation.lat': Number(lat),
      'currentLocation.lng': Number(lng),
    };
    if (isOnline !== undefined) {
      updateFields.isOnline = Boolean(isOnline);
    }

    const updatedRider = await Rider.findOneAndUpdate(
      { riderId },
      { $set: updateFields },
      { returnDocument: 'after', runValidators: true }
    );

    if (!updatedRider) {
      return res.status(404).json({ success: false, error: 'Rider not found' });
    }

    // Sync in-memory riderRegistry for nearest rider dispatching
    const riderRegistry = req.app.get('riderRegistry');
    if (riderRegistry) {
      const existing = riderRegistry.get(riderId) || {};
      riderRegistry.set(riderId, {
        ...existing,
        lat: Number(lat),
        lng: Number(lng),
        ...(isOnline !== undefined && { isOnline: Boolean(isOnline) }),
        lastSeen: Date.now(),
      });
    }

    const io = req.app.get('io');
    if (io) {
      io.emit('rider_location_updated', {
        riderId,
        lat: Number(lat),
        lng: Number(lng),
        isOnline: updatedRider.isOnline,
      });
    }

    res.status(200).json({
      success: true,
      message: 'Location updated',
      currentLocation: updatedRider.currentLocation,
    });
  } catch (error) {
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ success: false, error: 'Failed to update location', details: error.message });
  }
};

// 7. UPDATE FCM TOKEN
exports.updateFcmToken = async (req, res) => {
  try {
    const targetId = req.body.riderId || req.body.userId;
    const { fcmToken, phone } = req.body;

    if (!targetId && !phone) {
      return res.status(400).json({ success: false, error: 'riderId or phone is required' });
    }
    if (!fcmToken) {
      return res.status(400).json({ success: false, error: 'fcmToken is required' });
    }

    const cleanToken = fcmToken.trim();

    const query = {};
    if (targetId && phone) query.$or = [{ riderId: targetId }, { phone }];
    else if (targetId) query.riderId = targetId;
    else query.phone = phone;

    const rider = await Rider.findOneAndUpdate(
      query,
      { $set: { fcmToken: cleanToken } },
      { returnDocument: 'after', runValidators: true }
    );

    res.status(200).json({
      success: true,
      message: 'Rider FCM token updated',
      riderId: rider?.riderId || targetId,
      fcmToken: cleanToken,
    });
  } catch (error) {
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ success: false, error: 'Failed to update FCM token', details: error.message });
  }
};

// 8. RIDER LOGOUT
exports.logout = async (req, res) => {
  try {
    const targetId = req.body.riderId || req.body.userId;
    const { phone } = req.body;

    if (!targetId && !phone) {
      return res.status(400).json({ success: false, error: 'riderId or phone is required' });
    }

    const cleanPhone = phone ? phone.toString().trim().replace(/[^0-9]/g, '').slice(-10) : undefined;

    const query = {};
    if (targetId && cleanPhone) query.$or = [{ riderId: targetId }, { phone: cleanPhone }];
    else if (targetId) query.riderId = targetId;
    else if (cleanPhone) query.phone = cleanPhone;

    const rider = await Rider.findOneAndUpdate(
      query,
      { $set: { fcmToken: '', isOnline: false } },
      { returnDocument: 'after' }
    );

    // Clear registry if rider was registered
    const riderId = rider?.riderId || targetId;
    const riderRegistry = req.app.get('riderRegistry');
    if (riderRegistry && riderId && riderRegistry.has(riderId)) {
      const existing = riderRegistry.get(riderId);
      if (existing.disconnectTimer) clearTimeout(existing.disconnectTimer);
      riderRegistry.set(riderId, {
        ...existing,
        lat: 0,
        lng: 0,
        isOnline: false,
        lastSeen: Date.now(),
      });
    }

    const io = req.app.get('io');
    if (io && riderId) {
      io.emit('rider_status_changed', { riderId, isOnline: false });
      io.emit('riders_changed', { riderId, isOnline: false });
    }

    if (!rider) {
      return res.status(404).json({ success: false, error: 'Rider not found' });
    }

    res.status(200).json({ success: true, message: 'Rider logged out successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Failed to logout', details: error.message });
  }
};
