import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../network/api_client.dart';

class StoreSocketService {
  static final StoreSocketService _instance = StoreSocketService._internal();
  factory StoreSocketService() => _instance;
  StoreSocketService._internal();

  io.Socket? _socket;
  bool _isConnected = false;
  bool get isConnected => _isConnected;
  String? _currentStoreId;

  final StreamController<Map<String, dynamic>> _newOrderController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _orderUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewOrder => _newOrderController.stream;
  Stream<Map<String, dynamic>> get onOrderUpdate => _orderUpdateController.stream;

  void init() {
    if (_socket != null) {
      if (!_socket!.connected) {
        _socket!.connect();
      }
      return;
    }

    final origin = ApiClient.baseUrl.replaceAll('/api', '');
    debugPrint('⚡ [StoreSocketService] Connecting to WebSocket: $origin');

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
        debugPrint('⚡ [StoreSocketService] Connected successfully (ID: ${_socket?.id})');
        if (_currentStoreId != null && _currentStoreId!.isNotEmpty) {
          _socket?.emit('join:store', _currentStoreId);
        }
      });

      _socket?.onDisconnect((_) {
        _isConnected = false;
        debugPrint('⚡ [StoreSocketService] Disconnected');
      });

      _socket?.onConnectError((err) {
        _isConnected = false;
        debugPrint('⚠️ [StoreSocketService] Connection error: $err');
      });

      // 1. Global status update listener
      _socket?.on('order:status_update', (data) {
        debugPrint('🔄 [StoreSocketService] Global order:status_update received');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final sid = map['storeId']?.toString() ?? map['storeDetails']?['storeId']?.toString();
          if (_currentStoreId == null || sid == null || sid.toLowerCase() == _currentStoreId!.toLowerCase()) {
            _orderUpdateController.add(map);
          }
        }
      });

      // 2. Global new order listener
      _socket?.on('order:new', (data) {
        debugPrint('📦 [StoreSocketService] Global order:new received');
        if (data is Map) {
          final map = Map<String, dynamic>.from(data);
          final sid = map['storeId']?.toString() ?? map['storeDetails']?['storeId']?.toString();
          if (_currentStoreId == null || sid == null || sid.toLowerCase() == _currentStoreId!.toLowerCase()) {
            _newOrderController.add(map);
          }
        }
      });

      _socket?.connect();
    } catch (e) {
      debugPrint('⚠️ [StoreSocketService] Exception: $e');
    }
  }

  void subscribeToStore(String storeId) {
    if (storeId.isEmpty) return;
    _currentStoreId = storeId;
    init();

    if (_socket != null && _isConnected) {
      _socket?.emit('join:store', storeId);
    }

    // Unbind prior listeners to prevent duplicate triggers
    _socket?.off('store:$storeId:new_order');
    _socket?.off('store:$storeId:order_update');

    _socket?.on('store:$storeId:new_order', (data) {
      debugPrint('📦 [StoreSocketService] Store-specific new order received for $storeId: $data');
      if (data is Map) {
        _newOrderController.add(Map<String, dynamic>.from(data));
      }
    });

    _socket?.on('store:$storeId:order_update', (data) {
      debugPrint('🔄 [StoreSocketService] Store-specific order update for $storeId: $data');
      if (data is Map) {
        _orderUpdateController.add(Map<String, dynamic>.from(data));
      }
    });
  }

  void dispose() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _isConnected = false;
  }
}
