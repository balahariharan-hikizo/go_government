const mongoose = require('mongoose');

// 1. Variant Schema (for different sizes, weights, packs with individual price/stock)
const VariantSchema = new mongoose.Schema(
  {
    variantId: { type: String, required: true,unique:true },
    unit: { type: String, required: true, trim: true }, // e.g. '500 g', '1 kg', '5 kg', '250 ml'
    price: { type: Number, required: true },
    originalPrice: { type: Number, default: 0 },
    discountPercentage: { type: String, default: '' },
    stock: { type: Number, default: 10 },
    isAvailable: { type: Boolean, default: true },
    image: { type: String, default: '' }, // optional variant-specific image
  },
  { _id: false }
);

// 2. Product Schema
const ProductSchema = new mongoose.Schema(
  {
    productId: { type: String, required: true, unique: true },
    storeId: { type: String, required: true, index: true },
    title: { type: String, required: true, trim: true },
    category: { type: String, default: 'general', trim: true },
    
    // Default Base Unit & Price (used as base/fallback)
    unit: { type: String, default: '1 Units', trim: true },
    price: { type: Number, required: true },
    originalPrice: { type: Number, default: 0 },
    discountPercentage: { type: String, default: '' },
    stock: { type: Number, default: 10 },
    isAvailable: { type: Boolean, default: true },

    // Multiple Images Array & Primary Thumbnail
    image: { type: String, default: '' }, // Primary thumbnail
    images: { type: [String], default: [] }, // Array of multiple product images
    
    // Product Variants Support (Sizes / Weights)
    hasVariants: { type: Boolean, default: false },
    variants: [VariantSchema],

    description: { type: String, default: '', trim: true },
    
    // Detailed Citizen App Specifications & Highlights
    brand: { type: String, default: 'Unbranded', trim: true },
    packOf: { type: String, default: '1', trim: true },
    type: { type: String, default: '', trim: true },
    shelfLife: { type: String, default: '7 Days', trim: true },
    formFactor: { type: String, default: 'Whole', trim: true },
    origin: { type: String, default: 'India', trim: true },
    
    // Government Subsidy Fields (for Ration / PDS / Essential stores)
    isSubsidized: { type: Boolean, default: false },
    subsidyLimit: { type: String, default: '', trim: true },
  },
  {
    timestamps: true,
  }
);

// Pre-save hook to ensure images array and primary image are synchronized
ProductSchema.pre('save', function () {
  // If images array has elements but primary image is empty, set primary image
  if (this.images && this.images.length > 0 && !this.image) {
    this.image = this.images[0];
  }
  // If primary image exists but images array is empty, populate images array
  if (this.image && (!this.images || this.images.length === 0)) {
    this.images = [this.image];
  }
  // Auto-flag hasVariants if variants array is not empty
  if (this.variants && this.variants.length > 0) {
    this.hasVariants = true;
  }
});

ProductSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    delete ret._id;
  },
});

module.exports = mongoose.model('Product', ProductSchema);
