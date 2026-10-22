import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../network/api_client.dart';
import '../hive/hive_service.dart';

class RiderSocketService {
  static final RiderSocketService _instance = RiderSocketService._internal();
  factory RiderSocketService() => _instance;
  RiderSocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;

  final StreamController<Map<String, dynamic>> _orderAvailableController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _orderStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _orderAssignedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _orderDispatchController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _orderDispatchCancelledController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onOrderAvailable =>
      _orderAvailableController.stream;
  Stream<Map<String, dynamic>> get onOrderStatusUpdate =>
      _orderStatusController.stream;
  Stream<Map<String, dynamic>> get onOrderAssigned =>
      _orderAssignedController.stream;
  Stream<Map<String, dynamic>> get onOrderDispatch =>
      _orderDispatchController.stream;
  Stream<Map<String, dynamic>> get onOrderDispatchCancelled =>
      _orderDispatchCancelledController.stream;
  Stream<Map<String, dynamic>> get onChatMessage =>
      _chatMessageController.stream;

  String? _currentChatOrderId;

  void subscribeToChat(String orderId) {
    if (orderId.isEmpty) return;
    _currentChatOrderId = orderId;
    _socket?.off('chat:$orderId');
    _socket?.on('chat:$orderId', (data) {
      debugPrint('⚡ [RiderSocketService] Chat message received for order $orderId: $data');
      if (data is Map) {
        _chatMessageController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  void unsubscribeFromChat(String orderId) {
    // Left empty or no-op so active_delivery_screen doesn't lose live chat events
  }

  void init() {
    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      return;
    }

    final origin = ApiClient.baseUrl.replaceAll('/api', '');
    debugPrint('⚡ [RiderSocketService] Connecting to WebSocket: $origin');

    try {
      _socket = io.io(
        origin,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(1500)
            .setReconnectionAttempts(99)
            .build(),
      );

      _socket?.onConnect((_) {
        _isConnected = true;
        debugPrint('⚡ [RiderSocketService] Connected successfully (ID: ${_socket?.id})');
        final riderId = HiveService.userId.isNotEmpty
            ? HiveService.userId
            : (HiveService.userPhone.isNotEmpty ? HiveService.userPhone : 'rider');
        _socket?.emit('join:rider', riderId);
        if (_currentChatOrderId != null) {
          subscribeToChat(_currentChatOrderId!);
        }
      });

      _socket?.onDisconnect((_) {
        _isConnected = false;
        debugPrint('⚡ [RiderSocketService] Disconnected');
      });

      _socket?.onConnectError((err) {
        _isConnected = false;
        debugPrint('⚠️ [RiderSocketService] Connection error: $err');
      });

      // 1. Available orders for riders (placed, preparing, or ready_for_pickup)
      _socket?.on('order:available', (data) {
        debugPrint('📦 [RiderSocketService] Real-time order:available received: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final status = map['status']?.toString().toLowerCase().trim();
          if (status == null || status == 'ready_for_pickup' || status == 'placed' || status == 'preparing') {
            _orderAvailableController.add(map);
          }
        }
      });

      // 2. Order status changes
      _socket?.on('order:status_update', (data) {
        debugPrint('🔄 [RiderSocketService] Real-time order:status_update received');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _orderStatusController.add(map);
          final status = map['status']?.toString().toLowerCase().trim();
          if (status == 'ready_for_pickup' || status == 'placed' || status == 'preparing') {
            _orderAvailableController.add(map);
          }
        }
      });

      // 3. Order assigned event (when another or current rider accepts an order)
      _socket?.on('order:assigned', (data) {
        debugPrint('🚴 [RiderSocketService] Real-time order:assigned received: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _orderAssignedController.add(map);
          _orderStatusController.add(map);
        }
      });

      // 4. Targeted dispatch alert for this rider (with distance & 30s countdown)
      _socket?.on('order:dispatch', (data) {
        debugPrint('🚨 [RiderSocketService] Targeted dispatch received: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _orderDispatchController.add(map);
          _orderAvailableController.add(map);
        }
      });

      // 5. Dispatch cancelled (claimed by another rider)
      _socket?.on('order:dispatch_cancelled', (data) {
        debugPrint('❌ [RiderSocketService] Dispatch cancelled: $data');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          _orderDispatchCancelledController.add(map);
        }
      });

      _socket?.connect();
    } catch (e) {
      debugPrint('⚠️ [RiderSocketService] Exception: $e');
    }
  }

  void sendGpsPing(double lat, double lng, bool isOnline) {
    final riderId = HiveService.userId.isNotEmpty
        ? HiveService.userId
        : (HiveService.userPhone.isNotEmpty ? HiveService.userPhone : 'RIDER_DEVICE');
    debugPrint('📡 [RiderSocketService] Emitting rider:location_ping for $riderId ($lat, $lng) Online: $isOnline');
    _socket?.emit('rider:location_ping', {
      'riderId': riderId,
      'lat': lat,
      'lng': lng,
      'isOnline': isOnline,
    });
  }

  void sendLocation({
    required String orderId,
    required double latitude,
    required double longitude,
    required String riderId,
  }) {
    _socket?.emit('rider:location', {
      'orderId': orderId,
      'latitude': latitude,
      'longitude': longitude,
      'riderId': riderId,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void sendChatMessage(Map<String, dynamic> message) {
    _socket?.emit('chat:send', message);
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
