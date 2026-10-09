import '../../model/product_model.dart';

abstract class ProductState {}

class ProductInitial extends ProductState {}

class ProductLoading extends ProductState {}

class ProductLoaded extends ProductState {
  final List<ProductModel> products;
  final bool hasMore;
  final int page;
  final int total;
  final bool isLoadingMore;

  ProductLoaded(
    this.products, {
    this.hasMore = false,
    this.page = 1,
    this.total = 0,
    this.isLoadingMore = false,
  });
}

class ProductSubmitting extends ProductState {}

class ProductSubmitSuccess extends ProductState {
  final ProductModel product;
  final String message;
  ProductSubmitSuccess(this.product, {this.message = 'Product added successfully!'});
}

class ProductError extends ProductState {
  final String error;
  ProductError(this.error);
}
