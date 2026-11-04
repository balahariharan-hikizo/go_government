const mongoose = require('mongoose');

const AdminSchema = new mongoose.Schema(
  {
    adminId: {
      type: String,
      required: true,
      unique: true,
      index: true,
    },
    username: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      index: true,
    },
    password: {
      type: String,
      required: true,
    },
    name: {
      type: String,
      default: 'Municipal Administrator',
      trim: true,
    },
    role: {
      type: String,
      enum: ['SUPER_ADMIN', 'OFFICER'],
      default: 'OFFICER',
    },
    createdBy: {
      type: String,
      default: 'SYSTEM',
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    lastLogin: {
      type: Date,
    },
  },
  {
    timestamps: true,
  }
);

AdminSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    delete ret._id;
    delete ret.password; // Never expose password hash in response
  },
});

module.exports = mongoose.model('Admin', AdminSchema);

