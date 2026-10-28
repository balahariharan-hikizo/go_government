import 'package:equatable/equatable.dart';

abstract class CouponState extends Equatable {
  const CouponState();

  @override
  List<Object?> get props => [];
}

class CouponInitial extends CouponState {}

class CouponApplying extends CouponState {}

class CouponValid extends CouponState {
  final String code;
  final int discount;
  const CouponValid({required this.code, required this.discount});

  @override
  List<Object?> get props => [code, discount];
}

class CouponInvalid extends CouponState {
  final String error;
  const CouponInvalid({required this.error});

  @override
  List<Object?> get props => [error];
}
