import '../../screen/home/bus_stop/near_bus_stop_screen.dart';

abstract class BusStopEvent {}

class ChangeBusStopFlowStateEvent extends BusStopEvent {
  final BusStopFlowState flowState;
  ChangeBusStopFlowStateEvent(this.flowState);
}

class ChangeBusStopWalkModeEvent extends BusStopEvent {
  final bool isWalkMode;
  ChangeBusStopWalkModeEvent(this.isWalkMode);
}

class SelectBusStopEvent extends BusStopEvent {
  final int selectedIndex;
  SelectBusStopEvent(this.selectedIndex);
}
