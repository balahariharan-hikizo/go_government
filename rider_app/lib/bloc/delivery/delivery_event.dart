import 'package:equatable/equatable.dart';
import '../../model/delivery_order_model.dart';

abstract class DeliveryEvent extends Equatable {
  const DeliveryEvent();

  @override
  List<Object?> get props => [];
}

class LoadDeliveriesEvent extends DeliveryEvent {}

class ToggleDutyEvent extends DeliveryEvent {
  final bool isOnline;
  const ToggleDutyEvent(this.isOnline);

  @override
  List<Object?> get props => [isOnline];
}

class AcceptDeliveryOrderEvent extends DeliveryEvent {
  final DeliveryOrder order;
  const AcceptDeliveryOrderEvent(this.order);

  @override
  List<Object?> get props => [order];
}

class ConfirmStorePickupEvent extends DeliveryEvent {
  final String orderId;
  const ConfirmStorePickupEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class ConfirmDeliveredEvent extends DeliveryEvent {
  final String orderId;
  const ConfirmDeliveredEvent(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class InitiateReturnEvent extends DeliveryEvent {
  final String orderId;
  final String riderId;
  final String reason;
  final String? notes;

  const InitiateReturnEvent({
    required this.orderId,
    required this.riderId,
    required this.reason,
    this.notes,
  });

  @override
  List<Object?> get props => [orderId, riderId, reason, notes];
}
