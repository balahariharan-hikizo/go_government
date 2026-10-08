const Rider = require('../models/Rider');
const { getNextSequence } = require('../utils/sequenceGenerator');

// 1. SEND RIDER OTP
exports.sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    const cleanPhone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const otpExpires = new Date(Date.now() + 5 * 60 * 1000);

    let rider = await Rider.findOne({ phone: cleanPhone });
    if (!rider) {
      const riderId = await getNextSequence('riderId', 'RDR_', 5);
      try {
        rider = await Rider.create({
          phone: cleanPhone,
          riderId,
          role: 'rider',
          otp,
          otpExpires,
        });
      } catch (err) {
        if (err.code === 11000) {
          rider = await Rider.findOneAndUpdate(
            { phone: cleanPhone },
            { $set: { otp, otpExpires } },
            { returnDocument: 'after' }
          );
        } else {
          throw err;
        }
      }
    } else {
      rider.otp = otp;
      rider.otpExpires = otpExpires;
      await rider.save();
    }

    console.log(`🛵 [Rider OTP] Sent to ${cleanPhone}: ${otp}`);

    res.status(200).json({
      success: true,
      message: `OTP sent successfully to Rider ${cleanPhone}`,
      otp: otp, // Returned for testing
    });
  } catch (error) {
    console.error('Error sending Rider OTP:', error);
    res.status(500).json({ error: 'Failed to send OTP', details: error.message });
  }
};

// 2. VERIFY RIDER OTP
exports.verifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ error: 'Phone and OTP are required' });
    }

    const cleanPhone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    const rider = await Rider.findOne({ phone: cleanPhone });

    if (!rider) {
      return res.status(404).json({ error: 'Rider not found. Please request OTP first.' });
    }

    if (rider.otpExpires && new Date() > rider.otpExpires) {
      return res.status(400).json({ error: 'OTP has expired. Please request a new one.' });
    }

    if (rider.otp !== otp.toString().trim()) {
      return res.status(400).json({ error: 'Invalid OTP code. Please enter the correct OTP.' });
    }

    // Clear OTP
    rider.otp = '';
    await rider.save();

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
    res.status(500).json({ error: 'Failed to verify OTP', details: error.message });
  }
};

// 3. GET RIDER PROFILE
exports.getProfile = async (req, res) => {
  try {
    const id = req.params.riderId;
    const rider = await Rider.findOne({ $or: [{ riderId: id }, { phone: id }] });
    if (!rider) {
      return res.status(404).json({ error: 'Rider not found' });
    }
    res.status(200).json(rider);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch Rider profile', details: error.message });
  }
};

// 4. UPDATE RIDER PROFILE (Vehicle, License, Name)
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
      return res.status(400).json({ error: 'riderId or userId is required' });
    }

    const updatedRider = await Rider.findOneAndUpdate(
      { riderId: targetRiderId },
      {
        $set: {
          ...(targetName && { name: targetName.trim() }),
          ...(email && { email: email.trim().toLowerCase() }),
          ...(profileImage && { profileImage }),
          ...(vehicleType && { vehicleType }),
          ...(vehicleNumber && { vehicleNumber: vehicleNumber.trim() }),
          ...(drivingLicenseNumber && { drivingLicenseNumber: drivingLicenseNumber.trim() }),
          ...(drivingLicenseDoc && { drivingLicenseDoc }),
        },
      },
      { new: true, runValidators: true }
    );

    if (!updatedRider) {
      return res.status(404).json({ error: 'Rider not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Rider profile updated successfully',
      rider: updatedRider,
    });
  } catch (error) {
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ error: 'Failed to update Rider profile', details: error.message });
  }
};

// 5. TOGGLE ONLINE / OFFLINE STATUS
exports.toggleOnline = async (req, res) => {
  try {
    const { riderId, isOnline } = req.body;

    if (!riderId || isOnline === undefined) {
      return res.status(400).json({ error: 'riderId and isOnline (boolean) are required' });
    }

    const rider = await Rider.findOneAndUpdate(
      { riderId },
      { $set: { isOnline: Boolean(isOnline) } },
      { new: true, runValidators: true }
    );

    if (!rider) {
      return res.status(404).json({ error: 'Rider not found' });
    }

    res.status(200).json({
      success: true,
      message: `Rider is now ${rider.isOnline ? 'ONLINE' : 'OFFLINE'}`,
      isOnline: rider.isOnline,
    });
  } catch (error) {
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ error: 'Failed to update status', details: error.message });
  }
};

// 6. UPDATE LIVE GPS LOCATION
exports.updateLocation = async (req, res) => {
  try {
    const { riderId, lat, lng } = req.body;

    if (!riderId || lat === undefined || lng === undefined) {
      return res.status(400).json({ error: 'riderId, lat, and lng are required' });
    }

    await Rider.findOneAndUpdate(
      { riderId },
      { 
        $set: { 
          'currentLocation.lat': Number(lat), 
          'currentLocation.lng': Number(lng) 
        } 
      },
      { runValidators: true }
    );

    res.status(200).json({ success: true, message: 'Location updated' });
  } catch (error) {
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ error: 'Failed to update location', details: error.message });
  }
};

// 7. UPDATE FCM TOKEN
exports.updateFcmToken = async (req, res) => {
  try {
    const targetId = req.body.riderId || req.body.userId;
    const { fcmToken, phone } = req.body;

    if (!targetId && !phone) {
      return res.status(400).json({ error: 'riderId or phone is required' });
    }
    if (!fcmToken) {
      return res.status(400).json({ error: 'fcmToken is required' });
    }

    const query = {};
    if (targetId && phone) query.$or = [{ riderId: targetId }, { phone }];
    else if (targetId) query.riderId = targetId;
    else query.phone = phone;

    await Rider.findOneAndUpdate(
      query,
      { $set: { fcmToken: fcmToken.trim() } },
      { runValidators: true }
    );

    res.status(200).json({ success: true, message: 'Rider FCM token updated' });
  } catch (error) {
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ error: 'Failed to update FCM token', details: error.message });
  }
};

// 8. RIDER LOGOUT
exports.logout = async (req, res) => {
  try {
    const targetId = req.body.riderId || req.body.userId;
    const { phone } = req.body;
    const query = {};
    if (targetId && phone) query.$or = [{ riderId: targetId }, { phone }];
    else if (targetId) query.riderId = targetId;
    else if (phone) query.phone = phone;

    await Rider.updateOne(query, { $set: { fcmToken: '', isOnline: false } });
    res.status(200).json({ success: true, message: 'Rider logged out successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to logout', details: error.message });
  }
};
