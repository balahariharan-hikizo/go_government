import 'package:equatable/equatable.dart';

abstract class CouponEvent extends Equatable {
  const CouponEvent();

  @override
  List<Object?> get props => [];
}

class ApplyCoupon extends CouponEvent {
  final String code;
  const ApplyCoupon(this.code);

  @override
  List<Object?> get props => [code];
}

class RemoveCoupon extends CouponEvent {
  const RemoveCoupon();
}
