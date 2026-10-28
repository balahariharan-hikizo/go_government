import 'package:equatable/equatable.dart';

abstract class ProductEvent extends Equatable {
  const ProductEvent();

  @override
  List<Object?> get props => [];
}

class LoadProducts extends ProductEvent {
  final String storeId;
  final String storeType; // 'medical' or 'vegstore'
  final String? category;
  const LoadProducts({required this.storeId, required this.storeType, this.category});

  @override
  List<Object?> get props => [storeId, storeType, category];
}

class LoadMoreProducts extends ProductEvent {
  final String storeId;
  final String storeType;
  final String? category;
  const LoadMoreProducts({required this.storeId, required this.storeType, this.category});

  @override
  List<Object?> get props => [storeId, storeType, category];
}

class FilterProducts extends ProductEvent {
  final String query;
  const FilterProducts(this.query);

  @override
  List<Object?> get props => [query];
}
