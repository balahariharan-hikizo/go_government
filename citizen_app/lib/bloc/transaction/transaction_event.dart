abstract class TransactionEvent {}

class LoadTransactionsEvent extends TransactionEvent {}

class ResetTransactionsEvent extends TransactionEvent {}

class AddTransactionEvent extends TransactionEvent {
  final Map<String, dynamic> transaction;
  AddTransactionEvent(this.transaction);
}

class AddWalletMoneyEvent extends TransactionEvent {
  final double amount;
  final String paymentMethod;
  AddWalletMoneyEvent(this.amount, {this.paymentMethod = 'UPI'});
}

class DeductWalletMoneyEvent extends TransactionEvent {
  final double amount;
  final String reason;
  DeductWalletMoneyEvent(this.amount, {this.reason = 'Purchase'});
}

class AddCoinsEvent extends TransactionEvent {
  final int coins;
  final String reason;
  AddCoinsEvent(this.coins, {this.reason = 'Reward'});
}

class RedeemCoinsEvent extends TransactionEvent {
  final int coins;
  RedeemCoinsEvent(this.coins);
}

class SpendCoinsEvent extends TransactionEvent {
  final int coins;
  SpendCoinsEvent(this.coins);
}

class ToggleReorderScreenEvent extends TransactionEvent {
  final bool showReorderScreen;
  ToggleReorderScreenEvent(this.showReorderScreen);
}

class ReturnWatermelonProductEvent extends TransactionEvent {
  final int index;
  ReturnWatermelonProductEvent(this.index);
}

class UpdateOrderStatusEvent extends TransactionEvent {
  final String orderId;
  final String status;
  UpdateOrderStatusEvent({required this.orderId, required this.status});
}

