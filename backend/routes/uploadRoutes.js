const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const uploadController = require('../controllers/uploadController');

const router = express.Router();

const uploadDir = path.join(__dirname, '..', 'uploads');
const profileDir = path.join(uploadDir, 'profile_images');
const storeDir = path.join(uploadDir, 'store_images');
const productDir = path.join(uploadDir, 'product_images');

[uploadDir, profileDir, storeDir, productDir].forEach((dir) => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Storage configurations
const generalStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    const type = (req.query.type || req.body.type || '').toLowerCase();
    let prefix = 'complaint-';
    if (type === 'store' || type === 'storeimg') prefix = 'storeimg-';
    else if (type === 'product' || type === 'productimg') prefix = 'productimg-';
    cb(null, prefix + Date.now() + ext);
  },
});

const profileStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, profileDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, 'profile-' + Date.now() + ext);
  },
});

const storeStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, 'storeimg-' + Date.now() + ext);
  },
});

const productStorage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, uploadDir),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, 'productimg-' + Date.now() + ext);
  },
});

const uploadGeneral = multer({ storage: generalStorage });
const uploadProfile = multer({ storage: profileStorage });
const uploadStore = multer({ storage: storeStorage });
const uploadProduct = multer({ storage: productStorage });

// Explicit named upload routes
router.post('/complaint', uploadGeneral.single('image'), uploadController.uploadGeneral);

router.post('/store', uploadStore.single('image'), uploadController.uploadStore);
router.post('/product', uploadProduct.array('images', 10), uploadController.uploadProductMultiple);
router.post('/profile', uploadProfile.single('image'), uploadController.uploadProfile);

module.exports = router;
