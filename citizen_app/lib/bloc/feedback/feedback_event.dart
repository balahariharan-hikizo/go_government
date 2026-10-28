abstract class FeedbackEvent {}

class SelectOptionEvent extends FeedbackEvent {
  final int questionIndex;
  final int optionIndex;
  SelectOptionEvent(this.questionIndex, this.optionIndex);
}

class SubmitFeedbackEvent extends FeedbackEvent {}
