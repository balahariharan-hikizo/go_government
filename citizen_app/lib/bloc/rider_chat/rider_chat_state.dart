class RiderChatState {
  final List<Map<String, dynamic>> messages;

  RiderChatState({
    required this.messages,
  });

  factory RiderChatState.initial() {
    return RiderChatState(
      messages: [],
    );
  }

  RiderChatState copyWith({
    List<Map<String, dynamic>>? messages,
  }) {
    return RiderChatState(
      messages: messages ?? this.messages,
    );
  }
}
