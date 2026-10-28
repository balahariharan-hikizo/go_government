import '../../screen/home/toilet/near_toilet_screen.dart';

class ToiletState {
  final ToiletFlowState flowState;
  final bool isWalkMode;
  final int selectedIndex;

  ToiletState({
    required this.flowState,
    required this.isWalkMode,
    required this.selectedIndex,
  });

  factory ToiletState.initial() {
    return ToiletState(
      flowState: ToiletFlowState.list,
      isWalkMode: false,
      selectedIndex: 0,
    );
  }

  ToiletState copyWith({
    ToiletFlowState? flowState,
    bool? isWalkMode,
    int? selectedIndex,
  }) {
    return ToiletState(
      flowState: flowState ?? this.flowState,
      isWalkMode: isWalkMode ?? this.isWalkMode,
      selectedIndex: selectedIndex ?? this.selectedIndex,
    );
  }
}
