import 'package:flutter_bloc/flutter_bloc.dart';
import '../../model/category_model.dart';
import '../../network/category_api_service.dart';
import 'category_event.dart';
import 'category_state.dart';

class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  static final CategoryBloc instance = CategoryBloc._internal();
  factory CategoryBloc() => instance;

  List<CategoryModel> _categories = [];
  final Set<String> _expandedCategoryIds = {};

  CategoryBloc._internal() : super(CategoryInitial()) {
    on<LoadStoreCategoriesEvent>((event, emit) async {
      emit(CategoryLoading());
      try {
        final list = await CategoryApiService.getCategoriesByStore(
          event.storeId,
          activeOnly: event.activeOnly,
        );
        _categories = list;
        emit(CategoryLoaded(
          categories: List.from(_categories),
          expandedCategoryIds: Set.from(_expandedCategoryIds),
        ));
      } catch (e) {
        emit(CategoryError('Failed to load categories: $e'));
      }
    });

    on<ToggleCategoryExpansionEvent>((event, emit) {
      if (_expandedCategoryIds.contains(event.categoryId)) {
        _expandedCategoryIds.remove(event.categoryId);
      } else {
        _expandedCategoryIds.add(event.categoryId);
      }
      emit(CategoryLoaded(
        categories: List.from(_categories),
        expandedCategoryIds: Set.from(_expandedCategoryIds),
      ));
    });

    on<CreateCategoryEvent>((event, emit) async {
      final res = await CategoryApiService.createCategory(
        storeId: event.storeId,
        name: event.name,
        parentCategoryId: event.parentCategoryId,
        description: event.description,
        icon: event.icon,
        image: event.image,
        displayOrder: event.displayOrder,
        isActive: event.isActive,
      );

      if (res['success'] == true && res['category'] is CategoryModel) {
        final created = res['category'] as CategoryModel;
        _categories.add(created);
        // Automatically expand the parent so the new category is visible
        if (event.parentCategoryId.isNotEmpty) {
          _expandedCategoryIds.add(event.parentCategoryId);
        }
        emit(CategoryOperationSuccess(
          res['message'] ?? 'Category created successfully!',
          category: created,
        ));
        emit(CategoryLoaded(
          categories: List.from(_categories),
          expandedCategoryIds: Set.from(_expandedCategoryIds),
        ));
      } else {
        emit(CategoryError(res['error'] ?? 'Failed to create category'));
        emit(CategoryLoaded(
          categories: List.from(_categories),
          expandedCategoryIds: Set.from(_expandedCategoryIds),
        ));
      }
    });

    on<UpdateCategoryEvent>((event, emit) async {
      final res = await CategoryApiService.updateCategory(
        event.categoryId,
        name: event.name,
        description: event.description,
        icon: event.icon,
        image: event.image,
        displayOrder: event.displayOrder,
        isActive: event.isActive,
      );

      if (res['success'] == true) {
        final idx = _categories.indexWhere((c) => c.categoryId == event.categoryId);
        if (idx != -1) {
          _categories[idx] = _categories[idx].copyWith(
            name: event.name,
            description: event.description,
            icon: event.icon,
            image: event.image,
            displayOrder: event.displayOrder,
            isActive: event.isActive,
          );
        }
        emit(CategoryOperationSuccess(
          res['message'] ?? 'Category updated successfully!',
          category: idx != -1 ? _categories[idx] : null,
        ));
        emit(CategoryLoaded(
          categories: List.from(_categories),
          expandedCategoryIds: Set.from(_expandedCategoryIds),
        ));
      } else {
        emit(CategoryError(res['error'] ?? 'Failed to update category'));
        emit(CategoryLoaded(
          categories: List.from(_categories),
          expandedCategoryIds: Set.from(_expandedCategoryIds),
        ));
      }
    });

    on<ToggleCategoryActiveEvent>((event, emit) async {
      // Optimistic in-memory toggle
      final idx = _categories.indexWhere((c) => c.categoryId == event.categoryId);
      if (idx != -1) {
        _categories[idx] = _categories[idx].copyWith(isActive: event.isActive);
        emit(CategoryLoaded(
          categories: List.from(_categories),
          expandedCategoryIds: Set.from(_expandedCategoryIds),
        ));
      }

      final res = await CategoryApiService.updateCategory(
        event.categoryId,
        isActive: event.isActive,
      );

      if (res['success'] != true && idx != -1) {
        // Rollback on failure
        _categories[idx] = _categories[idx].copyWith(isActive: !event.isActive);
        emit(CategoryError('Failed to update category status'));
        emit(CategoryLoaded(
          categories: List.from(_categories),
          expandedCategoryIds: Set.from(_expandedCategoryIds),
        ));
      }
    });

    on<DeleteCategoryEvent>((event, emit) async {
      final res = await CategoryApiService.deleteCategory(event.categoryId);
      if (res['success'] == true) {
        _categories.removeWhere((c) => c.categoryId == event.categoryId);
        _expandedCategoryIds.remove(event.categoryId);
        emit(CategoryOperationSuccess(
          res['message'] ?? 'Category removed successfully',
        ));
        emit(CategoryLoaded(
          categories: List.from(_categories),
          expandedCategoryIds: Set.from(_expandedCategoryIds),
        ));
      } else {
        emit(CategoryError(res['error'] ?? 'Failed to delete category'));
        emit(CategoryLoaded(
          categories: List.from(_categories),
          expandedCategoryIds: Set.from(_expandedCategoryIds),
        ));
      }
    });
  }
}

