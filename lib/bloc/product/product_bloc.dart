import 'package:flutter_bloc/flutter_bloc.dart';
import '../../network/product_api_service.dart';
import 'product_event.dart';
import 'product_state.dart';

class ProductBloc extends Bloc<ProductEvent, ProductState> {
  List<Map<String, dynamic>> _allProducts = [];

  ProductBloc() : super(ProductInitial()) {
    on<LoadProducts>((event, emit) async {
      emit(ProductLoading());
      try {
        _allProducts = await ProductApiService.fetchProductsByStore(
          event.storeId,
          storeType: event.storeType,
        );
        emit(ProductLoaded(_allProducts));
      } catch (e) {
        _allProducts = [];
        emit(const ProductLoaded([]));
      }
    });

    on<FilterProducts>((event, emit) {
      if (event.query.trim().isEmpty) {
        emit(ProductLoaded(_allProducts));
      } else {
        final query = event.query.toLowerCase();
        final filtered = _allProducts.where((p) {
          final title = (p['title'] ?? '').toString().toLowerCase();
          final brand = (p['brand'] ?? '').toString().toLowerCase();
          return title.contains(query) || brand.contains(query);
        }).toList();
        emit(ProductLoaded(filtered));
      }
    });
  }
}
