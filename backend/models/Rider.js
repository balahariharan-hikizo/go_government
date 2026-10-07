const mongoose = require('mongoose');

const RiderSchema = new mongoose.Schema(
  {
    riderId: { 
      type: String, 
      required: true, 
      unique: true,
      index: true,
    },
    name: { 
      type: String, 
      default: '', 
      trim: true 
    },
    phone: { 
      type: String, 
      required: true, 
      unique: true,
      index: true,
    },
    email: { 
      type: String, 
      default: '', 
      trim: true, 
      lowercase: true 
    },
    profileImage: { 
      type: String, 
      default: '' 
    },
    role:{
      type: String,
      default: 'rider', index: true
    },

    // Vehicle & License Information
    vehicleType: { 
      type: String, 
      enum: ['bike', 'scooter', 'ev', 'cycle', 'other'],
      default: 'bike' 
    },
    vehicleNumber: { 
      type: String, 
      default: '',
      trim: true 
    },
    drivingLicenseNumber: { 
      type: String, 
      default: '',
      trim: true 
    },
    drivingLicenseDoc: { 
      type: String, 
      default: '' 
    },

    // Operational & Live Status
    isOnline: { 
      type: Boolean, 
      default: false,
      index: true 
    },
    isBusy: {
      type: Boolean,
      default: false,
      index: true
    },
    currentLocation: {
      lat: { type: Number, default: 0.0 },
      lng: { type: Number, default: 0.0 },
    },
    
    // Financial & Earnings
    walletBalance: { 
      type: Number, 
      default: 0, 
      min: 0 
    },



    // Auth & Notifications
    otp: { 
      type: String, 
      default: '' 
    },
    otpExpires: { 
      type: Date 
    },
    fcmToken: { 
      type: String, 
      default: '' 
    },
  },
  {
    timestamps: true, // auto adds createdAt & updatedAt
  }
);

// Clean JSON response (Removes _id, __v, and sensitive otp)
RiderSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    delete ret._id;
    delete ret.otp;
    delete ret.otpExpires;
  },
});

module.exports = mongoose.model('Rider', RiderSchema);
