import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hive/hive_service.dart';
import '../../network/wallet_api_service.dart';
import 'transaction_event.dart';
import 'transaction_state.dart';

class TransactionBloc extends Bloc<TransactionEvent, TransactionState> {
  static final TransactionBloc instance = TransactionBloc._();

  TransactionBloc() : this._();

  TransactionBloc._() : super(TransactionState.initial()) {
    on<ResetTransactionsEvent>((event, emit) {
      emit(TransactionState(
        transactions: [],
        walletBalance: 0.0,
        coinsBalance: 0,
        showReorderScreen: false,
        watermelonReturned: List.generate(4, (_) => false),
      ));
    });

    on<LoadTransactionsEvent>((event, emit) async {
      // 1. Instantly display cached Hive state
      final raw = HiveService.getMyTransactions();
      final clean = raw.where((tx) => !TransactionState.isMock(tx)).toList();
      if (clean.length != raw.length) {
        HiveService.saveAllTransactions(clean);
      }
      final localWallet = HiveService.getWalletBalance();
      final localCoins = HiveService.getCoinsBalance();

      emit(state.copyWith(
        transactions: clean,
        walletBalance: localWallet,
        coinsBalance: localCoins,
      ));

      // 2. Fetch live balance, ledger, and order history from MongoDB backend
      try {
        final results = await Future.wait([
          WalletApiService.getWalletDetails(),
          WalletApiService.getOrderHistory(),
        ]);

        final walletRes = results[0] as Map<String, dynamic>;
        final orderTxs = results[1] as List<Map<String, dynamic>>;

        double serverWallet = localWallet;
        int serverCoins = localCoins;
        final nonOrderWalletTxs = <Map<String, dynamic>>[];

        if (walletRes['success'] == true) {
          serverWallet = (walletRes['walletBalance'] as num?)?.toDouble() ?? 0.0;
          serverCoins = (walletRes['coinsBalance'] as num?)?.toInt() ?? 0;
          final serverTxs = walletRes['transactions'] as List<dynamic>? ?? [];

          for (final t in serverTxs) {
            if (t is Map) {
              final cat = t['category']?.toString();
              final orderId = t['orderId']?.toString();
              // Exclude regular order payment transactions from wallet ledger so they don't duplicate orderTxs.
              // But always include order refunds (category == 'order_refund') so the refund credit appears!
              if (cat == 'order_payment' || (cat != 'order_refund' && orderId != null && orderId.isNotEmpty)) {
                continue;
              }

              final isCredit = t['type'] == 'credit';
              final amt = (t['amount'] as num?)?.abs().toDouble() ?? 0.0;
              nonOrderWalletTxs.add({
                'id': t['transactionId'] ?? t['_id'] ?? '',
                'title': t['title'] ?? (cat == 'order_refund' ? 'Order Refund' : 'Transaction'),
                'subtitle': t['subtitle'] ?? '',
                'amount': isCredit ? '+₹${amt.toInt()}' : '-₹${amt.toInt()}',
                'isPositive': isCredit,
                'status': t['status'] == 'success' ? 'Successful' : (t['status'] ?? 'Successful'),
                'date': t['subtitle']?.toString().split('·').last.trim() ?? '',
                'createdAt': t['createdAt'],
                'items': [],
                'address': t['paymentMethod'] ?? 'Wallet Account',
                'listingPrice': '₹0.00',
                'sellingPrice': '₹${amt.toInt()}',
                'grandTotal': '₹${amt.toInt()}',
                'paid': '₹${amt.toInt()}',
                'paymentMethod': t['paymentMethod'] ?? 'Wallet',
                'category': cat,
                'orderId': orderId,
              });
            }
          }
        }

        // Merge order history with non-order wallet entries (top-ups, coin redemptions, refunds)
        if (orderTxs.isNotEmpty || nonOrderWalletTxs.isNotEmpty) {
          final combined = <Map<String, dynamic>>[
            ...orderTxs,
            ...nonOrderWalletTxs,
          ];

          // Sort descending by date so recent refunds & top-ups appear right at the top!
          combined.sort((a, b) {
            final aDate = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

          await HiveService.setWalletBalance(serverWallet);
          await HiveService.setCoinsBalance(serverCoins);
          await HiveService.saveAllTransactions(combined);

          emit(state.copyWith(
            walletBalance: serverWallet,
            coinsBalance: serverCoins,
            transactions: combined,
          ));
        } else if (walletRes['success'] == true) {
          await HiveService.setWalletBalance(serverWallet);
          await HiveService.setCoinsBalance(serverCoins);
          await HiveService.saveAllTransactions([]);
          emit(state.copyWith(
            walletBalance: serverWallet,
            coinsBalance: serverCoins,
            transactions: [],
          ));
        }
      } catch (_) {}
    });

    on<AddTransactionEvent>((event, emit) async {
      await HiveService.saveTransaction(event.transaction);
      final updatedList = HiveService.getMyTransactions();
      emit(state.copyWith(transactions: updatedList));
    });

    on<AddWalletMoneyEvent>((event, emit) async {
      // 1. Optimistic UI update
      final optimisticBal = state.walletBalance + event.amount;
      await HiveService.setWalletBalance(optimisticBal);

      final now = DateTime.now();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final dateStr = '${months[now.month - 1]} ${now.day} · ${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'pm' : 'am'}';

      final tx = {
        'id': 'TOP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        'title': 'Wallet Top-up',
        'subtitle': 'Added via ${event.paymentMethod} · $dateStr',
        'amount': '+₹${event.amount.toInt()}',
        'isPositive': true,
        'status': 'Successful',
        'date': dateStr,
        'items': [],
        'address': 'Wallet Account',
        'listingPrice': '₹0.00',
        'sellingPrice': '₹${event.amount.toInt()}',
        'grandTotal': '₹${event.amount.toInt()}',
        'paid': '₹${event.amount.toInt()}',
      };

      await HiveService.saveTransaction(tx);
      emit(state.copyWith(
        walletBalance: optimisticBal,
        transactions: HiveService.getMyTransactions(),
      ));

      // 2. Persist to MongoDB backend
      try {
        final res = await WalletApiService.topupWallet(
          amount: event.amount,
          paymentMethod: event.paymentMethod,
        );
        if (res['success'] == true) {
          final serverBal = (res['walletBalance'] as num?)?.toDouble() ?? optimisticBal;
          await HiveService.setWalletBalance(serverBal);
          emit(state.copyWith(walletBalance: serverBal));
        }
      } catch (_) {}
    });

    on<DeductWalletMoneyEvent>((event, emit) async {
      final newBalance = (state.walletBalance - event.amount).clamp(0.0, double.infinity);
      await HiveService.setWalletBalance(newBalance);
      emit(state.copyWith(walletBalance: newBalance));
    });

    on<AddCoinsEvent>((event, emit) async {
      final newCoins = state.coinsBalance + event.coins;
      await HiveService.setCoinsBalance(newCoins);
      emit(state.copyWith(coinsBalance: newCoins));

      // Persist to MongoDB backend
      try {
        final res = await WalletApiService.addCoins(
          coins: event.coins,
          reason: event.reason,
        );
        if (res['success'] == true) {
          final serverCoins = (res['coinsBalance'] as num?)?.toInt() ?? newCoins;
          await HiveService.setCoinsBalance(serverCoins);
          emit(state.copyWith(coinsBalance: serverCoins));
        }
      } catch (_) {}
    });

    on<RedeemCoinsEvent>((event, emit) async {
      // Minimum 100 coins required to redeem (100 coins = ₹1)
      if (state.coinsBalance < event.coins || event.coins < 100) return;
      final double cashAmount = (event.coins / 100).floorToDouble();
      if (cashAmount <= 0) return;
      final int actualCoinsToDeduct = (cashAmount * 100).toInt();
      final newCoins = state.coinsBalance - actualCoinsToDeduct;
      final newBalance = state.walletBalance + cashAmount;

      await HiveService.setCoinsBalance(newCoins);
      await HiveService.setWalletBalance(newBalance);

      // Call backend
      try {
        await WalletApiService.redeemCoins(coins: actualCoinsToDeduct);
      } catch (_) {}

      final now = DateTime.now();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final dateStr = '${months[now.month - 1]} ${now.day} · ${now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour)}:${now.minute.toString().padLeft(2, '0')} ${now.hour >= 12 ? 'pm' : 'am'}';

      final tx = {
        'id': 'RED-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        'title': 'Coins Redeemed',
        'subtitle': '$actualCoinsToDeduct coins converted · $dateStr',
        'amount': '+₹${cashAmount.toInt()}',
        'isPositive': true,
        'status': 'Credited',
        'date': dateStr,
        'items': [],
        'address': 'Reward Redemption',
        'listingPrice': '₹0.00',
        'sellingPrice': '₹${cashAmount.toInt()}',
        'grandTotal': '₹${cashAmount.toInt()}',
        'paid': '₹${cashAmount.toInt()}',
      };

      await HiveService.saveTransaction(tx);
      final updatedList = HiveService.getMyTransactions();

      emit(state.copyWith(
        walletBalance: newBalance,
        coinsBalance: newCoins,
        transactions: updatedList,
      ));
    });

    on<SpendCoinsEvent>((event, emit) async {
      final newCoins = (state.coinsBalance - event.coins).clamp(0, 999999);
      await HiveService.setCoinsBalance(newCoins);
      emit(state.copyWith(coinsBalance: newCoins));
    });

    on<ToggleReorderScreenEvent>((event, emit) {
      emit(state.copyWith(showReorderScreen: event.showReorderScreen));
    });

    on<ReturnWatermelonProductEvent>((event, emit) {
      final updatedList = List<bool>.from(state.watermelonReturned);
      if (event.index >= 0 && event.index < updatedList.length) {
        updatedList[event.index] = true;
      }
      emit(state.copyWith(watermelonReturned: updatedList));
    });

    on<UpdateOrderStatusEvent>((event, emit) async {
      final currentList = HiveService.getMyTransactions();
      final index = currentList.indexWhere((t) => t['id']?.toString() == event.orderId);
      if (index != -1) {
        currentList[index]['status'] = event.status;
        await HiveService.saveAllTransactions(currentList);
        emit(state.copyWith(transactions: currentList));
      } else {
        final inMemoryList = List<Map<String, dynamic>>.from(
          state.transactions.map((t) => Map<String, dynamic>.from(t)),
        );
        final mIndex = inMemoryList.indexWhere((t) => t['id']?.toString() == event.orderId);
        if (mIndex != -1) {
          inMemoryList[mIndex]['status'] = event.status;
          await HiveService.saveAllTransactions(inMemoryList);
          emit(state.copyWith(transactions: inMemoryList));
        }
      }
    });
  }
}
