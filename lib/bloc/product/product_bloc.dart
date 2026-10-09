import 'package:flutter_bloc/flutter_bloc.dart';
import '../../network/product_api_service.dart';
import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  List<Map<String, dynamic>> _allProducts = [];
  int _currentPage = 1;
  bool _hasMore = false;
  int _total = 0;
  bool _isLoadingMore = false;

  ProductBloc() : super(ProductInitial()) {
    on<LoadProducts>((event, emit) async {
      emit(ProductLoading());
      try {
        _currentPage = 1;
        final res = await ProductApiService.fetchProductsPaginated(
          event.storeId,
          page: 1,
          limit: 20,
          category: event.category,
          storeType: event.storeType,
        );
        _allProducts = (res['products'] as List).cast<Map<String, dynamic>>();
        _hasMore = res['hasMore'] as bool;
        _total = res['total'] as int;
        _currentPage = res['page'] as int;

        emit(ProductLoaded(
          List.from(_allProducts),
          hasMore: _hasMore,
          page: _currentPage,
          total: _total,
        ));
      } catch (e) {
        _allProducts = [];
        _hasMore = false;
        emit(const ProductLoaded([]));
      }
    });

    on<LoadMoreProducts>((event, emit) async {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
      emit(ProductLoaded(
        List.from(_allProducts),
        hasMore: _hasMore,
        page: _currentPage,
        total: _total,
        isLoadingMore: true,
      ));

      try {
        final nextPage = _currentPage + 1;
        final res = await ProductApiService.fetchProductsPaginated(
          event.storeId,
          page: nextPage,
          limit: 20,
          category: event.category, 
          storeType: event.storeType,
        );
        final newItems = (res['products'] as List).cast<Map<String, dynamic>>();
        _currentPage = res['page'] as int;
        _hasMore = res['hasMore'] as bool;
        _total = res['total'] as int;
        _allProducts.addAll(newItems);

        emit(ProductLoaded(
          List.from(_allProducts),
          hasMore: _hasMore,
          page: _currentPage,
          total: _total,
          isLoadingMore: false,
        ));
      } catch (e) {
        emit(ProductLoaded(
          List.from(_allProducts),
          hasMore: _hasMore,
          page: _currentPage,
          total: _total,
          isLoadingMore: false,
        ));
      } finally {
        _isLoadingMore = false;
      }
    });

    on<FilterProducts>((event, emit) {
      if (event.query.trim().isEmpty) {
        emit(ProductLoaded(
          List.from(_allProducts),
          hasMore: _hasMore,
          page: _currentPage,
          total: _total,
        ));
      } else {
        final query = event.query.toLowerCase();
        final filtered = _allProducts.where((p) {
          final title = (p['title'] ?? '').toString().toLowerCase();
          final brand = (p['brand'] ?? '').toString().toLowerCase();
          return title.contains(query) || brand.contains(query);
        }).toList();
        emit(ProductLoaded(
          filtered,
          hasMore: false,
          page: _currentPage,
          total: filtered.length,
        ));
      }
    });
  }
}
