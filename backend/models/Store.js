const mongoose = require('mongoose');

const StoreSchema = new mongoose.Schema(
  {
    storeId: { type: String, required: true, unique: true },
    name: { type: String, required: true, trim: true },
    ownerName: { type: String, required: true, trim: true },
    phone: { type: String, required: true, unique: true, index: true },
    email: { type: String, default: '', trim: true },
    category: {
      type: String,
      required: true,
      enum: ['ration', 'medical', 'vegstore', 'supermarket', 'general', 'dairy'],
      default: 'general',
    },
    licenseNumber: { type: String, default: '', trim: true },
    address: { type: String, required: true, trim: true },
    pincode: { type: String, default: '' },
    location: {
      lat: { type: Number, required: true },
      lng: { type: Number, required: true },
    },
    storeImage: { type: String, default: '' },
    licenseDoc: { type: String, default: '' },
    bankDetails: {
      bankName: { type: String, default: '' },
      accountNumber: { type: String, default: '' },
      ifscCode: { type: String, default: '' },
      accountHolderName: { type: String, default: '' },
    },
    role:{type: String, default: 'store_owner', index: true,},
    status: {
      type: String,
      enum: ['pending', 'approved', 'rejected'],
      default: 'pending',
      index: true,
    },
    rejectionReason: { type: String, default: '' },
    timings: {
      open: { type: String, default: '08:00 AM' },
      close: { type: String, default: '09:00 PM' },
    },
    isOnline: { type: Boolean, default: true },
    rating: { type: Number, default: 4.5 },
    walletBalance: { type: Number, default: 0, min: 0 },
    verifiedAt: { type: Date },
    verifiedBy: { type: String, default: '' },
    fcmToken: { type: String, default: '' },

    // Auth OTP Fields for Store Owner Login
    otp: { type: String, default: '' },
    otpExpires: { type: Date },
  },
  {
    timestamps: true,
  }
);

StoreSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    delete ret._id;
    delete ret.otp;
    delete ret.otpExpires;
  },
});

module.exports = mongoose.model('Store', StoreSchema);
