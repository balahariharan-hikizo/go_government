const Complaint = require('../models/Complaint');
const { getNextSequence } = require('../utils/sequenceGenerator');

const STATUS_COLORS = {
  'Under Review': 0xffff5252,
  'In Progress': 0xffff9100,
  'Resolved': 0xff4caf50,
  'Rejected': 0xff757575,
};

function formatComplaint(doc, req) {
  if (!doc) return null;
  const obj = doc.toObject ? doc.toObject() : { ...doc };
  if (obj.imagePath && typeof obj.imagePath === 'string') {
    const trimmed = obj.imagePath.trim();
    if (trimmed.includes('/uploads/')) {
      const uploadPart = trimmed.substring(trimmed.indexOf('/uploads/'));
      const host = req.get('host') || 'localhost:5000';
      const protocol = req.protocol || 'http';
      obj.imagePath = `${protocol}://${host}${uploadPart}`;
    }
  }
  return obj;
}

// 0. GET COMPLAINT STATS (Admin Web)
exports.getStats = async (req, res) => {
  try {
    const total = await Complaint.countDocuments();
    const underReview = await Complaint.countDocuments({ status: { $regex: /^under review$/i } });
    const inProgress = await Complaint.countDocuments({ status: { $regex: /^in progress$/i } });
    const resolved = await Complaint.countDocuments({ status: { $regex: /^resolved$/i } });
    const rejected = await Complaint.countDocuments({ status: { $regex: /^rejected$/i } });

    res.status(200).json({
      success: true,
      stats: {
        total,
        underReview,
        inProgress,
        resolved,
        rejected,
      },
    });
  } catch (error) {
    console.error('Error fetching complaint stats:', error);
    res.status(500).json({ error: 'Failed to fetch complaint stats' });
  }
};

// 1. GET ALL COMPLAINTS
exports.getAllComplaints = async (req, res) => {
  try {
    const { status } = req.query;
    const filter = {};
    if (status && status !== 'all') {
      filter.status = new RegExp('^' + status.replace(/_/g, ' ') + '$', 'i');
    }
    const complaints = await Complaint.find(filter).sort({ createdAt: -1 });
    res.status(200).json(complaints.map((c) => formatComplaint(c, req)));
  } catch (error) {
    console.error('Error fetching complaints:', error);
    res.status(500).json({ error: 'Failed to fetch complaints' });
  }
};

// 2. GET SINGLE COMPLAINT
exports.getComplaintById = async (req, res) => {
  try {
    const complaint = await Complaint.findOne({ complaintId: req.params.complaintId });
    if (!complaint) {
      return res.status(404).json({ error: 'Complaint not found' });
    }
    res.status(200).json(formatComplaint(complaint, req));
  } catch (error) {
    console.error('Error fetching complaint:', error);
    res.status(500).json({ error: 'Failed to fetch complaint' });
  }
};

// 3. GET COMPLAINTS BY USER ID
exports.getUserComplaints = async (req, res) => {
  try {
    const userComplaints = await Complaint.find({ userId: req.params.userId }).sort({ createdAt: -1 });
    res.status(200).json(userComplaints.map((c) => formatComplaint(c, req)));
  } catch (error) {
    console.error('Error fetching user complaints:', error);
    res.status(500).json({ error: 'Failed to fetch user complaints' });
  }
};

// 4. SUBMIT A NEW COMPLAINT
exports.createComplaint = async (req, res) => {
  try {
    const data = req.body;

    if (!data.complaintId) {
      data.complaintId = await getNextSequence('complaintId', 'CMP_', 5);
    }
    data.id = data.complaintId;

    if (!data.userId) {
      data.userId = 'USER_GUEST';
    }
    if (!data.date) {
      const now = new Date();
      data.date =
        now.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) +
        ', ' +
        now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });
    }

    const complaint = await Complaint.findOneAndUpdate(
      { complaintId: data.complaintId },
      { $set: data },
      { new: true, upsert: true }
    );

    const formattedComplaint = formatComplaint(complaint, req);

    const ioCreate = req.app.get('io');
    if (ioCreate) {
      ioCreate.emit('complaint_created', formattedComplaint);
      ioCreate.emit('complaints_changed', { action: 'create', complaintId: data.complaintId });
    }

    res.status(201).json({ success: true, complaint: formattedComplaint });
  } catch (error) {
    console.error('Error submitting complaint:', error);
    res.status(500).json({ error: 'Failed to submit complaint', details: error.message });
  }
};

// 5. TOGGLE LIKE
exports.toggleLike = async (req, res) => {
  try {
    const { complaintId } = req.params;
    const userId = req.body.userId || req.body.citizenId;
    const { isCurrentlyLiked } = req.body;

    if (!userId) {
      return res.status(400).json({ error: 'userId or citizenId is required' });
    }

    const complaint = await Complaint.findOne({ complaintId });
    if (!complaint) {
      return res.status(404).json({ error: 'Complaint not found' });
    }

    if (!isCurrentlyLiked) {
      if (!complaint.likedBy.includes(userId)) {
        complaint.likedBy.push(userId);
        complaint.likesCount = complaint.likedBy.length;
      }
    } else {
      complaint.likedBy = complaint.likedBy.filter((uid) => uid !== userId);
      complaint.likesCount = complaint.likedBy.length;
    }

    await complaint.save();

    const ioLike = req.app.get('io');
    if (ioLike) {
      ioLike.emit('complaint_liked', {
        complaintId: complaint.complaintId,
        likesCount: complaint.likesCount,
        likedBy: complaint.likedBy,
      });
    }

    res.status(200).json({
      success: true,
      message: isCurrentlyLiked ? 'Unliked successfully' : 'Liked successfully 👍',
      complaintId: complaint.complaintId,
      likesCount: complaint.likesCount,
      likedBy: complaint.likedBy,
      complaint: complaint,
    });
  } catch (error) {
    console.error('Error toggling like:', error);
    res.status(500).json({ error: 'Failed to toggle like' });
  }
};

// 6. ADD COMMENT
exports.addComment = async (req, res) => {
  try {
    const { complaintId } = req.params;
    const userId = req.body.userId || req.body.citizenId;
    const { userName, comment } = req.body;

    if (!comment || !userId) {
      return res.status(400).json({ error: 'comment and userId/citizenId are required' });
    }

    const now = new Date();
    const formattedDate =
      now.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) +
      ', ' +
      now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });

    const newComment = {
      userName: userName || 'Citizen',
      comment,
      userId,
      date: formattedDate,
      timestamp: Date.now(),
    };

    const updated = await Complaint.findOneAndUpdate(
      { complaintId },
      { $push: { comments: newComment } },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ error: 'Complaint not found' });
    }

    const ioComment = req.app.get('io');
    if (ioComment) {
      ioComment.emit('complaint_comment_added', {
        complaintId: updated.complaintId,
        comment: newComment,
        comments: updated.comments,
      });
    }

    res.status(200).json({
      success: true,
      message: 'Comment added successfully 💬',
      complaintId: updated.complaintId,
      comments: updated.comments,
      complaint: updated,
    });
  } catch (error) {
    console.error('Error adding comment:', error);
    res.status(500).json({ error: 'Failed to add comment' });
  }
};

// 7. UPDATE COMPLAINT STATUS
exports.updateStatus = async (req, res) => {
  try {
    const { complaintId } = req.params;
    const { status, adminNotes, updatedBy } = req.body;

    if (!status) {
      return res.status(400).json({ error: 'Status is required' });
    }

    const color = STATUS_COLORS[status] || 0xffff9100;

    const now = new Date();
    const formattedDate =
      now.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) +
      ', ' +
      now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });

    const adminComment = {
      userName: updatedBy || 'Municipal Administration',
      comment: adminNotes
        ? `Status updated to '${status}': ${adminNotes}`
        : `Official complaint status updated to '${status}'`,
      userId: 'ADMIN',
      date: formattedDate,
      timestamp: Date.now(),
    };

    const updated = await Complaint.findOneAndUpdate(
      { complaintId },
      {
        $set: {
          status,
          statusColor: color,
        },
        $push: { comments: adminComment },
      },
      { new: true }
    );

    if (!updated) {
      return res.status(404).json({ error: 'Complaint not found' });
    }

    const formattedComplaint = formatComplaint(updated, req);

    const ioStatus = req.app.get('io');
    if (ioStatus) {
      ioStatus.emit('complaint_status_changed', {
        complaintId,
        status,
        statusColor: color,
        complaint: formattedComplaint,
        comment: adminComment,
      });
      ioStatus.emit('complaints_changed', { action: 'status_changed', complaintId, status });
    }

    console.log(`📋 [Complaint Status Updated] ${complaintId} -> ${status}`);

    res.status(200).json({
      success: true,
      message: `Complaint status updated to '${status}' successfully!`,
      complaint: formattedComplaint,
    });
  } catch (error) {
    console.error('Error updating complaint status:', error);
    res.status(500).json({ error: 'Failed to update complaint status', details: error.message });
  }
};
