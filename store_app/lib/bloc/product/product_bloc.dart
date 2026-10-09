import 'package:flutter_bloc/flutter_bloc.dart';
import '../../model/product_model.dart';
import '../../network/product_api_service.dart';
import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  static final ProductBloc instance = ProductBloc._internal();
  factory ProductBloc() => instance;

  List<ProductModel> _currentProducts = [];
  int _currentPage = 1;
  bool _hasMore = false;
  int _total = 0;
  bool _isLoadingMore = false;

  ProductBloc._internal() : super(ProductInitial()) {
    on<LoadStoreProductsEvent>((event, emit) async {
      emit(ProductLoading());
      _currentPage = 1;
      final res = await ProductApiService.getProductsByStorePaginated(event.storeId, page: 1, limit: 20);
      _currentProducts = res['products'] as List<ProductModel>;
      _hasMore = res['hasMore'] as bool;
      _total = res['total'] as int;
      _currentPage = res['page'] as int;
      emit(ProductLoaded(List.from(_currentProducts), hasMore: _hasMore, page: _currentPage, total: _total));
    });

    on<LoadMoreStoreProductsEvent>((event, emit) async {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
      emit(ProductLoaded(
        List.from(_currentProducts),
        hasMore: _hasMore,
        page: _currentPage,
        total: _total,
        isLoadingMore: true,
      ));

      try {
        final nextPage = _currentPage + 1;
        final res = await ProductApiService.getProductsByStorePaginated(event.storeId, page: nextPage, limit: 20);
        final newItems = res['products'] as List<ProductModel>;
        _currentPage = res['page'] as int;
        _hasMore = res['hasMore'] as bool;
        _total = res['total'] as int;
        _currentProducts.addAll(newItems);

        emit(ProductLoaded(
          List.from(_currentProducts),
          hasMore: _hasMore,
          page: _currentPage,
          total: _total,
          isLoadingMore: false,
        ));
      } catch (_) {
        emit(ProductLoaded(
          List.from(_currentProducts),
          hasMore: _hasMore,
          page: _currentPage,
          total: _total,
          isLoadingMore: false,
        ));
      } finally {
        _isLoadingMore = false;
      }
    });

    on<AddProductEvent>((event, emit) async {
      emit(ProductSubmitting());
      final res = await ProductApiService.addProduct(event.product);
      if (res != null && res['success'] == true && res['product'] != null) {
        final newProd = ProductModel.fromJson(res['product'] as Map<String, dynamic>);
        _currentProducts.insert(0, newProd);
        emit(ProductSubmitSuccess(newProd, message: res['message'] ?? 'Product added successfully!'));
        emit(ProductLoaded(List.from(_currentProducts), hasMore: _hasMore, page: _currentPage, total: _total));
      } else {
        emit(ProductError(res?['error'] ?? 'Failed to add product'));
        emit(ProductLoaded(List.from(_currentProducts), hasMore: _hasMore, page: _currentPage, total: _total));
      }
    });

    on<ToggleProductAvailabilityEvent>((event, emit) async {
      final success = await ProductApiService.toggleAvailability(event.productId, event.isAvailable);
      if (success) {
        final idx = _currentProducts.indexWhere((p) => p.productId == event.productId);
        if (idx != -1) {
          _currentProducts[idx] = _currentProducts[idx].copyWith(isAvailable: event.isAvailable);
          emit(ProductLoaded(List.from(_currentProducts), hasMore: _hasMore, page: _currentPage, total: _total));
        }
      }
    });

    on<DeleteProductEvent>((event, emit) async {
      final success = await ProductApiService.deleteProduct(event.productId);
      if (success) {
        _currentProducts.removeWhere((p) => p.productId == event.productId);
        emit(ProductLoaded(List.from(_currentProducts), hasMore: _hasMore, page: _currentPage, total: _total));
      }
    });

    on<UpdateProductEvent>((event, emit) async {
      emit(ProductSubmitting());
      final res = await ProductApiService.updateProduct(event.product);
      if (res != null && res['success'] == true && res['product'] != null) {
        final updated = ProductModel.fromJson(res['product'] as Map<String, dynamic>);
        final idx = _currentProducts.indexWhere((p) => p.productId == updated.productId);
        if (idx != -1) {
          _currentProducts[idx] = updated;
        }
        emit(ProductSubmitSuccess(updated, message: res['message'] ?? 'Product updated successfully! 🎉'));
        emit(ProductLoaded(List.from(_currentProducts), hasMore: _hasMore, page: _currentPage, total: _total));
      } else {
        emit(ProductError(res?['error'] ?? 'Failed to update product'));
        emit(ProductLoaded(List.from(_currentProducts), hasMore: _hasMore, page: _currentPage, total: _total));
      }
    });

    on<AdjustProductStockEvent>((event, emit) async {
      final idx = _currentProducts.indexWhere((p) => p.productId == event.productId);
      if (idx != -1) {
        final current = _currentProducts[idx];
        final newStock = (current.stock + event.delta).clamp(0, 99999);
        final success = await ProductApiService.updateProductStock(event.productId, newStock);
        if (success) {
          _currentProducts[idx] = current.copyWith(stock: newStock);
          emit(ProductLoaded(List.from(_currentProducts), hasMore: _hasMore, page: _currentPage, total: _total));
        }
      }
    });
  }
}
