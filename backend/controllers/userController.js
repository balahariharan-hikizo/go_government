const User = require('../models/User');
const { getNextSequence } = require('../utils/sequenceGenerator');

// 1. SEND OTP (Citizen / General User)
exports.sendOtp = async (req, res) => {
  try {
    const { phone } = req.body;

    if (!phone) {
      return res.status(400).json({ error: 'Phone number is required' });
    }

    const cleanPhone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);

    // Auto-generate random 4-digit OTP (1000 to 9999)
    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const otpExpires = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes validity

    // Check if user already exists
    let user = await User.findOne({ phone: cleanPhone });
    if (!user) {
      const userId = await getNextSequence('userId', 'USER_', 5);
      try {
        user = await User.create({
          phone: cleanPhone,
          userId,
          role: 'citizen',
          otp,
          otpExpires,
        });
      } catch (err) {
        if (err.code === 11000) {
          user = await User.findOneAndUpdate(
            { phone: cleanPhone },
            { $set: { otp, otpExpires } },
            { returnDocument: 'after' }
          );
        } else {
          throw err;
        }
      }
    } else {
      user.otp = otp;
      user.otpExpires = otpExpires;
      await user.save();
    }

    console.log(`📱 [Citizen OTP] Sent to ${cleanPhone}: ${otp}`);

    res.status(200).json({
      success: true,
      message: `OTP sent successfully to ${cleanPhone}`,
      otp: otp, // Returned for testing
    });
  } catch (error) {
    console.error('Error sending OTP:', error);
    res.status(500).json({ error: 'Failed to send OTP', details: error.message });
  }
};

// 2. VERIFY OTP
exports.verifyOtp = async (req, res) => {
  try {
    const { phone, otp, } = req.body;

    if (!phone || !otp) {
      return res.status(400).json({ error: 'Phone and OTP are required' });
    }

    const cleanPhone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    const user = await User.findOne({ phone: cleanPhone });

    if (!user) {
      return res.status(404).json({ error: 'User not found. Please request OTP first.' });
    }

    // Check expiration
    if (user.otpExpires && new Date() > user.otpExpires) {
      return res.status(400).json({ error: 'OTP has expired. Please request a new one.' });
    }

    // Verify OTP code
    if (user.otp !== otp.toString().trim()) {
      return res.status(400).json({ error: 'Invalid OTP code. Please enter the correct OTP.' });
    }

    // Clear OTP after successful verification
    user.otp = '';
    await user.save();

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
    res.status(500).json({ error: 'Failed to verify OTP', details: error.message });
  }
};

// 3. GET PROFILE BY USER ID
exports.getProfile = async (req, res) => {
  try {
    const user = await User.findOne({ userId: req.params.userId });
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.status(200).json({
      success: true,
      user: user,
    });
  } catch (error) {
    console.error('Error fetching profile:', error);
    res.status(500).json({ error: 'Failed to fetch profile', details: error.message });
  }
};

// 4. UPDATE / SAVE PROFILE
exports.updateProfile = async (req, res) => {
  try {
    const { userId, userName, email, profileImage } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
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
      { new: true, runValidators: true }
    );

    if (!updatedUser) {
      return res.status(404).json({ error: 'User not found' });
    }

    res.status(200).json({
      success: true,
      message: 'Profile updated successfully 🎉',
      user: updatedUser,
    });
  } catch (error) {
    console.error('Error updating profile:', error);
    res.status(500).json({ error: 'Failed to update profile', details: error.message });
  }
};

// 5. SEND PHONE UPDATE OTP
exports.sendPhoneUpdateOtp = async (req, res) => {
  try {
    const { userId, newPhone, currentPhone } = req.body;

    if (!newPhone) {
      return res.status(400).json({ error: 'newPhone is required' });
    }

    const cleanNewPhone = newPhone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    const cleanCurrentPhone = currentPhone
      ? currentPhone.toString().trim().replace(/[^0-9]/g, '').slice(-10)
      : null;

    let user = null;
    if (userId) {
      user = await User.findOne({ userId });
      if (!user) {
        return res.status(404).json({ error: 'User account not found for this userId' });
      }
      if (cleanCurrentPhone && user.phone !== cleanCurrentPhone) {
        return res.status(400).json({ error: 'Current phone number does not match this user account' });
      }
    } else if (cleanCurrentPhone) {
      user = await User.findOne({ phone: cleanCurrentPhone });
      if (!user) {
        return res.status(404).json({ error: 'User account not found for this phone number' });
      }
    } else {
      return res.status(400).json({ error: 'userId or currentPhone is required to identify the user' });
    }

    const existing = await User.findOne({
      phone: cleanNewPhone,
      userId: { $ne: user.userId },
    });

    if (existing) {
      return res.status(400).json({
        error: 'This phone number is already registered with another account.',
      });
    }

    const otp = Math.floor(1000 + Math.random() * 9000).toString();
    const otpExpires = new Date(Date.now() + 5 * 60 * 1000);

    user.pendingPhone = cleanNewPhone;
    user.pendingPhoneOtp = otp;
    user.pendingPhoneOtpExpires = otpExpires;
    await user.save();

    console.log(`📲 [Citizen Phone Update OTP] for ${cleanNewPhone}: ${otp}`);

    res.status(200).json({
      success: true,
      message: `OTP sent successfully to ${cleanNewPhone}`,
      otp: otp,
    });
  } catch (error) {
    console.error('Error sending phone update OTP:', error);
    res.status(500).json({ error: 'Failed to send OTP', details: error.message });
  }
};

// 6. VERIFY PHONE UPDATE OTP & UPDATE PHONE
exports.verifyPhoneUpdateOtp = async (req, res) => {
  try {
    const { userId, newPhone, currentPhone, otp } = req.body;

    if (!newPhone || !otp) {
      return res.status(400).json({ error: 'newPhone and otp are required' });
    }

    const cleanNewPhone = newPhone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    const cleanCurrentPhone = currentPhone
      ? currentPhone.toString().trim().replace(/[^0-9]/g, '').slice(-10)
      : null;

    let user = null;
    if (userId) {
      user = await User.findOne({ userId });
      if (!user) {
        return res.status(404).json({ error: 'User account not found for this userId' });
      }
      if (cleanCurrentPhone && user.phone !== cleanCurrentPhone) {
        return res.status(400).json({ error: 'Current phone number does not match this user account' });
      }
    } else if (cleanCurrentPhone) {
      user = await User.findOne({ phone: cleanCurrentPhone });
      if (!user) {
        return res.status(404).json({ error: 'User account not found for this phone number' });
      }
    } else {
      return res.status(400).json({ error: 'userId or currentPhone is required to identify the user' });
    }

    if (user.pendingPhone !== cleanNewPhone) {
      return res.status(400).json({ error: 'Phone number mismatch. Please request OTP again.' });
    }

    if (user.pendingPhoneOtpExpires && new Date() > user.pendingPhoneOtpExpires) {
      return res.status(400).json({ error: 'OTP has expired. Please request a new one.' });
    }

    if (user.pendingPhoneOtp !== otp.toString().trim()) {
      return res.status(400).json({ error: 'Invalid OTP code. Please enter the correct OTP.' });
    }

    user.phone = cleanNewPhone;
    user.pendingPhone = '';
    user.pendingPhoneOtp = '';
    user.pendingPhoneOtpExpires = null;
    await user.save();

    console.log(`✅ Citizen phone updated: user ${user.userId} -> ${cleanNewPhone}`);

    res.status(200).json({
      success: true,
      message: 'Phone number updated successfully',
      phone: cleanNewPhone,
      user: user,
    });
  } catch (error) {
    console.error('Error verifying phone update OTP:', error);
    res.status(500).json({ error: 'Failed to update phone number', details: error.message });
  }
};

// 7. UPDATE FCM TOKEN
exports.updateFcmToken = async (req, res) => {
  try {
    const { userId, phone, fcmToken } = req.body;

    if (!fcmToken) {
      return res.status(400).json({ error: 'fcmToken is required' });
    }

    const query = {};
    if (userId) query.userId = userId;
    else if (phone) query.phone = phone.toString().trim().replace(/[^0-9]/g, '').slice(-10);
    else return res.status(400).json({ error: 'userId or phone is required' });

    const user = await User.findOneAndUpdate(
      query,
      { $set: { fcmToken: fcmToken.trim() } },
      { new: true, runValidators: true }
    );

    res.status(200).json({
      success: true,
      message: 'FCM token updated successfully',
      fcmToken,
    });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update FCM token', details: error.message });
  }
};

// 8. LOGOUT
exports.logout = async (req, res) => {
  try {
    const { userId, phone } = req.body;
    if (!userId && !phone) {
      return res.status(400).json({ error: 'userId or phone is required' });
    }

    const query = {};
    if (userId && phone) query.$or = [{ userId }, { phone }];
    else if (userId) query.userId = userId;
    else query.phone = phone;

    await User.updateOne(query, { $set: { fcmToken: '' } });

    res.status(200).json({ success: true, message: 'Logged out successfully' });
  } catch (error) {
    res.status(500).json({ error: 'Failed to logout', details: error.message });
  }
};
