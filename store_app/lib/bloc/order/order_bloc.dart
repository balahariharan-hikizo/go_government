import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../network/store_order_api_service.dart';
import '../../services/socket_service.dart';
import 'order_event.dart';
import 'order_state.dart';

class OrderBloc extends Bloc<OrderEvent, OrderState> {
  static final OrderBloc instance = OrderBloc._internal();
  factory OrderBloc() => instance;

  List<Map<String, dynamic>> _orders = [];
  StreamSubscription? _newOrderSub;
  StreamSubscription? _orderUpdateSub;
  StreamSubscription? _returnReqSub;
  String? _subscribedStoreId;

  OrderBloc._internal() : super(OrderInitial()) {
    on<LoadStoreOrdersEvent>((event, emit) async {
      _bindSocket(event.storeId);
      if (event.showLoading && _orders.isEmpty) {
        emit(OrderLoading());
      }

      try {
        final list = await StoreOrderApiService.fetchStoreOrders(event.storeId);
        _orders = list;
        emit(OrderLoaded(orders: List.from(_orders)));
      } catch (e) {
        if (_orders.isEmpty) {
          emit(OrderError('Failed to fetch orders: $e'));
        } else {
          emit(OrderLoaded(orders: List.from(_orders)));
        }
      }
    });

    on<NewOrderReceivedEvent>((event, emit) {
      final orderId = event.order['orderId']?.toString();
      _orders.removeWhere((o) => o['orderId']?.toString() == orderId);
      _orders.insert(0, event.order);
      emit(OrderLoaded(
        orders: List.from(_orders),
        notificationMessage: '🔔 New Order #${orderId ?? ''} received!',
      ));
    });

    on<OrderUpdatedEvent>((event, emit) {
      final orderId = event.order['orderId']?.toString();
      final idx = _orders.indexWhere((o) => o['orderId']?.toString() == orderId);
      if (idx != -1) {
        _orders[idx] = Map<String, dynamic>.from(event.order);
      } else {
        _orders.insert(0, event.order);
      }
      emit(OrderLoaded(orders: List.from(_orders)));
    });

    on<ReturnRequestedEvent>((event, emit) {
      final orderId = event.order['orderId']?.toString();
      final idx = _orders.indexWhere((o) => o['orderId']?.toString() == orderId);
      if (idx != -1) {
        _orders[idx] = Map<String, dynamic>.from(event.order);
      } else {
        _orders.insert(0, event.order);
      }
      emit(OrderLoaded(
        orders: List.from(_orders),
        notificationMessage: '⚠️ Return requested for Order #${orderId ?? ''}',
        isErrorNotification: false,
      ));
    });

    on<UpdateOrderStatusEvent>((event, emit) async {
      final idx = _orders.indexWhere((o) => o['orderId']?.toString() == event.orderId);
      Map<String, dynamic>? prev;
      if (idx != -1) {
        prev = Map<String, dynamic>.from(_orders[idx]);
        _orders[idx] = Map<String, dynamic>.from(_orders[idx])..['status'] = event.newStatus;
        emit(OrderLoaded(orders: List.from(_orders)));
      }

      final success = await StoreOrderApiService.updateOrderStatus(
        orderId: event.orderId,
        status: event.newStatus,
      );

      if (success) {
        emit(OrderLoaded(
          orders: List.from(_orders),
          notificationMessage: event.successMessage,
        ));
      } else {
        // Rollback on failure
        if (idx != -1 && prev != null) {
          _orders[idx] = prev;
        }
        emit(OrderLoaded(
          orders: List.from(_orders),
          notificationMessage: 'Failed to update order status',
          isErrorNotification: true,
        ));
      }
    });

    on<ConfirmReturnEvent>((event, emit) async {
      final res = await StoreOrderApiService.confirmReturn(
        orderId: event.orderId,
        storeId: event.storeId,
        condition: event.condition,
        notes: event.notes,
      );

      if (res['success'] == true) {
        // Fetch fresh orders to update financials and status
        final list = await StoreOrderApiService.fetchStoreOrders(event.storeId);
        _orders = list;
        emit(OrderLoaded(
          orders: List.from(_orders),
          notificationMessage: '✅ Return confirmed! Items restocked & customer refunded.',
        ));
      } else {
        emit(OrderLoaded(
          orders: List.from(_orders),
          notificationMessage: res['message']?.toString() ?? 'Failed to confirm return',
          isErrorNotification: true,
        ));
      }
    });

    on<ReviewCitizenReturnEvent>((event, emit) async {
      final res = await StoreOrderApiService.reviewCitizenReturn(
        orderId: event.orderId,
        storeId: event.storeId,
        action: event.action,
        rejectionReason: event.rejectionReason,
      );

      if (res['success'] == true) {
        final list = await StoreOrderApiService.fetchStoreOrders(event.storeId);
        _orders = list;
        final msg = event.action == 'approve'
            ? '✅ Return approved! Delivery partner dispatched for customer doorstep pickup.'
            : 'Return request declined.';
        emit(OrderLoaded(
          orders: List.from(_orders),
          notificationMessage: msg,
          isErrorNotification: event.action != 'approve',
        ));
      } else {
        emit(OrderLoaded(
          orders: List.from(_orders),
          notificationMessage: res['message']?.toString() ?? 'Failed to process return request',
          isErrorNotification: true,
        ));
      }
    });
  }

  void _bindSocket(String storeId) {
    if (_subscribedStoreId == storeId) return;
    _subscribedStoreId = storeId;

    _newOrderSub?.cancel();
    _orderUpdateSub?.cancel();
    _returnReqSub?.cancel();

    StoreSocketService().subscribeToStore(storeId);

    _newOrderSub = StoreSocketService().onNewOrder.listen((newOrder) {
      add(NewOrderReceivedEvent(newOrder));
    });

    _orderUpdateSub = StoreSocketService().onOrderUpdate.listen((updatedOrder) {
      add(OrderUpdatedEvent(updatedOrder));
    });

    _returnReqSub = StoreSocketService().onReturnRequested.listen((returnOrder) {
      add(ReturnRequestedEvent(returnOrder));
    });
  }

  @override
  Future<void> close() {
    _newOrderSub?.cancel();
    _orderUpdateSub?.cancel();
    _returnReqSub?.cancel();
    return super.close();
  }
}

