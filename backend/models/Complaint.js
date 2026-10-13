const mongoose = require('mongoose');

const CommentSchema = new mongoose.Schema({
  userName: { type: String, default: 'Citizen' },
  comment: { type: String, required: true },
  date: { type: String, default: 'Just now' },
  userId: { type: String, required: true },
  timestamp: { type: Number, default: () => Date.now() },
});

const ComplaintSchema = new mongoose.Schema(
  {
    complaintId: { type: String, required: true, unique: true },
    id: { type: String }, // satisfies old index if present
    userId: { type: String, required: true },
    userName: { type: String, default: 'Citizen' },
    userAddress: { type: String, default: 'Location not specified' },
    category: { type: String, required: true },
    description: { type: String, default: '' },
    status: {
      type: String,
      enum: {
        values: ['Under Review', 'In Progress', 'Resolved', 'Rejected'],
        message: '{VALUE} is not a valid complaint status',
      },
      default: 'Under Review',
    },
    statusColor: { type: Number, default: 0xffff5252 },
    imagePath: { type: String, default: null },
    lat: { type: Number, default: null },
    lng: { type: Number, default: null },
    date: { type: String, default: '' },
    likesCount: { type: Number, default: 0 },
    likedBy: [{ type: String }],
    comments: [CommentSchema],
  },
  
  {
    timestamps: true,
  }
);

ComplaintSchema.set('toJSON', {
  virtuals: true,
  versionKey: false,
  transform: function (doc, ret) {
    ret._mongoId = ret._id;
    delete ret._id;
  },
});

module.exports = mongoose.model('Complaint', ComplaintSchema);
