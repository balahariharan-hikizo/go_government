const bcrypt = require('bcryptjs');
const Admin = require('../models/Admin');
const { getNextSequence } = require('./sequenceGenerator');

/**
 * Ensures at least one Master Municipal Admin exists on server boot.
 */
const seedMasterAdmin = async () => {
  try {
    const adminCount = await Admin.countDocuments();
    if (adminCount === 0) {
      const defaultUsername = (process.env.INITIAL_ADMIN_USERNAME).toLowerCase().trim();
      const defaultPassword = process.env.INITIAL_ADMIN_PASSWORD;
      const defaultName = process.env.INITIAL_ADMIN_NAME;

      const adminId = await getNextSequence('adminId', 'ADM_', 5);
      const hashedPassword = await bcrypt.hash(defaultPassword, 10);

      const masterAdmin = await Admin.create({
        adminId,
        username: defaultUsername,
        password: hashedPassword,
        name: defaultName,
        role: 'SUPER_ADMIN',
        createdBy: 'SYSTEM',
        isActive: true,
      });

      console.log(`🏛️ [Admin Seed] Default Master Admin created successfully: ${masterAdmin.adminId} (username: "${defaultUsername}") with role SUPER_ADMIN`);
    } else {
      // Ensure ADM_00001 has SUPER_ADMIN role
      await Admin.updateOne(
        { adminId: 'ADM_00001', role: { $ne: 'SUPER_ADMIN' } },
        { $set: { role: 'SUPER_ADMIN' } }
      );
      console.log(`🏛️ [Admin Seed] Admins exist in database (${adminCount} accounts). Super Admin role verified.`);
    }
  } catch (error) {
    console.error('❌ [Admin Seed] Failed to seed master admin:', error.message);
  }
};

module.exports = { seedMasterAdmin };

