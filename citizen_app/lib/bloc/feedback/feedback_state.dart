class FeedbackState {
  final int q1Selected;
  final int q2Selected;
  final int q3Selected;
  final int q4Selected;

  FeedbackState({
    required this.q1Selected,
    required this.q2Selected,
    required this.q3Selected,
    required this.q4Selected,
  });

  factory FeedbackState.initial() {
    return FeedbackState(
      q1Selected: -1,
      q2Selected: -1,
      q3Selected: -1,
      q4Selected: -1,
    );
  }

  FeedbackState copyWith({
    int? q1Selected,
    int? q2Selected,
    int? q3Selected,
    int? q4Selected,
  }) {
    return FeedbackState(
      q1Selected: q1Selected ?? this.q1Selected,
      q2Selected: q2Selected ?? this.q2Selected,
      q3Selected: q3Selected ?? this.q3Selected,
      q4Selected: q4Selected ?? this.q4Selected,
    );
  }
}
