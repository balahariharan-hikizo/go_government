const Complaint = require('../models/Complaint');
const { getNextSequence } = require('../utils/sequenceGenerator');
const { createNotification } = require('./notificationController');

const STATUS_COLORS = {
  'Under Review': 0xffff5252,
  'In Progress': 0xffff9100,
  'Resolved': 0xff4caf50,
  'Rejected': 0xff757575,
};

function formatComplaintDate(createdAt, fallbackDate) {
  if (!createdAt) return fallbackDate || 'Recently';
  const d = new Date(createdAt);
  if (isNaN(d.getTime())) return fallbackDate || 'Recently';

  const now = new Date();
  const isToday = d.toDateString() === now.toDateString();

  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  const isYesterday = d.toDateString() === yesterday.toDateString();

  const timeStr = d.toLocaleTimeString('en-IN', {
    hour: '2-digit',
    minute: '2-digit',
    hour12: true,
  });

  if (isToday) {
    return `Today, ${timeStr}`;
  }
  if (isYesterday) {
    return `Yesterday, ${timeStr}`;
  }
  const dateStr = d.toLocaleDateString('en-IN', {
    day: 'numeric',
    month: 'short',
  });
  return `${dateStr}, ${timeStr}`;
}

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

  // Dynamically calculate accurate date relative to actual creation time
  obj.date = formatComplaintDate(obj.createdAt, obj.date);

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
    res.status(500).json({ success: false, error: 'Failed to fetch complaint stats' });
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
    const formatted = complaints.map((c) => formatComplaint(c, req));
    res.status(200).json({
      success: true,
      count: formatted.length,
      complaints: formatted,
    });
  } catch (error) {
    console.error('Error fetching complaints:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch complaints' });
  }
};

// 2. GET SINGLE COMPLAINT
exports.getComplaintById = async (req, res) => {
  try {
    const complaint = await Complaint.findOne({ complaintId: req.params.complaintId });
    if (!complaint) {
      return res.status(404).json({ success: false, error: 'Complaint not found' });
    }
    res.status(200).json({
      success: true,
      complaint: formatComplaint(complaint, req),
    });
  } catch (error) {
    console.error('Error fetching complaint:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch complaint' });
  }
};

// 3. GET COMPLAINTS BY USER ID
exports.getUserComplaints = async (req, res) => {
  try {
    const userComplaints = await Complaint.find({ userId: req.params.userId }).sort({ createdAt: -1 });
    const formatted = userComplaints.map((c) => formatComplaint(c, req));
    res.status(200).json({
      success: true,
      count: formatted.length,
      complaints: formatted,
    });
  } catch (error) {
    console.error('Error fetching user complaints:', error);
    res.status(500).json({ success: false, error: 'Failed to fetch user complaints' });
  }
};

// 4. SUBMIT A NEW COMPLAINT
exports.createComplaint = async (req, res) => {
  try {
    const data = req.body;

    const isOfficialSequence = typeof data.complaintId === 'string' && /^CMP_\d{5}$/.test(data.complaintId);
    if (!isOfficialSequence) {
      data.complaintId = await getNextSequence('complaintId', 'CMP_', 5);
    }
    data.id = data.complaintId;

    if (!data.userId) {
      data.userId = 'USER_GUEST';
    }
    // Always save real absolute date format (e.g. "17 Oct, 04:45 PM") instead of static "Today"
    const now = new Date();
    data.date =
      now.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) +
      ', ' +
      now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });

    // Normalize coordinates if provided
    if (data.latitude != null && data.lat == null) data.lat = Number(data.latitude);
    if (data.longitude != null && data.lng == null) data.lng = Number(data.longitude);
    if (data.lat != null && !isNaN(Number(data.lat))) data.lat = Number(data.lat);
    if (data.lng != null && !isNaN(Number(data.lng))) data.lng = Number(data.lng);

    // Normalize status to valid enum or default to 'Under Review'
    const statusMap = {
      'under review': 'Under Review',
      'in progress': 'In Progress',
      'resolved': 'Resolved',
      'rejected': 'Rejected',
      'pending': 'Under Review',
    };
    if (data.status) {
      data.status = statusMap[data.status.toLowerCase()] || data.status;
    } else {
      data.status = 'Under Review';
    }
    data.statusColor = STATUS_COLORS[data.status] || 0xffff5252;

    const complaint = await Complaint.findOneAndUpdate(
      { complaintId: data.complaintId },
      { $set: data },
      { returnDocument: 'after', upsert: true, runValidators: true }
    );

    const formattedComplaint = formatComplaint(complaint, req);

    const ioCreate = req.app.get('io');
    if (ioCreate) {
      ioCreate.emit('complaint_created', formattedComplaint);
      ioCreate.emit('complaints_changed', { action: 'create', complaintId: data.complaintId });
    }

    // Save In-App Notification
    if (data.userId) {
      createNotification({
        userId: data.userId,
        title: 'Complaint Registered',
        message: `Your complaint #${complaint.complaintId} has been successfully registered under '${complaint.category}'.`,
        type: 'complaint',
        referenceId: complaint.complaintId,
        metadata: { category: complaint.category, status: complaint.status },
      }).catch((e) => console.warn('Notification error:', e.message));
    }

    res.status(201).json({ success: true, complaint: formattedComplaint });
  } catch (error) {
    console.error('Error submitting complaint:', error);
    res.status(500).json({ success: false, error: 'Failed to submit complaint', details: error.message });
  }
};

// 5. TOGGLE LIKE
exports.toggleLike = async (req, res) => {
  try {
    const { complaintId } = req.params;
    const userId = req.body.userId || req.body.citizenId;
    const { isCurrentlyLiked } = req.body;

    if (!userId) {
      return res.status(400).json({ success: false, error: 'userId or citizenId is required' });
    }

    const complaint = await Complaint.findOne({ complaintId });
    if (!complaint) {
      return res.status(404).json({ success: false, error: 'Complaint not found' });
    }

    // Auto-detect toggle or respect explicit boolean
    const alreadyLiked = complaint.likedBy.includes(userId);
    const shouldUnlike = typeof isCurrentlyLiked === 'boolean' ? isCurrentlyLiked : alreadyLiked;

    if (shouldUnlike) {
      complaint.likedBy = complaint.likedBy.filter((uid) => uid !== userId);
    } else {
      if (!complaint.likedBy.includes(userId)) {
        complaint.likedBy.push(userId);
      }
    }
    complaint.likesCount = complaint.likedBy.length;

    await complaint.save();

    const formattedComplaint = formatComplaint(complaint, req);

    const ioLike = req.app.get('io');
    if (ioLike) {
      ioLike.emit('complaint_liked', {
        complaintId: complaint.complaintId,
        likesCount: complaint.likesCount,
        likedBy: complaint.likedBy,
      });
      ioLike.emit('complaints_changed', { action: 'like', complaintId: complaint.complaintId });
    }

    res.status(200).json({
      success: true,
      message: shouldUnlike ? 'Unliked successfully' : 'Liked successfully 👍',
      isLiked: !shouldUnlike,
      complaintId: complaint.complaintId,
      likesCount: complaint.likesCount,
      likedBy: complaint.likedBy,
      complaint: formattedComplaint,
    });
  } catch (error) {
    console.error('Error toggling like:', error);
    res.status(500).json({ success: false, error: 'Failed to toggle like' });
  }
};

// 6. ADD COMMENT
exports.addComment = async (req, res) => {
  try {
    const { complaintId } = req.params;
    const userId = req.body.userId || req.body.citizenId;
    const { userName } = req.body;
    const commentText = req.body.comment || req.body.text;

    if (!commentText || !userId) {
      return res.status(400).json({ success: false, error: 'comment/text and userId/citizenId are required' });
    }

    const now = new Date();
    const formattedDate =
      now.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) +
      ', ' +
      now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });

    const newComment = {
      userName: userName || 'Citizen',
      comment: commentText,
      userId,
      date: formattedDate,
      timestamp: Date.now(),
    };

    const updated = await Complaint.findOneAndUpdate(
      { complaintId },
      { $push: { comments: newComment } },
      { returnDocument: 'after' }
    );

    if (!updated) {
      return res.status(404).json({ success: false, error: 'Complaint not found' });
    }

    const formatted = formatComplaint(updated, req);

    const ioComment = req.app.get('io');
    if (ioComment) {
      ioComment.emit('complaint_comment_added', {
        complaintId: updated.complaintId,
        comment: newComment,
        comments: updated.comments,
      });
      ioComment.emit('complaints_changed', { action: 'comment', complaintId: updated.complaintId });
    }

    res.status(200).json({
      success: true,
      message: 'Comment added successfully 💬',
      complaintId: updated.complaintId,
      comments: updated.comments,
      complaint: formatted,
    });
  } catch (error) {
    console.error('Error adding comment:', error);
    res.status(500).json({ success: false, error: 'Failed to add comment' });
  }
};

// 7. UPDATE COMPLAINT STATUS
exports.updateStatus = async (req, res) => {
  try {
    const { complaintId } = req.params;
    const { status, adminNotes, updatedBy } = req.body;

    if (!status) {
      return res.status(400).json({ success: false, error: 'Status is required' });
    }

    const statusMap = {
      'under review': 'Under Review',
      'in progress': 'In Progress',
      'resolved': 'Resolved',
      'rejected': 'Rejected',
    };
    const normalizedStatus = statusMap[status.toLowerCase()] || status;
    const color = STATUS_COLORS[normalizedStatus] || STATUS_COLORS[status] || 0xffff9100;

    const now = new Date();
    const formattedDate =
      now.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' }) +
      ', ' +
      now.toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit', hour12: true });

    const adminComment = {
      userName: updatedBy || 'Municipal Administration',
      comment: adminNotes
        ? `Status updated to '${normalizedStatus}': ${adminNotes}`
        : `Official complaint status updated to '${normalizedStatus}'`,
      userId: 'ADMIN',
      date: formattedDate,
      timestamp: Date.now(),
    };

    const updated = await Complaint.findOneAndUpdate(
      { complaintId },
      {
        $set: {
          status: normalizedStatus,
          statusColor: color,
        },
        $push: { comments: adminComment },
      },
      { returnDocument: 'after', runValidators: true }
    );

    if (!updated) {
      return res.status(404).json({ success: false, error: 'Complaint not found' });
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

    // Save In-App Notification for Complaint Owner
    if (updated.userId) {
      createNotification({
        userId: updated.userId,
        title: `Complaint ${normalizedStatus}`,
        message: adminNotes
          ? `Complaint #${complaintId}: ${adminNotes}`
          : `Your complaint #${complaintId} (${updated.category}) is now '${normalizedStatus}'.`,
        type: 'complaint',
        referenceId: complaintId,
        metadata: { category: updated.category, status: normalizedStatus },
      }).catch((e) => console.warn('Notification error:', e.message));
    }

    console.log(`📋 [Complaint Status Updated] ${complaintId} -> ${status}`);

    res.status(200).json({
      success: true,
      message: `Complaint status updated to '${status}' successfully!`,
      complaint: formattedComplaint,
    });
  } catch (error) {
    console.error('Error updating complaint status:', error);
    const status = error.name === 'ValidationError' ? 400 : 500;
    res.status(status).json({ success: false, error: error.message || 'Failed to update complaint status', details: error.message });
  }
};
