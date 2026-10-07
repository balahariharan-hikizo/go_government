// 1. Upload General / Complaint Photo
exports.uploadGeneral = (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No image uploaded' });
  const host = req.get('host');
  const imageUrl = `${req.protocol}://${host}/uploads/${req.file.filename}`;
  console.log(`📸 [Image Uploaded] Filename: ${req.file.filename} -> ${imageUrl}`);
  res.status(200).json({ success: true, imageUrl, filename: req.file.filename });
};

// 2. Upload Store Image
exports.uploadStore = (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No store image uploaded' });
  const host = req.get('host');
  const imageUrl = `${req.protocol}://${host}/uploads/${req.file.filename}`;
  console.log(`🏪 [Store Image Uploaded] Filename: ${req.file.filename} -> ${imageUrl}`);
  res.status(200).json({ success: true, imageUrl, filename: req.file.filename });
};

// 4. Upload Profile Photo
exports.uploadProfile = (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'No profile image uploaded' });
  const host = req.get('host');
  const imageUrl = `${req.protocol}://${host}/uploads/profile_images/${req.file.filename}`;
  res.status(200).json({ success: true, imageUrl, filename: req.file.filename });
};

// 5. Upload Multiple Product Images
exports.uploadProductMultiple = (req, res) => {
  if (!req.files || req.files.length === 0) {
    return res.status(400).json({ error: 'No product images uploaded' });
  }
  const host = req.get('host');
  const imageUrls = req.files.map((file) => `${req.protocol}://${host}/uploads/${file.filename}`);
  console.log(`📦 [Multiple Product Images Uploaded] Count: ${imageUrls.length}`);
  res.status(200).json({ success: true, imageUrls, count: imageUrls.length });
};
