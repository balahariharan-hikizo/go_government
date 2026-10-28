import 'package:flutter_bloc/flutter_bloc.dart';
import 'order_tracking_event.dart';
import 'order_tracking_state.dart';

class OrderTrackingBloc extends Bloc<OrderTrackingEvent, OrderTrackingState> {
  OrderTrackingBloc() : super(OrderTrackingState.initial()) {
    on<UpdateTrackingStepEvent>((event, emit) {
      emit(state.copyWith(currentStep: event.step));
    });

    on<SetTrackingOrderEvent>((event, emit) {
      final orderId = event.order['orderId']?.toString() ?? event.order['id']?.toString();
      emit(state.copyWith(
        activeOrderId: orderId,
        activeOrder: event.order,
        currentStep: event.initialStep,
        isCancelled: false,
      ));
    });

    on<CancelActiveOrderEvent>((event, emit) {
      emit(state.copyWith(
        isCancelled: true,
        currentStep: 0,
      ));
    });
  }
}

