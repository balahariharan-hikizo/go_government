const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orderController');

// 1. Order Creation & Monitoring
router.post('/create', orderController.createOrder);
router.get('/all', orderController.getAllOrders);
router.get('/riders/live-locations', orderController.getLiveRiderLocations);

// 2. Role-specific Order Queries
router.get('/user/:userId', orderController.getUserOrders);
router.get('/store/:storeId', orderController.getStoreOrders);
router.get('/available', orderController.getAvailableDeliveries);
router.get('/rider/:riderId', orderController.getRiderDeliveries);

// 3. Single Order Actions & State Transitions
router.get('/:orderId', orderController.getOrderDetails);
router.post('/:orderId/accept-rider', orderController.acceptOrder);
router.patch('/:orderId/status', orderController.updateOrderStatus);
router.delete('/:orderId', orderController.deleteOrder);

module.exports = router;
