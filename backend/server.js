require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const mongoose = require('mongoose');
const cors = require('cors');
const morgan = require('morgan');
const path = require('path');
const dns = require('dns');

// Ensure reliable DNS resolution for MongoDB Atlas SRV records
try {
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {
  console.warn('DNS server override failed:', e.message);
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//ROUTES

const complaintRoutes = require('./routes/complaintRoutes');
const uploadRoutes = require('./routes/uploadRoutes');
const authRoutes = require('./routes/authRoutes');
const addressRoutes = require('./routes/addressRoutes');
const storeRoutes = require('./routes/storeRoutes');
const feedbackRoutes = require('./routes/feedbackRoutes');
const productRoutes = require('./routes/productRoutes');
const categoryRoutes = require('./routes/categoryRoutes');
const cartRoutes = require('./routes/cartRoutes');
const wishlistRoutes = require('./routes/wishlistRoutes');
const orderRoutes = require('./routes/orderRoutes');
const walletRoutes = require('./routes/walletRoutes');
const riderRoutes = require('./routes/riderRoutes');
const notificationRoutes = require('./routes/notificationRoutes');
const { initSockets, riderRegistry, dispatchTimers } = require('./sockets/socketHandler');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE'],
  },
});

// Expose io instance to route handlers via req.app.get('io')
app.set('io', io);

// Initialize Socket.io connection handlers & Rider GPS Dispatch Engine
initSockets(io, app);

const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
app.use(morgan('dev'));

// Serve uploaded photos statically so Flutter can display them
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// Serve Production Admin Web Portal directly from backend
const adminWebPath = path.join(__dirname, '../admin_web/build/web');
app.use('/admin', express.static(adminWebPath));
app.get('/admin', (req, res) => {
  res.sendFile(path.join(adminWebPath, 'index.html'));
});
app.get('/admin/{*path}', (req, res) => {
  res.sendFile(path.join(adminWebPath, 'index.html'));
});

// Health Check Endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'online',
    message: 'GoGovernment Node.js Backend is running smoothly 🚀',
    timestamp: new Date().toISOString(),
  });
});

app.get('/', (req, res) => {
   res.status(200).json({
    sucess: 'true',
    message: 'Welcome to backend',
  });
});

// Debug Endpoint for Rider Registry & Dispatches
app.get('/debug/riders', (req, res) => {
  const riders = [];
  for (const [id, info] of riderRegistry.entries()) {
    riders.push({
      riderId: id,
      socketId: info.socketId,
      lat: info.lat,
      lng: info.lng,
      isOnline: info.isOnline,
      isBusy: info.isBusy,
      lastSeenSecondsAgo: Math.round((Date.now() - (info.lastSeen || 0)) / 1000),
      hasDisconnectTimer: !!info.disconnectTimer,
    });
  }
  res.json({
    totalRiders: riders.length,
    riders,
    activeDispatches: Array.from(dispatchTimers.keys()),
  });
});


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////


// API Routes (Clean direct mounts without /api)
app.use('/complaints', complaintRoutes);
app.use('/upload', uploadRoutes);
app.use('/auth', authRoutes);
app.use('/addresses', addressRoutes);
app.use('/stores', storeRoutes);
app.use('/feedback', feedbackRoutes);
app.use('/products', productRoutes);
app.use('/categories', categoryRoutes);
app.use('/cart', cartRoutes);
app.use('/wishlist', wishlistRoutes);
app.use('/orders', orderRoutes);
app.use('/wallet', walletRoutes);
app.use('/riders', riderRoutes);
app.use('/notifications', notificationRoutes);

// Connect to MongoDB & Start Server
const MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
  console.error('❌ MONGO_URI is missing in .env file!');
  process.exit(1);
}

const os = require('os');

mongoose
  .connect(MONGO_URI)
  .then(() => {
    console.log(' MongoDB Atlas Connected Successfully!');

    server.listen(PORT, '0.0.0.0', () => {
      console.log(` Server is running!`);
      console.log(` Laptop URL: http://localhost:${PORT}/health`);
      
      // Auto-detect local Wi-Fi IP
      const nets = os.networkInterfaces();
      for (const name of Object.keys(nets)) {
        for (const net of nets[name]) {
          if (net.family === 'IPv4' && !net.internal) {
            console.log(` Mobile URL (${name}): http://${net.address}:${PORT}/health`);
          }
        }
      }
    });
    
  })
  .catch((err) => {
    console.error('❌ MongoDB Connection Failed:', err.message);
  });
