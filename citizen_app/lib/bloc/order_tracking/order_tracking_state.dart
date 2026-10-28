class OrderTrackingState {
  final int currentStep;
  final String? activeOrderId;
  final Map<String, dynamic>? activeOrder;
  final bool isCancelled;

  OrderTrackingState({
    required this.currentStep,
    this.activeOrderId,
    this.activeOrder,
    this.isCancelled = false,
  });

  factory OrderTrackingState.initial() {
    return OrderTrackingState(
      currentStep: 0,
      activeOrderId: null,
      activeOrder: null,
      isCancelled: false,
    );
  }

  OrderTrackingState copyWith({
    int? currentStep,
    String? activeOrderId,
    Map<String, dynamic>? activeOrder,
    bool? isCancelled,
  }) {
    return OrderTrackingState(
      currentStep: currentStep ?? this.currentStep,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      activeOrder: activeOrder ?? this.activeOrder,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}

