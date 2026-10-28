import 'package:flutter_bloc/flutter_bloc.dart';
import 'coupon_event.dart';
import 'coupon_state.dart';

class CouponBloc extends Bloc<CouponEvent, CouponState> {
  final List<Map<String, dynamic>> _availableCoupons = [
    {'code': 'GETOFF120ON649', 'discount': 120},
    {'code': 'GETOFF000N199', 'discount': 160},
    {'code': 'FREE_DELIVERY', 'discount': 25},
    {'code': 'GOVERNMENT10', 'discount': 50},
  ];

  CouponBloc() : super(CouponInitial()) {
    on<ApplyCoupon>((event, emit) async {
      emit(CouponApplying());
      await Future.delayed(const Duration(milliseconds: 300)); // simulate latency
      final match = _availableCoupons.firstWhere(
        (c) => c['code'].toString().toLowerCase() == event.code.toLowerCase(),
        orElse: () => {},
      );
      if (match.isNotEmpty) {
        emit(CouponValid(code: match['code'], discount: match['discount']));
      } else {
        emit(const CouponInvalid(error: 'Invalid coupon code'));
      }
    });
    on<RemoveCoupon>((event, emit) async {
      emit(CouponInitial());
    });
  }
}
