class CustomerChatState {
  final List<Map<String, dynamic>> messages;

  CustomerChatState({required this.messages});

  factory CustomerChatState.initial() {
    return CustomerChatState(messages: []);
  }

  CustomerChatState copyWith({List<Map<String, dynamic>>? messages}) {
    return CustomerChatState(
      messages: messages ?? this.messages,
    );
  }
}
