import '../../screen/home/bus_stop/near_bus_stop_screen.dart';

class BusStopState {
  final BusStopFlowState flowState;
  final bool isWalkMode;
  final int selectedIndex;

  BusStopState({
    required this.flowState,
    required this.isWalkMode,
    required this.selectedIndex,
  });

  factory BusStopState.initial() {
    return BusStopState(
      flowState: BusStopFlowState.list,
      isWalkMode: false,
      selectedIndex: 0,
    );
  }

  BusStopState copyWith({
    BusStopFlowState? flowState,
    bool? isWalkMode,
    int? selectedIndex,
  }) {
    return BusStopState(
      flowState: flowState ?? this.flowState,
      isWalkMode: isWalkMode ?? this.isWalkMode,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}
