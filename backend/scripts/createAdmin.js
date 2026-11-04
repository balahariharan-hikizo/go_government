require('dotenv').config({ path: require('path').join(__dirname, '../.env') });
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const Admin = require('../models/Admin');
const { getNextSequence } = require('../utils/sequenceGenerator');

async function run() {
  const args = process.argv.slice(2);
  if (args.length < 2) {
    console.log('Usage: node scripts/createAdmin.js <username> <password> [name] [role]');
    console.log('Example: node scripts/createAdmin.js officer1 secretPass123 "Zone 1 Officer" OFFICER');
    console.log('Example: node scripts/createAdmin.js super2 adminPass123 "Senior Officer" SUPER_ADMIN');
    process.exit(1);
  }

  const [username, password, name, role] = args;
  const mongoUri = process.env.MONGO_URI || process.env.MONGODB_URI;

  try {
    console.log(`Connecting to MongoDB...`);
    await mongoose.connect(mongoUri);

    const cleanUsername = username.trim().toLowerCase();
    const existing = await Admin.findOne({ username: cleanUsername });
    if (existing) {
      console.error(`❌ Error: Username "${cleanUsername}" already exists with ID ${existing.adminId}.`);
      process.exit(1);
    }

    const adminId = await getNextSequence('adminId', 'ADM_', 5);
    const hashedPassword = await bcrypt.hash(password, 10);
    const assignedRole = (role && role.toUpperCase() === 'SUPER_ADMIN') ? 'SUPER_ADMIN' : 'OFFICER';

    const admin = await Admin.create({
      adminId,
      username: cleanUsername,
      password: hashedPassword,
      name: name ? name.trim() : 'Municipal Officer',
      role: assignedRole,
      createdBy: 'CLI_SCRIPT',
      isActive: true,
    });

    console.log(`✅ Admin created successfully!`);
    console.log(`ID:       ${admin.adminId}`);
    console.log(`Username: ${admin.username}`);
    console.log(`Name:     ${admin.name}`);
    console.log(`Role:     ${admin.role}`);
  } catch (error) {
    console.error('❌ Failed to create admin:', error);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
}

run();

