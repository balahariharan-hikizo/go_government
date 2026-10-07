const mongoose = require('mongoose');

const UserSchema = new mongoose.Schema(
  {
    userId: { type: String, required: true, unique: true },
    phone: { type: String, required: true, unique: true },
    userName: { type: String, default: '' },
    email: { type: String, default: '' },
    role: {
      type: String,
      default: 'citizen',
      index: true,
    },
    profileImage: { type: String, default: '' },
    walletBalance: { type: Number, default: 0, min: 0 },
    coinsBalance: { type: Number, default: 0, min: 0 },
    otp: { type: String, default: '' },
    otpExpires: { type: Date },
    pendingPhone: { type: String, default: '' },
    pendingPhoneOtp: { type: String, default: '' },
    pendingPhoneOtpExpires: { type: Date },
    fcmToken: { type: String, default: '' },
  },
  {
    timestamps: true,
  }
);

UserSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    delete ret._id;
    delete ret.otp; // Never expose OTP in response
    delete ret.otpExpires;
    delete ret.pendingPhoneOtp;
    delete ret.pendingPhoneOtpExpires;
  },
});

module.exports = mongoose.model('User', UserSchema);
