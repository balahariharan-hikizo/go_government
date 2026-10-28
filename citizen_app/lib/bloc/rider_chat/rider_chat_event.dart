abstract class RiderChatEvent {}

class InitChatEvent extends RiderChatEvent {
  final String orderId;
  InitChatEvent(this.orderId);
}

class SendChatMessageEvent extends RiderChatEvent {
  final String text;
  final String orderId;
  final String senderName;
  SendChatMessageEvent(this.text, {this.orderId = '', this.senderName = 'Citizen'});
}

class ReceiveChatMessageEvent extends RiderChatEvent {
  final Map<String, dynamic> message;
  ReceiveChatMessageEvent(this.message);
}

class ClearChatEvent extends RiderChatEvent {}
