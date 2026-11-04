const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Admin = require('../models/Admin');
const { getNextSequence } = require('../utils/sequenceGenerator');
const { ADMIN_JWT_SECRET } = require('../middleware/adminAuth');

// 1. ADMIN LOGIN
exports.login = async (req, res) => {
  try {
    const { username, password } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        error: 'MISSING_FIELDS',
        message: 'Username and password are required.',
      });
    }

    const cleanUsername = username.toString().trim().toLowerCase();
    const admin = await Admin.findOne({ username: cleanUsername });

    if (!admin || !admin.isActive) {
      return res.status(401).json({
        success: false,
        error: 'INVALID_CREDENTIALS',
        message: 'Invalid username or password.',
      });
    }

    const isMatch = await bcrypt.compare(password.toString(), admin.password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        error: 'INVALID_CREDENTIALS',
        message: 'Invalid username or password.',
      });
    }

    // Ensure ADM_00001 always has SUPER_ADMIN role
    const effectiveRole = admin.adminId === 'ADM_00001' ? 'SUPER_ADMIN' : (admin.role || 'OFFICER');
    if (admin.role !== effectiveRole) {
      admin.role = effectiveRole;
    }

    // Update last login
    admin.lastLogin = new Date();
    await admin.save();

    // Sign 12-hour JWT token
    const token = jwt.sign(
      {
        adminId: admin.adminId,
        username: admin.username,
        name: admin.name,
        role: effectiveRole,
      },
      ADMIN_JWT_SECRET,
      { expiresIn: '12h' }
    );

    console.log(`🔐 [Admin Auth] Admin logged in: ${admin.adminId} (${admin.username}) [${effectiveRole}]`);

    return res.status(200).json({
      success: true,
      message: 'Login successful. Welcome back!',
      token,
      admin: {
        adminId: admin.adminId,
        username: admin.username,
        name: admin.name,
        role: effectiveRole,
      },
    });
  } catch (error) {
    console.error('❌ [Admin Login] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'SERVER_ERROR',
      message: 'An error occurred during admin login.',
    });
  }
};

// 2. GET CURRENT ADMIN PROFILE
exports.getProfile = async (req, res) => {
  try {
    return res.status(200).json({
      success: true,
      admin: req.admin,
    });
  } catch (error) {
    console.error('❌ [Admin Profile] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'SERVER_ERROR',
      message: 'Failed to fetch admin profile.',
    });
  }
};

// 3. CREATE NEW ADMIN (Protected - Only SUPER_ADMIN can create)
exports.createAdmin = async (req, res) => {
  try {
    const callerRole = req.admin.adminId === 'ADM_00001' ? 'SUPER_ADMIN' : (req.admin.role || 'OFFICER');
    if (callerRole !== 'SUPER_ADMIN') {
      return res.status(403).json({
        success: false,
        error: 'FORBIDDEN',
        message: 'Access denied. Only Super Administrators can register new officers.',
      });
    }

    const { username, password, name, role } = req.body;

    if (!username || !password) {
      return res.status(400).json({
        success: false,
        error: 'MISSING_FIELDS',
        message: 'Username and password are required.',
      });
    }

    const cleanUsername = username.toString().trim().toLowerCase();
    if (cleanUsername.length < 3) {
      return res.status(400).json({
        success: false,
        error: 'USERNAME_TOO_SHORT',
        message: 'Username must be at least 3 characters long.',
      });
    }

    if (password.toString().length < 6) {
      return res.status(400).json({
        success: false,
        error: 'PASSWORD_TOO_SHORT',
        message: 'Password must be at least 6 characters long.',
      });
    }

    const existing = await Admin.findOne({ username: cleanUsername });
    if (existing) {
      return res.status(409).json({
        success: false,
        error: 'USERNAME_TAKEN',
        message: `Username "${cleanUsername}" is already taken. Please choose another.`,
      });
    }

    const adminId = await getNextSequence('adminId', 'ADM_', 5);
    const hashedPassword = await bcrypt.hash(password.toString(), 10);
    const assignedRole = role === 'SUPER_ADMIN' ? 'SUPER_ADMIN' : 'OFFICER';

    const newAdmin = await Admin.create({
      adminId,
      username: cleanUsername,
      password: hashedPassword,
      name: name && name.trim() ? name.trim() : 'Municipal Officer',
      role: assignedRole,
      createdBy: req.admin ? req.admin.adminId : 'SYSTEM',
      isActive: true,
    });

    console.log(`🏛️ [Admin Auth] New admin created: ${newAdmin.adminId} (${newAdmin.username}) [${assignedRole}] by ${req.admin ? req.admin.adminId : 'SYSTEM'}`);

    return res.status(201).json({
      success: true,
      message: `Admin account ${newAdmin.adminId} created successfully.`,
      admin: {
        adminId: newAdmin.adminId,
        username: newAdmin.username,
        name: newAdmin.name,
        role: newAdmin.role,
        createdBy: newAdmin.createdBy,
        createdAt: newAdmin.createdAt,
      },
    });
  } catch (error) {
    console.error('❌ [Create Admin] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'SERVER_ERROR',
      message: 'Failed to create new admin account.',
    });
  }
};

// 4. LIST ALL ADMINS (Protected)
exports.listAdmins = async (req, res) => {
  try {
    const admins = await Admin.find().sort({ createdAt: -1 });
    return res.status(200).json({
      success: true,
      count: admins.length,
      admins,
    });
  } catch (error) {
    console.error('❌ [List Admins] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'SERVER_ERROR',
      message: 'Failed to list admin accounts.',
    });
  }
};

// 5. SUPER ADMIN RESETS AN OFFICER'S PASSWORD (Protected - SUPER_ADMIN only)
exports.resetOfficerPassword = async (req, res) => {
  try {
    const callerRole = req.admin.adminId === 'ADM_00001' ? 'SUPER_ADMIN' : (req.admin.role || 'OFFICER');
    if (callerRole !== 'SUPER_ADMIN') {
      return res.status(403).json({
        success: false,
        error: 'FORBIDDEN',
        message: 'Access denied. Only Super Administrators can reset officers passwords.',
      });
    }

    const { targetAdminId, newPassword } = req.body;

    if (!targetAdminId || !newPassword) {
      return res.status(400).json({
        success: false,
        error: 'MISSING_FIELDS',
        message: 'Target Admin ID and new password are required.',
      });
    }

    if (targetAdminId === 'ADM_00001') {
      return res.status(400).json({
        success: false,
        error: 'CANNOT_RESET_MASTER',
        message: 'Master Chief Administrator password cannot be reset via officer directory.',
      });
    }

    if (newPassword.toString().length < 6) {
      return res.status(400).json({
        success: false,
        error: 'PASSWORD_TOO_SHORT',
        message: 'New password must be at least 6 characters long.',
      });
    }

    const targetAdmin = await Admin.findOne({ adminId: targetAdminId });
    if (!targetAdmin) {
      return res.status(404).json({
        success: false,
        error: 'ADMIN_NOT_FOUND',
        message: `Officer with ID ${targetAdminId} was not found.`,
      });
    }

    // Only ADM_00001 can reset another SUPER_ADMIN's password
    if (targetAdmin.role === 'SUPER_ADMIN' && req.admin.adminId !== 'ADM_00001') {
      return res.status(403).json({
        success: false,
        error: 'FORBIDDEN',
        message: 'Only the Chief Municipal Administrator (ADM_00001) can reset another Super Administrator password.',
      });
    }

    const hashedPassword = await bcrypt.hash(newPassword.toString(), 10);
    targetAdmin.password = hashedPassword;
    await targetAdmin.save();

    console.log(`🔐 [Admin Auth] Password for officer ${targetAdmin.adminId} (${targetAdmin.username}) was reset by ${req.admin.adminId}`);

    return res.status(200).json({
      success: true,
      message: `Password for ${targetAdmin.name} (${targetAdmin.adminId}) has been reset successfully.`,
    });
  } catch (error) {
    console.error('❌ [Reset Officer Password] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'SERVER_ERROR',
      message: 'Failed to reset officer password.',
    });
  }
};

// 6. ANY OFFICER CHANGES THEIR OWN PASSWORD (Protected - Requires current password)
exports.changeMyPassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        error: 'MISSING_FIELDS',
        message: 'Current password and new password are required.',
      });
    }

    if (newPassword.toString().length < 6) {
      return res.status(400).json({
        success: false,
        error: 'PASSWORD_TOO_SHORT',
        message: 'New password must be at least 6 characters long.',
      });
    }

    const admin = await Admin.findOne({ adminId: req.admin.adminId });
    if (!admin) {
      return res.status(404).json({
        success: false,
        error: 'ADMIN_NOT_FOUND',
        message: 'Admin account not found.',
      });
    }

    const isMatch = await bcrypt.compare(currentPassword.toString(), admin.password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        error: 'INCORRECT_PASSWORD',
        message: 'Your current password is incorrect. Please verify and try again.',
      });
    }

    const hashedPassword = await bcrypt.hash(newPassword.toString(), 10);
    admin.password = hashedPassword;
    await admin.save();

    console.log(`🔐 [Admin Auth] Officer ${admin.adminId} (${admin.username}) successfully changed their own password.`);

    return res.status(200).json({
      success: true,
      message: 'Your password has been changed successfully.',
    });
  } catch (error) {
    console.error('❌ [Change My Password] Error:', error);
    return res.status(500).json({
      success: false,
      error: 'SERVER_ERROR',
      message: 'Failed to change password.',
    });
  }
};

