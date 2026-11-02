abstract class OrderEvent {}

class LoadStoreOrdersEvent extends OrderEvent {
  final String storeId;
  final bool showLoading;

  LoadStoreOrdersEvent({
    required this.storeId,
    this.showLoading = true,
  });
}

class NewOrderReceivedEvent extends OrderEvent {
  final Map<String, dynamic> order;
  NewOrderReceivedEvent(this.order);
}

class OrderUpdatedEvent extends OrderEvent {
  final Map<String, dynamic> order;
  OrderUpdatedEvent(this.order);
}

class ReturnRequestedEvent extends OrderEvent {
  final Map<String, dynamic> order;
  ReturnRequestedEvent(this.order);
}

class UpdateOrderStatusEvent extends OrderEvent {
  final String orderId;
  final String newStatus;
  final String successMessage;

  UpdateOrderStatusEvent({
    required this.orderId,
    required this.newStatus,
    required this.successMessage,
  });
}

class ConfirmReturnEvent extends OrderEvent {
  final String orderId;
  final String storeId;
  final String? condition;
  final String? notes;

  ConfirmReturnEvent({
    required this.orderId,
    required this.storeId,
    this.condition,
    this.notes,
  });
}

class ReviewCitizenReturnEvent extends OrderEvent {
  final String orderId;
  final String storeId;
  final String action; // 'approve' | 'reject'
  final String? rejectionReason;

  ReviewCitizenReturnEvent({
    required this.orderId,
    required this.storeId,
    required this.action,
    this.rejectionReason,
  });
}

