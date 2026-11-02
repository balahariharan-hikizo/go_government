abstract class OrderState {}

class OrderInitial extends OrderState {}

class OrderLoading extends OrderState {}

class OrderLoaded extends OrderState {
  final List<Map<String, dynamic>> orders;
  final String? notificationMessage;
  final bool isErrorNotification;
  final int timestamp;

  OrderLoaded({
    required this.orders,
    this.notificationMessage,
    this.isErrorNotification = false,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
}

class OrderError extends OrderState {
  final String message;
  OrderError(this.message);
}

