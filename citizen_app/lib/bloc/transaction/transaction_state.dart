import '../../hive/hive_service.dart';

class TransactionState {
  final List<Map<String, dynamic>> transactions;
  final double walletBalance;
  final int coinsBalance;
  final bool showReorderScreen;
  final List<bool> watermelonReturned;

  TransactionState({
    required this.transactions,
    required this.walletBalance,
    required this.coinsBalance,
    required this.showReorderScreen,
    required this.watermelonReturned,
  });

  static const Set<String> mockIds = {
    'ORD-20261112-9876',
    'ORD-20261113-1122',
    'ORD-20261113-5432',
    'ORD-20261113-7788',
  };

  static bool isMock(Map<String, dynamic> tx) {
    final id = tx['id']?.toString() ?? '';
    return mockIds.contains(id);
  }

  static const List<Map<String, dynamic>> defaultTransactions = [];

  factory TransactionState.initial() {
    final raw = HiveService.getMyTransactions();
    final clean = raw.where((tx) => !isMock(tx)).toList();
    if (clean.length != raw.length) {
      HiveService.saveAllTransactions(clean);
    }
    final wallet = HiveService.getWalletBalance();
    final coins = HiveService.getCoinsBalance();

    return TransactionState(
      transactions: clean,
      walletBalance: wallet,
      coinsBalance: coins,
      showReorderScreen: false,
      watermelonReturned: List.generate(4, (_) => false),
    );
  }

  TransactionState copyWith({
    List<Map<String, dynamic>>? transactions,
    double? walletBalance,
    int? coinsBalance,
    bool? showReorderScreen,
    List<bool>? watermelonReturned,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      walletBalance: walletBalance ?? this.walletBalance,
      coinsBalance: coinsBalance ?? this.coinsBalance,
      showReorderScreen: showReorderScreen ?? this.showReorderScreen,
      watermelonReturned: watermelonReturned ?? this.watermelonReturned,
    );
  }
}
