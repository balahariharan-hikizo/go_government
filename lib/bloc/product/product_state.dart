import 'package:equatable/equatable.dart';

abstract class ProductState extends Equatable {
  const ProductState();

  @override
  List<Object?> get props => [];
}

class ProductInitial extends ProductState {}

class ProductLoading extends ProductState {}

class ProductLoaded extends ProductState {
  final List<Map<String, dynamic>> products;
  final bool hasMore;
  final int page;
  final int total;
  final bool isLoadingMore;

  const ProductLoaded(
    this.products, {
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.isLoadingMore = false,
  });

  @override
  List<Object?> get props => [products, hasMore, page, total, isLoadingMore];
}

class ProductError extends ProductState {
  final String message;
  const ProductError(this.message);

  @override
  List<Object?> get props => [message];
}
