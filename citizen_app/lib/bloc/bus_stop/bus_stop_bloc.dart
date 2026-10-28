import 'package:flutter_bloc/flutter_bloc.dart';
import 'bus_stop_event.dart';
import 'bus_stop_state.dart';

class BusStopBloc extends Bloc<BusStopEvent, BusStopState> {
  BusStopBloc() : super(BusStopState.initial()) {
    on<ChangeBusStopFlowStateEvent>((event, emit) {
      emit(state.copyWith(flowState: event.flowState));
    });

    on<ChangeBusStopWalkModeEvent>((event, emit) {
      emit(state.copyWith(isWalkMode: event.isWalkMode));
    });

    on<SelectBusStopEvent>((event, emit) {
      emit(state.copyWith(selectedIndex: event.selectedIndex));
    });
  }
}
