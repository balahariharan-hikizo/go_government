import 'package:flutter_bloc/flutter_bloc.dart';
import 'toilet_event.dart';
import 'toilet_state.dart';

class ToiletBloc extends Bloc<ToiletEvent, ToiletState> {
  ToiletBloc() : super(ToiletState.initial()) {
    on<ChangeToiletFlowStateEvent>((event, emit) {
      emit(state.copyWith(flowState: event.flowState));
    });

    on<ChangeToiletWalkModeEvent>((event, emit) {
      emit(state.copyWith(isWalkMode: event.isWalkMode));
    });

    on<SelectToiletEvent>((event, emit) {
      emit(state.copyWith(selectedIndex: event.selectedIndex));
    });
  }
}
