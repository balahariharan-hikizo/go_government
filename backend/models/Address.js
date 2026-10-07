const mongoose = require('mongoose');

const AddressSchema = new mongoose.Schema(
  {
    addressId: { type: String, required: true, unique: true },
    userId: { type: String, required: true, index: true },
    type: { type: String, default: 'Home' }, // 'Home', 'Work', 'Other'
    description: { type: String, default: '' },
    phone: { type: String, required: true },
    name: { type: String, default: '' },
    floor: { type: String, default: '' },
    landmark: { type: String, default: '' },
    imagePath: { type: String, default: null },
    isDefault: { type: Boolean, default: false },
    isDeleted: { type: Boolean, default: false },
    latitude: { type: Number, default: null },
    longitude: { type: Number, default: null },
  },
  
  {
    timestamps: true,
  }
);

AddressSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    ret.id = ret.addressId;
    ret._mongoId = ret._id;
    delete ret._id;
  },
});

module.exports = mongoose.model('Address', AddressSchema);
