const mongoose = require('mongoose');
const Address = require('../models/Address');
const { getNextSequence } = require('../utils/sequenceGenerator');

// 1. GET ALL ADDRESSES FOR A USER (Excludes soft-deleted addresses)
exports.getAddresses = async (req, res) => {
  try {
    const { userId } = req.params;
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }

    const addresses = await Address.find({
      userId,
      isDeleted: { $ne: true },
    }).sort({ isDefault: -1, createdAt: -1 });

    res.status(200).json({
      success: true,
      count: addresses.length,
      data: addresses,
    });
  } catch (error) {
    console.error('Error fetching addresses:', error);
    res.status(500).json({ error: 'Failed to fetch addresses', details: error.message });
  }
};

// 2. ADD A NEW ADDRESS
exports.createAddress = async (req, res) => {
  try {
    const {
      userId,
      type = 'Home',
      description,
      phone,
      name = '',
      floor = '',
      landmark = '',
      imagePath = null,
      isDefault = false,
      latitude = null,
      longitude = null,
    } = req.body;

    if (!userId || !phone) {
      return res.status(400).json({
        error: 'userId and phone are required fields.',
      });
    }

    const addressId = await getNextSequence('addressId', 'ADDR_', 5);

    if (isDefault) {
      await Address.updateMany({ userId, isDeleted: { $ne: true } }, { $set: { isDefault: false } });
    }

    const activeCount = await Address.countDocuments({ userId, isDeleted: { $ne: true } });
    const shouldBeDefault = isDefault || activeCount === 0;

    const newAddress = new Address({
      addressId,
      userId,
      type,
      description,
      phone,
      name,
      floor,
      landmark,
      imagePath,
      isDefault: shouldBeDefault,
      isDeleted: false,
      latitude: latitude !== null && latitude !== undefined ? Number(latitude) : null,
      longitude: longitude !== null && longitude !== undefined ? Number(longitude) : null,
    });

    const savedAddress = await newAddress.save();

    res.status(201).json({
      success: true,
      message: 'Address added successfully',
      data: savedAddress,
    });
  } catch (error) {
    console.error('Error adding address:', error);
    res.status(500).json({ error: 'Failed to add address', details: error.message });
  }
};

// 3. EDIT AN ADDRESS
exports.updateAddress = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = { ...req.body };

    const isObjectId = mongoose.Types.ObjectId.isValid(id);
    const query = isObjectId
      ? { $and: [{ $or: [{ addressId: id }, { _id: id }] }, { isDeleted: { $ne: true } }] }
      : { addressId: id, isDeleted: { $ne: true } };

    const existing = await Address.findOne(query);

    if (!existing) {
      return res.status(404).json({ error: 'Address not found' });
    }

    if (updateData.isDefault === true) {
      await Address.updateMany(
        { userId: existing.userId, addressId: { $ne: existing.addressId }, isDeleted: { $ne: true } },
        { $set: { isDefault: false } }
      );
    }

    const allowedFields = ['type', 'description', 'phone', 'name', 'floor', 'landmark', 'imagePath', 'isDefault', 'latitude', 'longitude'];
    allowedFields.forEach((field) => {
      if (updateData[field] !== undefined) {
        existing[field] = updateData[field];
      }
    });

    const updatedAddress = await existing.save();

    res.status(200).json({
      success: true,
      message: 'Address updated successfully',
      data: updatedAddress,
    });
  } catch (error) {
    console.error('Error updating address:', error);
    res.status(500).json({ error: 'Failed to update address', details: error.message });
  }
};

// 4. SOFT DELETE AN ADDRESS
exports.deleteAddress = async (req, res) => {
  try {
    const { id } = req.params;

    const isObjectId = mongoose.Types.ObjectId.isValid(id);
    const query = isObjectId
      ? { $and: [{ $or: [{ addressId: id }, { _id: id }] }, { isDeleted: { $ne: true } }] }
      : { addressId: id, isDeleted: { $ne: true } };

    const existing = await Address.findOne(query);

    if (!existing) {
      return res.status(404).json({ error: 'Address not found or already removed' });
    }

    const wasDefault = existing.isDefault;

    existing.isDeleted = true;
    existing.isDefault = false;
    await existing.save();

    if (wasDefault) {
      const nextAddr = await Address.findOne({
        userId: existing.userId,
        isDeleted: { $ne: true },
      }).sort({ createdAt: -1 });

      if (nextAddr) {
        nextAddr.isDefault = true;
        await nextAddr.save();
      }
    }

    console.log(`🗑️ [Soft Delete] Address ${existing.addressId} marked isDeleted=true`);

    res.status(200).json({
      success: true,
      message: 'Address removed from your address book successfully',
      deletedId: id,
    });
  } catch (error) {
    console.error('Error deleting address:', error);
    res.status(500).json({ error: 'Failed to delete address', details: error.message });
  }
};
