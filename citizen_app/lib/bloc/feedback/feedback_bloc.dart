import 'package:flutter_bloc/flutter_bloc.dart';
import 'feedback_event.dart';
import 'feedback_state.dart';

class FeedbackBloc extends Bloc<FeedbackEvent, FeedbackState> {
  FeedbackBloc() : super(FeedbackState.initial()) {
    on<SelectOptionEvent>((event, emit) {
      if (event.questionIndex == 0) {
        emit(state.copyWith(q1Selected: event.optionIndex));
      } else if (event.questionIndex == 1) {
        emit(state.copyWith(q2Selected: event.optionIndex));
      } else if (event.questionIndex == 2) {
        emit(state.copyWith(q3Selected: event.optionIndex));
      } else if (event.questionIndex == 3) {
        emit(state.copyWith(q4Selected: event.optionIndex));
      }
    });

    on<SubmitFeedbackEvent>((event, emit) {
      emit(FeedbackState.initial());
    });
  }
}
