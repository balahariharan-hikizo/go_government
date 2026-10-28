abstract class OrderTrackingEvent {}

class UpdateTrackingStepEvent extends OrderTrackingEvent {
  final int step;
  UpdateTrackingStepEvent(this.step);
}

class SetTrackingOrderEvent extends OrderTrackingEvent {
  final Map<String, dynamic> order;
  final int initialStep;
  SetTrackingOrderEvent(this.order, {this.initialStep = 0});
}

class CancelActiveOrderEvent extends OrderTrackingEvent {
  final String orderId;
  final String reason;
  CancelActiveOrderEvent({required this.orderId, required this.reason});
}

