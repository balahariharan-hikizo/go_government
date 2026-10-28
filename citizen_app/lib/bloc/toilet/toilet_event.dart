import '../../screen/home/toilet/near_toilet_screen.dart';

abstract class ToiletEvent {}

class ChangeToiletFlowStateEvent extends ToiletEvent {
  final ToiletFlowState flowState;
  ChangeToiletFlowStateEvent(this.flowState);
}

class ChangeToiletWalkModeEvent extends ToiletEvent {
  final bool isWalkMode;
  ChangeToiletWalkModeEvent(this.isWalkMode);
}

class SelectToiletEvent extends ToiletEvent {
  final int selectedIndex;
  SelectToiletEvent(this.selectedIndex);
}
