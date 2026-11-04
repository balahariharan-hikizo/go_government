const jwt = require('jsonwebtoken');
const Admin = require('../models/Admin');

const ADMIN_JWT_SECRET = process.env.ADMIN_JWT_SECRET;

if (!ADMIN_JWT_SECRET) {
  console.error('❌ CRITICAL: ADMIN_JWT_SECRET is missing in .env file!');
}

const adminAuthMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || req.headers.Authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        error: 'NO_TOKEN',
        message: 'Authentication required. No token provided.',
      });
    }

    const token = authHeader.split(' ')[1];

    let decoded;
    try {
      decoded = jwt.verify(token, ADMIN_JWT_SECRET);
    } catch (jwtErr) {
      if (jwtErr.name === 'TokenExpiredError') {
        return res.status(401).json({
          success: false,
          error: 'TOKEN_EXPIRED',
          message: 'Your admin session has expired. Please log in again.',
        });
      }
      return res.status(401).json({
        success: false,
        error: 'INVALID_TOKEN',
        message: 'Invalid or forged authentication token.',
      });
    }

    const admin = await Admin.findOne({ adminId: decoded.adminId, isActive: true });
    if (!admin) {
      return res.status(403).json({
        success: false,
        error: 'ACCOUNT_DEACTIVATED',
        message: 'Admin account is deactivated or not found.',
      });
    }

    req.admin = admin;
    next();
  } catch (error) {
    console.error('❌ [Admin Auth Middleware] Error:', error.message);
    return res.status(500).json({
      success: false,
      error: 'SERVER_ERROR',
      message: 'Failed to authenticate admin request.',
    });
  }
};

module.exports = { adminAuthMiddleware, ADMIN_JWT_SECRET };

