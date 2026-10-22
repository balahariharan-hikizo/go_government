abstract class CustomerChatEvent {}

class InitCustomerChatEvent extends CustomerChatEvent {
  final String orderId;
  InitCustomerChatEvent(this.orderId);
}

class SendCustomerChatMessageEvent extends CustomerChatEvent {
  final String text;
  final String orderId;
  final String senderName;
  SendCustomerChatMessageEvent(this.text, {required this.orderId, this.senderName = 'Delivery Partner'});
}

class ReceiveCustomerChatMessageEvent extends CustomerChatEvent {
  final Map<String, dynamic> message;
  ReceiveCustomerChatMessageEvent(this.message);
}

class ClearCustomerChatEvent extends CustomerChatEvent {}
