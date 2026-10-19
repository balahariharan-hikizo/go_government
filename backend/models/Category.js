const mongoose = require('mongoose');

const CategorySchema = new mongoose.Schema(
  {
    categoryId: { type: String, required: true, unique: true, index: true },
    storeId: { type: String, required: true, index: true }, // Associated storeId or 'global'
    name: { type: String, required: true, trim: true },
    description: { type: String, default: '', trim: true },
    icon: { type: String, default: '' },
    image: { type: String, default: '' },
    displayOrder: { type: Number, default: 0 },
    isActive: { type: Boolean, default: true, index: true },
    isDeleted: { type: Boolean, default: false, index: true },
    deletedAt: { type: Date, default: null },
  },
  {
    timestamps: true,
  }
);

CategorySchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    delete ret._id;
  },
});

module.exports = mongoose.model('Category', CategorySchema);
