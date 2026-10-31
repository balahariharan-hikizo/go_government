import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../hive/hive_service.dart';

class WalletApiService {
  static String get _userId {
    final uid = HiveService.userId;
    if (uid.isNotEmpty) return uid;
    final phone = HiveService.userPhone;
    if (phone.isNotEmpty) return phone;
    return '';
  }

  /// Fetches live wallet balance, coins, and ledger transactions from MongoDB
  static Future<Map<String, dynamic>> getWalletDetails([String? userId]) async {
    final resolvedUser = userId ?? _userId;
    if (resolvedUser.isEmpty) {
      return {'success': true, 'walletBalance': 0.0, 'coinsBalance': 0, 'transactions': []};
    }
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/wallet/$resolvedUser');
      final res = await http.get(url, headers: ApiClient.defaultHeaders).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'success': true,
          'walletBalance': (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
          'coinsBalance': (data['coinsBalance'] as num?)?.toInt() ?? 0,
          'transactions': data['transactions'] as List<dynamic>? ?? [],
        };
      }
    } catch (e) {
      debugPrint('[WalletApiService] getWalletDetails error: $e');
    }
    return {'success': false, 'walletBalance': 0.0, 'coinsBalance': 0, 'transactions': []};
  }

  /// Tops up citizen wallet via UPI / NetBanking / Cards
  static Future<Map<String, dynamic>> topupWallet({
    required double amount,
    String? paymentMethod,
    String? referenceId,
    String? userId,
  }) async {
    final resolvedUser = userId ?? _userId;
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/wallet/topup');
      final body = jsonEncode({
        'userId': resolvedUser,
        'amount': amount,
        'paymentMethod': paymentMethod ?? 'UPI',
        'referenceId': referenceId ?? 'UPI_${DateTime.now().millisecondsSinceEpoch}',
      });

      final res = await http.post(url, headers: ApiClient.defaultHeaders, body: body).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'success': true,
          'walletBalance': (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
          'coinsBalance': (data['coinsBalance'] as num?)?.toInt() ?? 0,
          'transaction': data['transaction'],
          'message': data['message'] ?? 'Wallet topped up successfully',
        };
      } else {
        final data = jsonDecode(res.body);
        return {'success': false, 'error': data['error'] ?? 'Top-up failed'};
      }
    } catch (e) {
      debugPrint('[WalletApiService] topupWallet error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Atomically deducts wallet for an order
  static Future<Map<String, dynamic>> deductWallet({
    required double amount,
    String? orderId,
    String? title,
    String? subtitle,
    String? userId,
  }) async {
    final resolvedUser = userId ?? _userId;
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/wallet/deduct');
      final body = jsonEncode({
        'userId': resolvedUser,
        'amount': amount,
        'orderId': orderId,
        'title': title,
        'subtitle': subtitle,
      });

      final res = await http.post(url, headers: ApiClient.defaultHeaders, body: body).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'success': true,
          'walletBalance': (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
          'transaction': data['transaction'],
        };
      } else {
        final data = jsonDecode(res.body);
        return {
          'success': false,
          'code': data['code'],
          'error': data['error'] ?? 'Wallet payment failed',
          'walletBalance': (data['walletBalance'] as num?)?.toDouble(),
        };
      }
    } catch (e) {
      debugPrint('[WalletApiService] deductWallet error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Converts reward coins to wallet cash (100 coins = ₹1)
  static Future<Map<String, dynamic>> redeemCoins({
    required int coins,
    String? userId,
  }) async {
    final resolvedUser = userId ?? _userId;
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/wallet/redeem-coins');
      final body = jsonEncode({
        'userId': resolvedUser,
        'coins': coins,
      });

      final res = await http.post(url, headers: ApiClient.defaultHeaders, body: body).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'success': true,
          'walletBalance': (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
          'coinsBalance': (data['coinsBalance'] as num?)?.toInt() ?? 0,
          'message': data['message'],
        };
      } else {
        final data = jsonDecode(res.body);
        return {'success': false, 'error': data['error'] ?? 'Redemption failed'};
      }
    } catch (e) {
      debugPrint('[WalletApiService] redeemCoins error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Credits reward coins to citizen account (e.g. from grievances, feedback surveys)
  static Future<Map<String, dynamic>> addCoins({
    required int coins,
    String? reason,
    String? userId,
  }) async {
    final resolvedUser = userId ?? _userId;
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/wallet/add-coins');
      final body = jsonEncode({
        'userId': resolvedUser,
        'coins': coins,
        'reason': reason ?? 'Civic Activity Reward',
      });

      final res = await http.post(url, headers: ApiClient.defaultHeaders, body: body).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'success': true,
          'walletBalance': (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
          'coinsBalance': (data['coinsBalance'] as num?)?.toInt() ?? 0,
          'message': data['message'],
        };
      } else {
        final data = jsonDecode(res.body);
        return {'success': false, 'error': data['error'] ?? 'Failed to add coins'};
      }
    } catch (e) {
      debugPrint('[WalletApiService] addCoins error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Fetches full order history from MongoDB and maps to transaction format
  static Future<List<Map<String, dynamic>>> getOrderHistory([String? userId]) async {
    final resolvedUser = userId ?? _userId;
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/orders/user/$resolvedUser');
      final res = await http.get(url, headers: ApiClient.defaultHeaders).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final orders = data['data'] as List<dynamic>? ?? [];
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

        return orders.map<Map<String, dynamic>>((o) {
          final total = (o['grandTotal'] as num?)?.toInt() ?? 0;
          final storeDetails = (o['storeDetails'] as Map?) ?? {};
          final storeId = (o['storeId'] ?? storeDetails['storeId'] ?? '').toString();
          final storeName = (storeDetails['name'] ?? o['storeName'] ?? 'Store Order').toString();
          final storePhone = (storeDetails['phone'] ?? '').toString();
          final orderId = o['orderId']?.toString() ?? '';
          final status = o['status']?.toString() ?? 'placed';
          final payMethod = o['paymentMethod']?.toString() ?? 'Cash on Delivery';
          final addr = o['deliveryAddress']?['address']?.toString() ?? '';
          final itemTotal = (o['itemTotal'] as num?)?.toInt() ?? total;
          final rawItems = (o['items'] as List<dynamic>? ?? []).map<Map<String, dynamic>>((i) {
            final pId = (i['productId'] ?? i['id'] ?? '').toString();
            final vId = (i['variantId'] ?? '').toString();
            final price = (i['price'] as num?)?.toDouble() ?? 0.0;
            final origPrice = (i['originalPrice'] as num?)?.toDouble() ?? price;
            final qty = (i['quantity'] ?? i['qty'] as num?)?.toInt() ?? 1;
            return {
              'id': vId.isNotEmpty ? '$pId:$vId' : pId,
              'productId': pId,
              'variantId': vId,
              'title': i['title']?.toString() ?? 'Product',
              'price': '₹${price.toInt()}',
              'originalPrice': origPrice,
              'qty': qty,
              'quantity': qty,
              'unit': i['unit']?.toString() ?? '1 Units',
              'image': i['image']?.toString() ?? '',
              if (storeId.isNotEmpty) 'storeId': storeId,
              if (storeName.isNotEmpty) 'storeName': storeName,
            };
          }).toList();

          String dateFormatted = '';
          String shortDate = '';
          try {
            final dt = DateTime.parse(o['createdAt'].toString()).toLocal();
            final m = months[dt.month - 1];
            final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
            final min = dt.minute.toString().padLeft(2, '0');
            final ampm = dt.hour >= 12 ? 'pm' : 'am';
            dateFormatted = '${dt.day} $m ${dt.year}, $h:$min $ampm';
            shortDate = '$m ${dt.day} - $h:$min $ampm';
          } catch (_) {}

          const statusMap = {
            'placed': 'Processing',
            'confirmed': 'Confirmed',
            'preparing': 'Preparing',
            'ready_for_pickup': 'Ready for Pickup',
            'accepted': 'Rider Assigned',
            'out_for_delivery': 'Out for Delivery',
            'delivered': 'Delivered',
            'cancelled': 'Cancelled',
            'return_requested': 'Return Requested',
            'return_pickup_pending': 'Return Pickup Pending',
            'return_pickup_assigned': 'Return Rider Assigned',
            'returning_to_store': 'Returning to Store',
            'returned_to_store': 'Returned & Refunded',
            'returned': 'Returned & Refunded',
            'return_rejected': 'Return Declined',
          };

          final isCod = payMethod.toLowerCase().contains('cash') || payMethod.toLowerCase().contains('cod');
          final isUpi = payMethod.toLowerCase().contains('upi') || payMethod.toLowerCase().contains('online');

          String subtitleText = 'Sent by you · $shortDate';
          String amountText = '-₹$total';
          bool isPositiveTx = false;
          String paymentTag = 'Wallet';

          if (isCod) {
            paymentTag = 'Cash on Delivery';
            if (status == 'cancelled') {
              amountText = '₹0';
              subtitleText = 'COD · Order Cancelled · $shortDate';
            } else if (status == 'returned_to_store' || status == 'returned') {
              amountText = '₹$total';
              subtitleText = 'COD · Return Processed · $shortDate';
            } else {
              amountText = '₹$total';
              subtitleText = 'Pay on Delivery · $shortDate';
            }
          } else if (isUpi) {
            paymentTag = 'UPI Payment';
            if (status == 'cancelled') {
              amountText = '+₹$total';
              subtitleText = 'UPI Refund Initiated · $shortDate';
              isPositiveTx = true;
            } else {
              amountText = '-₹$total';
              subtitleText = 'Paid via UPI · $shortDate';
            }
          } else {
            paymentTag = 'Wallet Account';
            if (status == 'cancelled') {
              amountText = '+₹$total';
              subtitleText = 'Refunded to Wallet · $shortDate';
              isPositiveTx = true;
            } else {
              amountText = '-₹$total';
              subtitleText = 'Paid from Wallet · $shortDate';
            }
          }

          return {
            'id': orderId,
            'title': storeName,
            'subtitle': subtitleText,
            'amount': amountText,
            'isPositive': isPositiveTx,
            'status': statusMap[status] ?? 'Processing',
            'date': dateFormatted,
            'createdAt': o['createdAt'],
            'items': rawItems,
            'address': addr,
            'listingPrice': '₹$itemTotal',
            'sellingPrice': '₹$itemTotal',
            'grandTotal': '₹$total',
            'paid': '₹$total',
            'paymentMethod': payMethod,
            'paymentTag': paymentTag,
            'storeId': storeId,
            'storeName': storeName,
            'storePhone': storePhone,
            'storeDetails': storeDetails,
          };
        }).toList();
      }
    } catch (e) {
      debugPrint('[WalletApiService] getOrderHistory error: $e');
    }
    return [];
  }

  /// Refunds an amount back to user's wallet (e.g. order cancellation) (API 9.4)
  static Future<Map<String, dynamic>> refundWallet({
    required double amount,
    required String orderId,
    String? reason,
    String? userId,
  }) async {
    final resolvedUser = userId ?? _userId;
    try {
      final url = Uri.parse('${ApiClient.baseUrl}/wallet/refund');
      final body = jsonEncode({
        'userId': resolvedUser,
        'amount': amount,
        'orderId': orderId,
        'reason': reason ?? 'Order Cancellation Refund',
      });

      final res = await http.post(url, headers: ApiClient.defaultHeaders, body: body).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'success': true,
          'walletBalance': (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
          'transaction': data['transaction'],
          'message': data['message'] ?? 'Refund processed successfully',
        };
      }
    } catch (e) {
      debugPrint('[WalletApiService] refundWallet error: $e');
    }
    return {'success': false, 'error': 'Refund failed'};
  }
}
