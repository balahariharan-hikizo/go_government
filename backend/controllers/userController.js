const User = require('../models/User');
const { getNextSequence } = require('../utils/sequenceGenerator');
const { sanitizePhone, generateOtp } = require('../utils/commonHelper');

// 1. SEND OTP (Citizen / General User)
exports.sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ success: false, error: 'Phone number is required' });
    }

    const cleanPhone = sanitizePhone(phone);
    const { otp, otpExpires } = generateOtp(5);


    // Fast path: existing user (95%+ traffic) - Single atomic DB call
    let user = await User.findOneAndUpdate(
      { phone: cleanPhone },
      { $set: { otp, otpExpires } },
      { returnDocument: 'after' }
    );

    if (!user) {
      // New user registration flow
      const userId = await getNextSequence('userId', 'USER_', 5);
      user = await User.create({
        phone: cleanPhone,
        userId,
        role: 'citizen',
        otp,
        otpExpires,
      });
    }

    console.log(`📱 [Citizen OTP] Sent to ${cleanPhone}: ${otp}`);

    res.status(200).json({
      success: true,
      message: `OTP sent successfully to ${cleanPhone}`,
      otp: otp, // Returned for testing
    });
  } catch (error) {
    console.error('Error sending OTP:', error);
    res.status(500).json({ success: false, error: 'Failed to send OTP', details: error.message });
  }
};

// 2. VERIFY OTP
exports.verifyOtp = async (req, res) => {
  try {
    const { phone, otp } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ success: false, error: 'Phone and OTP are required' });
    }

    const cleanPhone = sanitizePhone(phone);
    const cleanOtp = otp.toString().trim();

    // 1. FAST PATH: Single atomic query to verify and clear OTP in 1 DB call
    const user = await User.findOneAndUpdate(
      {
        phone: cleanPhone,
        otp: cleanOtp,
        otpExpires: { $gte: new Date() },
      },
      { $set: { otp: '' } },
      { returnDocument: 'after' }
    );

    if (!user) {
      return res.status(400).json({ success: false, error: 'Invalid or expired OTP code. Please enter the correct OTP.' });
    }

    const hasProfile = Boolean(user.userName && user.userName.trim().length > 0);
    const isNewUser = !hasProfile;

    res.status(200).json({
      success: true,
      message: isNewUser ? 'New user! Please setup profile.' : 'Welcome back!',
      isNewUser: isNewUser,
      userId: user.userId,
      role: user.role || 'citizen',
      user: user,
    });
  } catch (error) {
    console.error('Error verifying OTP:', error);
    res.status(500).json({ success: false, error: 'Failed to verify OTP', details: error.message });
  }
};

// 3. GET PROFILE BY USER ID
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.params.userId });
    if (!user) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    res.status(200).json({
      success: true,
      user: user,
    });
  } catch (error) {
    console.error('Error fetching profile:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch profile', details: error.message });
  }
};

// 4. UPDATE / SAVE PROFILE
exports.updateProfile = async (req, res) => {
  try {
    const { userId, userName, email, profileImage } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, error: 'userId is required' });
    }

    const updatedUser = await User.findOneAndUpdate(
      { userId },
      {
        $set: {
          ...(userName && { userName: userName.trim() }),
          ...(email && { email: email.trim().toLowerCase() }),
          ...(profileImage && { profileImage }),
        },
      },
      { returnDocument: 'after', runValidators: true }
    );

    if (!updatedUser) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully 🎉',
      user: updatedUser,
    });
  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({ success: false, error: 'Failed to update profile', details: error.message });
  }
};

// 5. SEND PHONE UPDATE OTP
exports.sendPhoneUpdateOtp = async (req, res) => {
  try {
    const { userId, newPhone, currentPhone } = req.body;

    if (!newPhone) {
      return res.status(400).json({ success: false, error: 'newPhone is required' });
    }

    const cleanNewPhone = newPhone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    const cleanCurrentPhone = currentPhone
      ? currentPhone.toString().trim().replace(/[^0-9]/g, '').slice(-10)
      : null;

    const userQuery = userId
      ? { userId }
      : (cleanCurrentPhone ? { phone: cleanCurrentPhone } : null);

    if (!userQuery) {
      return res.status(400).json({ success: false, error: 'userId or currentPhone is required to identify the user' });
    }

    // Parallel DB lookups: fetch user and check if newPhone is already registered
    const [user, existing] = await Promise.all([
      User.findOne(userQuery),
      User.findOne({ phone: cleanNewPhone }),
    ]);

    if (!user) {
      return res.status(404).json({ success: false, error: 'User account not found' });
    }
    if (cleanCurrentPhone && user.phone !== cleanCurrentPhone) {
      return res.status(400).json({ success: false, error: 'Current phone number does not match this user account' });
    }

    if (existing && existing.userId !== user.userId) {
      return res.status(400).json({
        success: false,
        error: 'This phone number is already registered with another account.',
      });
    }

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const otpExpires = new Date(Date.now() + 5 * 60 * 1000);

    await User.updateOne(
      { userId: user.userId },
      {
        $set: {
          pendingPhone: cleanNewPhone,
          pendingPhoneOtp: otp,
          pendingPhoneOtpExpires: otpExpires,
        },
      }
    );

    console.log(`📲 [Citizen Phone Update OTP] for ${cleanNewPhone}: ${otp}`);

    res.status(200).json({
      success: true,
      message: `OTP sent successfully to ${cleanNewPhone}`,
      otp: otp,
    });
  } catch (error) {
    console.error('Error sending phone update OTP:', error);
    res.status(500).json({ success: false, error: 'Failed to send OTP', details: error.message });
  }
};

// 6. VERIFY PHONE UPDATE OTP & UPDATE PHONE
exports.verifyPhoneUpdateOtp = async (req, res) => {
  try {
    const { userId, newPhone, currentPhone, otp } = req.body;

    if (!newPhone || !otp) {
      return res.status(400).json({ success: false, error: 'newPhone and otp are required' });
    }

    const cleanNewPhone = newPhone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    const cleanCurrentPhone = currentPhone
      ? currentPhone.toString().trim().replace(/[^0-9]/g, '').slice(-10)
      : null;
    const cleanOtp = otp.toString().trim();

    const userQuery = userId
      ? { userId }
      : (cleanCurrentPhone ? { phone: cleanCurrentPhone } : null);

    if (!userQuery) {
      return res.status(400).json({ success: false, error: 'userId or currentPhone is required to identify the user' });
    }

    // 1. FAST PATH: Single atomic query to verify pending OTP and update phone
    const updatedUser = await User.findOneAndUpdate(
      {
        ...userQuery,
        pendingPhone: cleanNewPhone,
        pendingPhoneOtp: cleanOtp,
        pendingPhoneOtpExpires: { $gte: new Date() },
      },
      {
        $set: {
          phone: cleanNewPhone,
          pendingPhone: '',
          pendingPhoneOtp: '',
          pendingPhoneOtpExpires: null,
        },
      },
      { returnDocument: 'after' }
    );

    if (!updatedUser) {
      return res.status(400).json({ success: false, error: 'Invalid or expired OTP code. Please request OTP again.' });
    }

    console.log(`✅ Citizen phone updated: user ${updatedUser.userId} -> ${cleanNewPhone}`);
    res.status(200).json({
      success: true,
      message: 'Phone number updated successfully',
      phone: cleanNewPhone,
      user: updatedUser,
    });
  } catch (error) {
    console.error('Error verifying phone update OTP:', error);
    res.status(500).json({ success: false, error: 'Failed to update phone number', details: error.message });
  }
};

// 7. UPDATE FCM TOKEN
exports.updateFcmToken = async (req, res) => {
  try {
    const { userId, phone, fcmToken } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ success: false, error: 'fcmToken is required' });
    }

    const query = {};
    if (userId) query.userId = userId;
    else if (phone) query.phone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    else return res.status(400).json({ success: false, error: 'userId or phone is required' });

    const user = await User.findOneAndUpdate(
      query,
      { $set: { fcmToken: fcmToken.trim() } },
      { returnDocument: 'after', runValidators: true }
    );

    res.status(200).json({
      success: true,
      message: 'FCM token updated successfully',
      fcmToken,
    });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Failed to update FCM token', details: error.message });
  }
};

// 8. LOGOUT
exports.logout = async (req, res) => {
  try {
    const { userId, phone } = req.body;
    if (!userId && !phone) {
      return res.status(400).json({ success: false, error: 'userId or phone is required' });
    }

    const query = {};
    if (userId && phone) query.$or = [{ userId }, { phone }];
    else if (userId) query.userId = userId;
    else query.phone = phone;

    await User.updateOne(query, { $set: { fcmToken: '' } });

    res.status(200).json({ success: true, message: 'Logged out successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: 'Failed to logout', details: error.message });
  }
};
